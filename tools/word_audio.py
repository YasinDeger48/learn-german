"""Natural voice (Google Neural2, a woman's voice) for single words: every level word as the app says it
("der Bahnhof", "gehen") and every glossary word of the daily texts.

    python -I -X utf8 tools/word_audio.py --dry     counts what is missing
    python -I -X utf8 tools/word_audio.py           makes the missing MP3s
    python -I -X utf8 tools/word_audio.py --sentences [--max-chars=200000]
        also the sentences the app speaks (examples, grammar, phrases, Hören dialogs, daily text sentences, ...),
        A1 first. Each run makes at most --max-chars characters and the next run goes on where it stopped,
        so the Google quota can be spread over the months.

Hören dialog lines are spoken by three voices; the man's and the announcer's lines are keyed "1|<text>" and
"2|<text>" in words.json (the woman's lines use the plain key, like words).

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
# Hören dialogs: speaker 1 = man, 2 = announcer (A1Line.s in the app).
SPEAKER_VOICES = {1: 'de-DE-Neural2-B', 2: 'de-DE-Neural2-D'}
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


def split_sentences(paragraph):
    """Same split as ReadingQuiz.sentences(of:) in the app."""
    out, current = [], ''
    for i, ch in enumerate(paragraph):
        current += ch
        end = i == len(paragraph) - 1
        if ch in '.!?' and (end or paragraph[i + 1] == ' '):
            if current.strip():
                out.append(current.strip())
            current = ''
    if current.strip():
        out.append(current.strip())
    return out


def spoken_sentences():
    """(speaker, text) the app speaks besides single words, most useful first: level by level from A1."""
    content = os.path.join(REPO, 'Resources', 'content')

    def load(name):
        path = os.path.join(content, name)
        return json.load(open(path, encoding='utf-8')) if os.path.exists(path) else None

    units = (load('units.json') or {}).get('units', [])
    memorize = (load('memorize.json') or {}).get('sheets', [])
    speaking = (load('speaking.json') or {}).get('tasks', [])
    out = []
    for level in ['a1', 'a2', 'b1', 'b2']:
        data = load(f'{level}.json') or {}
        level_up = level.upper()
        # Heard before answering first (Hören, dictation), then everything spoken after an answer.
        for item in data.get('hoeren', []):
            out += [(line['s'], line['t']) for line in item['lines']]
        # Song lines: Lina reads a line when it is tapped in the karaoke (SongPlayerView).
        for song in (load(f'songs_{level}.json') or {}).get('songs', []):
            out += [(-1, line['de']) for line in song['lines']]
        for text in data.get('texts', []):
            out += [(-1, line) for line in text['de']]
        out += [(-1, p['de']) for u in units if u['level'] == level_up for p in u['phrases']]
        out += [(-1, s['options'][0]) for s in data.get('situations', []) if s['options']]
        out += [(-1, m['right']) for m in data.get('mistakes', [])]
        out += [(-1, r.get('x') or r.get('a')) for sh in memorize if sh['level'] == level_up for r in sh['rows']]
        out += [(-1, t['prompt']) for t in speaking if t['level'] == level_up]
        verbs = load(f'verbs_{level}.json') or {}
        for v in verbs.get('verbs', []):
            out += [(-1, e['de'] if isinstance(e, dict) else e) for e in v.get('examples', [])]
            # Tembel Mod reads the forms too (LazySlide.lines in the app): infinitive, ich/du/er, past, perfect,
            # future, and the verb's questions.
            out.append((-1, v['v']))
            out += [(-1, f'{p} {f}') for p, f in zip(['ich', 'du', 'er'], v.get('praesens', []))]
            if v.get('praeteritum'):
                out.append((-1, f"ich {v['praeteritum'][0]}"))
            out += [(-1, f"er {v['perfekt']}"), (-1, f"er {v['futur']}")]
            out += [(-1, q['de']) for q in v.get('questions', [])]
        for w in data.get('words', []):
            out += [(-1, ex['de']) for ex in w.get('ex', [])]
            if w.get('type') in ('der', 'die', 'das') and w.get('plural'):
                out.append((-1, f"die {w['plural']}"))  # Tembel Mod says the plural
        for g in data.get('grammarItems', []):
            if g['options']:
                out.append((-1, g['q'].replace('___', g['options'][0].replace(' … ', ' '))))
        for t in (load(f'daily_{level}.json') or {}).get('texts', []):
            for paragraph in t['paragraphs']:
                out += [(-1, sentence) for sentence in split_sentences(paragraph)]
    seen, unique = set(), []
    for speaker, text in out:
        text = ' '.join(str(text or '').split())
        speaker = speaker if speaker in SPEAKER_VOICES else -1
        key = (speaker, key_of(text))
        if text and key not in seen:
            seen.add(key)
            unique.append((speaker, text))
    return unique


def google_key():
    for line in open(KEYS, encoding='utf-8-sig'):
        if line.startswith('GOOGLE_KEY='):
            return line.split('=', 1)[1].strip()
    sys.exit('No GOOGLE_KEY in ' + KEYS)


def synthesize(key, text, voice=VOICE):
    body = json.dumps({
        'input': {'text': text},
        'voice': {'languageCode': 'de-DE', 'name': voice},
        'audioConfig': {'audioEncoding': 'MP3', 'speakingRate': RATE, 'sampleRateHertz': 24000},
    }).encode('utf-8')
    request = urllib.request.Request(f'https://texttospeech.googleapis.com/v1/text:synthesize', data=body,
                                     headers={'Content-Type': 'application/json', 'User-Agent': AGENT, 'X-Goog-Api-Key': key}, method='POST')
    with urllib.request.urlopen(request, timeout=60) as reply:
        return base64.b64decode(json.load(reply)['audioContent'])


def main():
    dry = '--dry' in sys.argv
    max_chars = next((int(a.split('=')[1]) for a in sys.argv if a.startswith('--max-chars=')), 200_000)
    index_path = os.path.join(OUT, 'words.json')
    items = {}  # rebuilt every run from the files of the current voice
    folder = os.path.join(OUT, 'w')
    os.makedirs(folder, exist_ok=True)

    texts = [(-1, t) for t in spoken_texts()]
    words = len(texts)
    if '--sentences' in sys.argv:
        texts += spoken_sentences()
    jobs = []
    for speaker, text in texts:
        voice = SPEAKER_VOICES.get(speaker, VOICE)
        index_key = f'{speaker}|{key_of(text)}' if speaker in SPEAKER_VOICES else key_of(text)
        if index_key in items:
            continue
        digest = hashlib.sha1(f'{voice}|{text}'.encode('utf-8')).hexdigest()[:12]
        path = os.path.join(folder, f'{digest}.mp3')
        if os.path.exists(path) and os.path.getsize(path) > 500:
            items[index_key] = digest
        else:
            jobs.append((text, digest, path, voice, index_key))
    chars = sum(len(j[0]) for j in jobs)
    print(f'{words} words, {len(texts) - words} sentences; {len(jobs)} to make, {chars:,} characters')
    # Stay under the limit: take jobs in order (most useful first); the next run goes on from there.
    batch, used = [], 0
    for job in jobs:
        if used + len(job[0]) > max_chars:
            break
        batch.append(job)
        used += len(job[0])
    if len(batch) < len(jobs):
        print(f'this run: {len(batch)} files, {used:,} characters (limit {max_chars:,}); '
              f'{len(jobs) - len(batch)} left for the next run')
    jobs = batch
    if dry or not jobs:
        json.dump({'items': items}, open(index_path, 'w', encoding='utf-8'), ensure_ascii=False, sort_keys=True)
        return

    key = google_key()
    tool = audio_pad.ffmpeg()
    failed = []

    def make(job):
        text, digest, path, voice, _ = job
        # Google allows a limited number of requests per minute: wait and try again on 429.
        for attempt in range(8):
            try:
                audio = synthesize(key, text, voice)
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
                items[job[4]] = job[1]
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
