"""Natural voices for the daily texts (Google Cloud Text-to-Speech, Chirp 3 HD).

    python -I -X utf8 tools/audio.py A1            makes the missing or changed MP3s of A1
    python -I -X utf8 tools/audio.py A1 --dry      only counts the characters

Files go to ../deschly-site/audio/<voice>/<text id>.mp3 (voice f = woman, m = man); the app downloads them
when the learner taps play and keeps them. audio/index.json records a hash of every text, so a text is only
made again when it changed. Push the site with Gizlilik-Sitesi-Yukle.cmd afterwards.

The key is read from ../tts/anahtarlar.txt (GOOGLE_KEY=...), never from the repo.
A run stops before it would use more than --max-chars characters (default 300,000; the free tier is
1,000,000 characters a month for Chirp 3 HD).
"""
import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_pad  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
SITE_AUDIO = os.path.join(ROOT, 'deschly-site', 'audio')
KEYS = os.path.join(ROOT, 'tts', 'anahtarlar.txt')
VOICES = {'f': 'de-DE-Chirp3-HD-Achernar', 'm': 'de-DE-Chirp3-HD-Achird'}
RATE = 0.95
AGENT = 'tts-batch-script/1.0'


def google_key():
    for line in open(KEYS, encoding='utf-8-sig'):
        if line.startswith('GOOGLE_KEY='):
            return line.split('=', 1)[1].strip()
    sys.exit('No GOOGLE_KEY in ' + KEYS)


def spoken(text):
    """What is read: the title, a pause, then the paragraphs (same words as on screen)."""
    return text['title'] + '.\n\n' + '\n\n'.join(text['paragraphs'])


def synthesize(key, voice, content):
    body = json.dumps({
        'input': {'text': content},
        'voice': {'languageCode': 'de-DE', 'name': voice},
        'audioConfig': {'audioEncoding': 'MP3', 'speakingRate': RATE, 'sampleRateHertz': 24000},
    }).encode('utf-8')
    request = urllib.request.Request(f'https://texttospeech.googleapis.com/v1/text:synthesize', data=body,
                                     headers={'Content-Type': 'application/json', 'User-Agent': AGENT, 'X-Goog-Api-Key': key}, method='POST')
    with urllib.request.urlopen(request, timeout=120) as reply:
        return base64.b64decode(json.load(reply)['audioContent'])


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry' in sys.argv
    max_chars = next((int(a.split('=')[1]) for a in sys.argv if a.startswith('--max-chars=')), 300_000)
    levels = [a.lower() for a in args] or ['a1']

    index_path = os.path.join(SITE_AUDIO, 'index.json')
    index = json.load(open(index_path, encoding='utf-8')) if os.path.exists(index_path) else {}

    jobs = []
    for level in levels:
        texts = json.load(open(os.path.join(REPO, 'Resources', 'content', f'daily_{level}.json'), encoding='utf-8'))['texts']
        for text in texts:
            content = spoken(text)
            digest = hashlib.sha256(content.encode('utf-8')).hexdigest()[:16]
            for short in VOICES:
                path = os.path.join(SITE_AUDIO, short, f"{text['id']}.mp3")
                if index.get(text['id'], {}).get(short) == digest and os.path.exists(path):
                    continue
                jobs.append((text['id'], short, content, digest, path))

    total = sum(len(j[2]) for j in jobs)
    print(f'{len(jobs)} files to make, {total:,} characters (limit {max_chars:,})')
    if dry or not jobs:
        return
    if total > max_chars:
        sys.exit('Over the limit: run fewer levels or pass --max-chars=N')

    key = google_key()
    made = 0
    for text_id, short, content, digest, path in jobs:
        try:
            audio = synthesize(key, VOICES[short], content)
        except urllib.error.HTTPError as e:
            print(f'  {text_id} {short}: error {e.code} {e.read()[:160]!r}')
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(audio)
        audio_pad.pad(path)
        audio_pad.mark([path])
        index.setdefault(text_id, {})[short] = digest
        made += 1
        if made % 10 == 0:
            print(f'  {made}/{len(jobs)}')
            json.dump(index, open(index_path, 'w', encoding='utf-8'), indent=1, sort_keys=True)
    json.dump(index, open(index_path, 'w', encoding='utf-8'), indent=1, sort_keys=True)
    size = sum(os.path.getsize(os.path.join(dp, f)) for dp, _, fs in os.walk(SITE_AUDIO) for f in fs if f.endswith('.mp3'))
    print(f'made {made} files; audio folder {size / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
