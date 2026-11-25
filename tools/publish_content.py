"""Publishes the app content to the website, so installed apps get new texts and pictures without an App Store update.

    python -I -X utf8 tools/publish_content.py            (writes ../deschly-site/content/)
    python -I -X utf8 tools/publish_content.py --check    (only shows what would change)

Then push the site (Gizlilik-Sitesi-Yukle.cmd). Apps check the manifest at most every 6 hours and use the new files
from their next launch. Keep SCHEMA equal to ContentStore.schema in the app; raise both when the JSON shape changes
in a way older apps cannot read (older apps then simply stop updating and keep their bundled content).
"""
import glob
import hashlib
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SITE = os.path.normpath(os.path.join(REPO, '..', 'deschly-site', 'content'))
SCHEMA = 2


def sources():
    """Published name → local file."""
    out = {}
    for path in sorted(glob.glob(os.path.join(REPO, 'Resources', 'content', '*.json'))):
        out[os.path.basename(path)] = path
    for path in sorted(glob.glob(os.path.join(REPO, 'Resources', 'Covers', '*.jpg'))):
        out['covers/' + os.path.basename(path)] = path
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 16), b''):
            h.update(block)
    return h.hexdigest()


def main():
    check = '--check' in sys.argv
    if not check:
        # Hand edits from Deschly Studio first, so a regenerated content file never goes out without them.
        sys.path.insert(0, HERE)
        import content_edits
        content_edits.apply_all()
    files = sources()
    # A content file must be valid JSON before it goes to every installed app.
    for name, path in files.items():
        if name.endswith('.json'):
            json.load(open(path, encoding='utf-8'))
    manifest_path = os.path.join(SITE, 'manifest.json')
    try:
        old = json.load(open(manifest_path, encoding='utf-8'))['files']
    except (OSError, ValueError, KeyError):
        old = {}
    new = {name: {'sha256': sha256(path), 'size': os.path.getsize(path)} for name, path in files.items()}
    changed = [n for n in new if old.get(n, {}).get('sha256') != new[n]['sha256']]
    removed = [n for n in old if n not in new]
    size = sum(f['size'] for f in new.values())
    print(f'{len(new)} files, {size / 1e6:.1f} MB; changed or new: {len(changed)}; removed: {len(removed)}')
    for n in changed[:20]:
        print('  +', n)
    if len(changed) > 20:
        print(f'  … {len(changed) - 20} more')
    for n in removed:
        print('  -', n)
    if check:
        return
    os.makedirs(os.path.join(SITE, 'covers'), exist_ok=True)
    for name in changed:
        shutil.copyfile(files[name], os.path.join(SITE, name))
    for name in removed:
        path = os.path.join(SITE, name)
        if os.path.exists(path):
            os.remove(path)
    with open(manifest_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'schema': SCHEMA, 'files': new}, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write('\n')
    print(f'written to {SITE}; now push the site (Gizlilik-Sitesi-Yukle.cmd)')


if __name__ == '__main__':
    main()
