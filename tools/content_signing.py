"""Signs the content manifest, so the app installs content only from us (even if the website were changed by someone).

    python -I -X utf8 tools/content_signing.py keygen     makes the signing key (once) and prints the public key
    python -I -X utf8 tools/content_signing.py test       checks this Ed25519 code against the RFC 8032 test vector

tools/publish_content.py calls sign_file() for deschly-site/content/manifest.json → manifest.sig (base64).
The private key lives outside the repo in ../tts/content_signing_key.txt (hex). Keep a backup of it: without it,
apps that check the signature accept no new content until an app update with a new public key.
The public key is in the app: ContentUpdater.publicKey (Sources/Core/Content/ContentUpdater.swift).

Ed25519 as in RFC 8032 (pure Python, no packages needed; signing one small file is fast enough).
"""
import base64
import hashlib
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY_FILE = os.path.join(os.path.dirname(REPO), 'tts', 'content_signing_key.txt')

P = 2 ** 255 - 19
L = 2 ** 252 + 27742317777372353535851937790883648493
D = -121665 * pow(121666, P - 2, P) % P
SQRT_M1 = pow(2, (P - 1) // 4, P)


def _sha512(data):
    return hashlib.sha512(data).digest()


def _inv(x):
    return pow(x, P - 2, P)


def _recover_x(y):
    xx = (y * y - 1) * _inv(D * y * y + 1) % P
    x = pow(xx, (P + 3) // 8, P)
    if (x * x - xx) % P != 0:
        x = x * SQRT_M1 % P
    if x % 2 != 0:
        x = P - x
    return x


_BY = 4 * _inv(5) % P
_BX = _recover_x(_BY)
BASE = (_BX, _BY, 1, _BX * _BY % P)  # extended coordinates


def _add(p1, p2):
    x1, y1, z1, t1 = p1
    x2, y2, z2, t2 = p2
    a = (y1 - x1) * (y2 - x2) % P
    b = (y1 + x1) * (y2 + x2) % P
    c = t1 * 2 * D * t2 % P
    d = z1 * 2 * z2 % P
    e, f, g, h = b - a, d - c, d + c, b + a
    return (e * f % P, g * h % P, f * g % P, e * h % P)


def _mul(s, point):
    result = (0, 1, 1, 0)
    while s > 0:
        if s & 1:
            result = _add(result, point)
        point = _add(point, point)
        s >>= 1
    return result


def _encode(point):
    x, y, z, _ = point
    zi = _inv(z)
    x, y = x * zi % P, y * zi % P
    return int.to_bytes(y | ((x & 1) << 255), 32, 'little')


def _expand(secret):
    h = _sha512(secret)
    a = int.from_bytes(h[:32], 'little')
    a &= (1 << 254) - 8
    a |= 1 << 254
    return a, h[32:]


def public_key(secret):
    a, _ = _expand(secret)
    return _encode(_mul(a, BASE))


def sign(secret, message):
    a, prefix = _expand(secret)
    pub = _encode(_mul(a, BASE))
    r = int.from_bytes(_sha512(prefix + message), 'little') % L
    big_r = _encode(_mul(r, BASE))
    h = int.from_bytes(_sha512(big_r + pub + message), 'little') % L
    s = (r + h * a) % L
    return big_r + int.to_bytes(s, 32, 'little')


def load_key():
    if not os.path.exists(KEY_FILE):
        return None
    return bytes.fromhex(open(KEY_FILE, encoding='utf-8').read().strip())


def sign_file(path):
    """Writes <path minus .json>.sig with the base64 signature; returns False when there is no key."""
    secret = load_key()
    if secret is None:
        return False
    data = open(path, 'rb').read()
    sig_path = os.path.splitext(path)[0] + '.sig'
    with open(sig_path, 'w', encoding='ascii', newline='\n') as f:
        f.write(base64.b64encode(sign(secret, data)).decode('ascii') + '\n')
    return True


def test():
    # RFC 8032, 7.1, TEST 1
    secret = bytes.fromhex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60')
    assert public_key(secret).hex() == 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'
    assert sign(secret, b'').hex() == ('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b')
    # RFC 8032, 7.1, TEST 2 (one byte)
    secret = bytes.fromhex('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb')
    assert public_key(secret).hex() == '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c'
    assert sign(secret, bytes([0x72])).hex() == ('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00')
    print('Ed25519 matches RFC 8032 test vectors')


def keygen():
    if os.path.exists(KEY_FILE):
        sys.exit('A key already exists: ' + KEY_FILE + ' (not replaced)')
    secret = os.urandom(32)
    os.makedirs(os.path.dirname(KEY_FILE), exist_ok=True)
    with open(KEY_FILE, 'w', encoding='utf-8', newline='\n') as f:
        f.write(secret.hex() + '\n')
    print('private key written to', KEY_FILE, '(keep a backup, never commit it)')
    print('public key (put it in ContentUpdater.publicKey):', public_key(secret).hex())


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'test'
    if command == 'keygen':
        keygen()
    elif command == 'public':
        key = load_key()
        print(public_key(key).hex() if key else 'no key')
    else:
        test()
