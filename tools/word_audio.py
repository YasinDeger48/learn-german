"""Natural voice (Google Neural2, a woman's voice) for single words: every level word as the app says it
("der Bahnhof", "gehen") and every glossary word of the daily texts.

    python -I -X utf8 tools/word_audio.py --dry     counts what is missing
    python -I -X utf8 tools/word_audio.py           makes the missing MP3s

Output in ../deschly-site/audio/:
    w/<hash>.mp3       one file per spoken text (hash = first 12 hex of sha1 of voice + '|' + text, so a new
                       voice gets new names and phones do not keep playing cached old files)
    words.json         {"items": {"der bahnhof": "<hash>", …}}  key: lower case, single spaces
The app (A1Speaker.say) plays the recording when the text is in words.json, else the iPhone voice.
Key from ../tts/anahtarlar.txt (GOOGLE_KEY). Push the site afterwards.
"""
import base64
import concurrent.futures
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_pad  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
OUT = os.path.join(ROOT, 'deschly-site', 'audio')
KEYS = os.path.join(ROOT, 'tts', 'anahtarlar.txt')
# Neural2, not Chirp 3 HD: Chirp cuts the end of very short texts ("die Verspätung" stopped mid-sound),
# Neural2 lets the word fade out naturally. Long texts (tools/audio.py) stay on Chirp.
VOICE = 'de-DE-Neural2-G'
RATE = 0.9
AGENT = 'tts-batch-script/1.0'
NOUN = {'der', 'die', 'das'}


def key_of(text):
    return ' '.join(text.lower().split())


def spoken_texts():
    out = []
    for level in ['a1', 'a2', 'b1', 'b2']:
        content = json.load(open(os.path.join(REPO, 'Resources', 'content', f'{level}.json'), encoding='utf-8'))
        for w in content['words']:
            out.append(f"{w['type']} {w['de']}" if w['type'] in NOUN else w['de'])
        for t in json.load(open(os.path.join(REPO, 'Resources', 'content', f'daily_{level}.json'), encoding='utf-8'))['texts']:
            for g in t['glossary']:
                out.append(f"{g['art']} {g['lemma']}" if g.get('art') else g['lemma'])
    lexicon = os.path.join(REPO, 'Resources', 'content', 'lexicon.json')
    if os.path.exists(lexicon):
        for g in json.load(open(lexicon, encoding='utf-8'))['forms']:
            out.append(f"{g['art']} {g['lemma']}" if g.get('art') else g['lemma'])
    seen, unique = set(), []
    for text in out:
        text = ' '.join(text.split())
        if text and key_of(text) not in seen:
            seen.add(key_of(text))
            unique.append(text)
    return unique


def google_key():
    for line in open(KEYS, encoding='utf-8-sig'):
        if line.startswith('GOOGLE_KEY='):
            return line.split('=', 1)[1].strip()
    sys.exit('No GOOGLE_KEY in ' + KEYS)


def synthesize(key, text):
    body = json.dumps({
        'input': {'text': text},
        'voice': {'languageCode': 'de-DE', 'name': VOICE},
        'audioConfig': {'audioEncoding': 'MP3', 'speakingRate': RATE, 'sampleRateHertz': 24000},
    }).encode('utf-8')
    request = urllib.request.Request(f'https://texttospeech.googleapis.com/v1/text:synthesize?key={key}', data=body,
                                     headers={'Content-Type': 'application/json', 'User-Agent': AGENT}, method='POST')
    with urllib.request.urlopen(request, timeout=60) as reply:
        return base64.b64decode(json.load(reply)['audioContent'])


def main():
    dry = '--dry' in sys.argv
    max_chars = next((int(a.split('=')[1]) for a in sys.argv if a.startswith('--max-chars=')), 200_000)
    index_path = os.path.join(OUT, 'words.json')
    items = {}  # rebuilt every run from the files of the current voice
    folder = os.path.join(OUT, 'w')
    os.makedirs(folder, exist_ok=True)

    texts = spoken_texts()
    jobs = []
    for text in texts:
        digest = hashlib.sha1(f'{VOICE}|{text}'.encode('utf-8')).hexdigest()[:12]
        path = os.path.join(folder, f'{digest}.mp3')
        if os.path.exists(path) and os.path.getsize(path) > 500:
            items[key_of(text)] = digest
        else:
            jobs.append((text, digest, path))
    chars = sum(len(j[0]) for j in jobs)
    print(f'{len(texts)} words, {len(jobs)} to make, {chars:,} characters (limit {max_chars:,})')
    if dry or not jobs:
        json.dump({'items': items}, open(index_path, 'w', encoding='utf-8'), ensure_ascii=False, sort_keys=True)
        return
    if chars > max_chars:
        sys.exit('Over the limit: pass --max-chars=N')

    key = google_key()
    tool = audio_pad.ffmpeg()
    failed = []

    def make(job):
        text, digest, path = job
        # Google allows a limited number of requests per minute: wait and try again on 429.
        for attempt in range(8):
            try:
                audio = synthesize(key, text)
                with open(path, 'wb') as f:  # only after a good answer, so a failure leaves no empty file
                    f.write(audio)
                audio_pad.pad(path, tool)
                return job, None
            except urllib.error.HTTPError as e:
                if e.code != 429:
                    return job, f'{e.code}'
            except OSError as e:
                if attempt >= 3:
                    return job, str(e)[:60]
            time.sleep(min(60, 5 * 2 ** attempt))
        return job, 'retries'

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for n, (job, error) in enumerate(pool.map(make, jobs), 1):
            if error:
                failed.append((job[0], error))
            else:
                items[key_of(job[0])] = job[1]
            if n % 250 == 0:
                print(f'  {n}/{len(jobs)}')
                json.dump({'items': items}, open(index_path, 'w', encoding='utf-8'), ensure_ascii=False, sort_keys=True)
    json.dump({'items': items}, open(index_path, 'w', encoding='utf-8'), ensure_ascii=False, sort_keys=True)
    audio_pad.mark([j[2] for j in jobs if os.path.exists(j[2])])
    size = sum(os.path.getsize(os.path.join(folder, f)) for f in os.listdir(folder))
    print(f'made {len(jobs) - len(failed)}, failed {len(failed)}; words.json {len(items)} items; w/ folder {size / 1e6:.1f} MB')
    for text, error in failed[:15]:
        print(f'  failed: {text} ({error})')


if __name__ == '__main__':
    main()
