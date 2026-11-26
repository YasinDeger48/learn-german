"""Background sounds (Ortam sesi) for the daily texts and path stories: a bus, a café, an office… played softly under the voice.

    python -I -X utf8 tools/ambience.py assign     which sound each text gets (no key needed), prints a summary
    python -I -X utf8 tools/ambience.py write      writes ambience.json with the sounds already made (no download)
    python -I -X utf8 tools/ambience.py sounds     downloads CC0 recordings from Freesound and makes the loops

Output in ../deschly-site/audio/:
    ambience/<kind>.m4a      45 s mono AAC loops, faded at both ends, loudness evened out
    ambience.json            {"texts": {"a1-001": "street", …}, "sounds": {"street": {source, by, license}, …}}

Only Creative Commons 0 recordings are used, so no credit is required (we still keep the source in the JSON).
The Freesound key is read from ../tts/anahtarlar.txt (FREESOUND_KEY=...). Push the site afterwards.
"""
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
OUT = os.path.join(ROOT, 'deschly-site', 'audio')
KEYS = os.path.join(ROOT, 'tts', 'anahtarlar.txt')
WORK = os.path.join(ROOT, 'tts', 'ambience_raw')
AGENT = 'deschly-ambience-tool/1.0'

# kind -> (Freesound search, German words that point to it; a word matches at its start)
KINDS = {
    'bus': ('bus interior ambience', ['bus', 'busse', 'haltestelle', 'straßenbahn', 'tram', 'u-bahn', 's-bahn', 'busfahr']),
    'train': ('train station ambience', ['zug', 'züge', 'bahnhof', 'bahnsteig', 'gleis', 'ice', 'fernzug', 'regionalzug']),
    'cafe': ('cafe restaurant ambience', ['café', 'cafe', 'restaurant', 'kantine', 'kellner', 'bäckerei', 'imbiss', 'mensa']),
    'office': ('office typing keyboard ambience', ['büro', 'kollege', 'kollegin', 'besprechung', 'meeting', 'schreibtisch', 'drucker', 'firma', 'abteilung']),
    'shop': ('supermarket ambience', ['supermarkt', 'markt', 'kasse', 'laden', 'geschäft', 'einkauf', 'kunde', 'kundin', 'wochenmarkt']),
    'home': ('kitchen room tone ambience', ['küche', 'wohnung', 'wohnzimmer', 'balkon', 'zuhause', 'kochen', 'frühstück', 'familie']),
    'nature': ('park birds ambience', ['park', 'garten', 'wald', 'see', 'spaziergang', 'vögel', 'wiese', 'natur', 'beet', 'baum']),
    'rain': ('rain falling ambience', ['regen', 'regnet', 'gewitter', 'regenschirm', 'unwetter']),
    'school': ('classroom ambience', ['schule', 'klasse', 'kurs', 'lehrer', 'lehrerin', 'unterricht', 'uni', 'seminar', 'prüfung']),
    'street': ('city street ambience traffic', ['straße', 'kreuzung', 'ampel', 'verkehr', 'fahrrad', 'innenstadt', 'stadt', 'bürgersteig', 'auto']),
}
MIN_HITS = 2
# Kinds whose search also needs the Freesound tag (plain searches find other sounds first).
TAGGED = {'rain'}
# Hand-picked where the word count chooses badly or finds too few words (chosen by reading the texts, 2026-11-26).
# Texts left out on purpose: no fitting place (plane, silent cinema, orchestra or theatre rehearsal, gym).
OVERRIDES = {
    'a1-001': 'street',
    'a1-005': 'train', 'a1-006': 'office', 'a1-007': 'home', 'a1-008': 'home', 'a1-011': 'home', 'a1-015': 'home',
    'a1-017': 'home', 'a1-019': 'office', 'a1-021': 'home', 'a1-024': 'home', 'a1-026': 'home', 'a1-028': 'office',
    'a1-029': 'cafe', 'a1-033': 'home', 'a1-034': 'home', 'a1-036': 'office', 'a1-037': 'nature', 'a1-038': 'home',
    'a1-040': 'school', 'a1-043': 'office', 'a1-045': 'shop', 'a1-047': 'nature', 'a1-048': 'home', 'a1-050': 'school',
    'a1-052': 'street', 'a1-054': 'home', 'a1-055': 'home', 'a1-056': 'home', 'a1-057': 'home', 'a1-059': 'home',
    'a1-060': 'street',
    's-a1-01-1': 'school', 's-a1-02-1': 'school', 's-a1-04-1': 'shop', 's-a1-08-1': 'office', 's-a1-08-2': 'home',
    's-a1-10-2': 'school', 's-a1-12-1': 'office', 's-a1-12-2': 'office',
    'a2-002': 'office', 'a2-007': 'office', 'a2-010': 'home', 'a2-013': 'home', 'a2-016': 'home', 'a2-017': 'office',
    'a2-022': 'home', 'a2-023': 'home', 'a2-024': 'street', 'a2-025': 'shop', 'a2-026': 'nature', 'a2-029': 'school',
    'a2-042': 'home', 'a2-043': 'home', 'a2-044': 'street', 'a2-047': 'shop', 'a2-057': 'school', 'a2-060': 'home',
    'b1-005': 'office', 'b1-006': 'office', 'b1-009': 'home', 'b1-010': 'school', 'b1-015': 'home', 'b1-020': 'home',
    'b1-023': 'nature', 'b1-024': 'office', 'b1-026': 'nature', 'b1-031': 'office', 'b1-034': 'school',
    'b1-037': 'office', 'b1-040': 'nature', 'b1-047': 'school', 'b1-050': 'street', 'b1-060': 'home',
    'b2-006': 'cafe', 'b2-008': 'home', 'b2-011': 'shop', 'b2-015': 'office', 'b2-016': 'home', 'b2-022': 'office',
    'b2-027': 'nature', 'b2-029': 'office', 'b2-031': 'office', 'b2-032': 'office', 'b2-043': 'office',
    'b2-045': 'office', 'b2-046': 'office', 'b2-052': 'home', 'b2-054': 'office', 'b2-056': 'office',
    'b2-058': 'office',
}


def all_texts():
    """The daily texts and the path stories of every level."""
    out = []
    for level in ['a1', 'a2', 'b1', 'b2']:
        for name in (f'daily_{level}.json', f'stories_{level}.json'):
            path = os.path.join(REPO, 'Resources', 'content', name)
            if os.path.exists(path):
                out += json.load(open(path, encoding='utf-8'))['texts']
    return out


def assign():
    texts = {}
    counts = {k: 0 for k in KINDS}
    every = all_texts()
    for t in every:
        words = re.findall(r'[\wäöüß-]+', (t['title'] + ' ' + ' '.join(t['paragraphs'])).lower())
        score = {k: sum(1 for w in words for s in stems if w.startswith(s)) for k, (_, stems) in KINDS.items()}
        best = max(score, key=score.get)
        if t['id'] in OVERRIDES:
            best = OVERRIDES[t['id']]
        elif score[best] < MIN_HITS:
            continue
        texts[t['id']] = best
        counts[best] += 1
    total = len(every)
    print(f'{len(texts)}/{total} texts get a background sound: ' + ', '.join(f'{k} {n}' for k, n in counts.items()))
    return texts


def write_json(texts, sounds):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, 'ambience.json')
    old = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else {}
    sounds = {**old.get('sounds', {}), **sounds}
    # Only point texts at sounds that exist.
    texts = {i: k for i, k in texts.items() if k in sounds}
    json.dump({'texts': texts, 'sounds': sounds}, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, sort_keys=True)
    print(f'ambience.json: {len(texts)} texts, {len(sounds)} sounds')


def ffmpeg():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return os.path.join(ROOT, 'tts', 'piper-env', 'Lib', 'site-packages', 'imageio_ffmpeg', 'binaries', 'ffmpeg-win-x86_64-v9.0.2.exe')


def freesound_key():
    for line in open(KEYS, encoding='utf-8-sig'):
        if line.startswith('FREESOUND_KEY=') and line.split('=', 1)[1].strip():
            return line.split('=', 1)[1].strip()
    sys.exit('No FREESOUND_KEY in ' + KEYS)


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': AGENT}), timeout=60) as r:
        return json.load(r)


def sounds():
    key = freesound_key()
    tool = ffmpeg()
    os.makedirs(WORK, exist_ok=True)
    os.makedirs(os.path.join(OUT, 'ambience'), exist_ok=True)
    made = {}
    only = sys.argv[2:]
    for kind, (query, _) in KINDS.items():
        if only and kind not in only:
            continue
        params = {
            'query': query,
            'filter': 'license:"Creative Commons 0" duration:[50 TO 900]' + (f' tag:{kind}' if kind in TAGGED else ''),
            'sort': 'rating_desc',
            'fields': 'id,name,username,license,duration,previews,num_ratings,avg_rating',
            'page_size': 15,
            'token': key,
        }
        results = get_json('https://freesound.org/apiv2/search/text/?' + urllib.parse.urlencode(params)).get('results', [])
        results = [r for r in results if r.get('num_ratings', 0) >= 2] or results
        if not results:
            print(f'  {kind}: nothing found')
            continue
        pick = results[0]
        raw = os.path.join(WORK, f'{kind}.mp3')
        with urllib.request.urlopen(urllib.request.Request(pick['previews']['preview-hq-mp3'], headers={'User-Agent': AGENT}), timeout=120) as r:
            open(raw, 'wb').write(r.read())
        target = os.path.join(OUT, 'ambience', f'{kind}.m4a')
        start = min(10, max(0, pick['duration'] - 50))
        subprocess.run([tool, '-y', '-loglevel', 'error', '-ss', str(start), '-t', '45', '-i', raw,
                        '-af', 'loudnorm=I=-24:TP=-3,afade=t=in:d=2,afade=t=out:st=43:d=2',
                        '-ac', '1', '-ar', '44100', '-c:a', 'aac', '-b:a', '64k', target], check=True)
        made[kind] = {'file': f'ambience/{kind}.m4a', 'source': f"https://freesound.org/s/{pick['id']}/",
                      'name': pick['name'], 'by': pick['username'], 'license': 'CC0'}
        print(f"  {kind}: {pick['name']} by {pick['username']} ({pick['duration']:.0f}s) -> {os.path.getsize(target) // 1024} KB")
    write_json(assign(), made)


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'assign'
    if command == 'assign':
        assign()
    elif command == 'write':  # new texts or stories: rewrite ambience.json with the sounds already made
        write_json(assign(), {})
    elif command == 'sounds':
        sounds()
