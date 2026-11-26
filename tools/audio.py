"""Natural voices for the daily texts and the path stories (Google Cloud Text-to-Speech, Chirp 3 HD).
In dialogues ("Lina: Hallo!") every speaker has an own voice and the name is not read (see dialogue_plan).

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
import re
import shutil
import subprocess
import sys
import tempfile
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


# Dialogues ("Lina: Hallo!"): every speaker has an own voice and the name is not read.
# Same rules as Dialogue in Sources/Core/Services/Speech.swift.
LABEL = re.compile(r'^([A-ZÄÖÜ][a-zäöüß]+(?: [A-ZÄÖÜ][a-zäöüß]+)?):\s+(\S.*)$')
NOT_A_NAME = {'Der', 'Die', 'Das', 'Ein', 'Eine', 'Sie', 'Er', 'Es', 'Ich', 'Wir', 'Aber', 'Und', 'Dann'}
MALE = {'Tom', 'Max', 'Ben', 'Paul', 'Jan', 'Lukas', 'Felix', 'Leon', 'David', 'Ali', 'Mehmet', 'Ahmet', 'Murat',
        'Emre', 'Peter', 'Thomas', 'Michael', 'Stefan', 'Jonas', 'Mann', 'Kellner', 'Arzt', 'Lehrer', 'Verkäufer',
        'Chef', 'Vater', 'Opa', 'Junge', 'Polizist', 'Fahrer', 'Nachbar', 'Kollege', 'Freund', 'Busfahrer'}
FEMALE_POOL = ['de-DE-Chirp3-HD-Achernar', 'de-DE-Chirp3-HD-Kore', 'de-DE-Chirp3-HD-Aoede', 'de-DE-Chirp3-HD-Leda']
MALE_POOL = ['de-DE-Chirp3-HD-Achird', 'de-DE-Chirp3-HD-Charon', 'de-DE-Chirp3-HD-Puck', 'de-DE-Chirp3-HD-Orus']
FIXED = {'Lina': FEMALE_POOL[0], 'Elif': FEMALE_POOL[1]}  # the two heroines of the A1 stories
GAP = 0.45  # seconds of silence between two lines


def speaker(paragraph):
    """(name, words) when the paragraph is a dialogue line, else None."""
    match = LABEL.match(paragraph.strip())
    if not match or match.group(1).split()[0] in NOT_A_NAME:
        return None
    return match.group(1), match.group(2)


def is_male(name):
    return name.startswith('Herr ') or name.split()[0] in MALE


def dialogue_plan(text, narrator):
    """[(voice, words)] for a dialogue text (title and narration in the narrator's voice), or None."""
    lines = [speaker(p) for p in text['paragraphs']]
    if sum(1 for x in lines if x) < 2:
        return None
    voices, used = {}, set()
    for x in lines:
        if not x or x[0] in voices:
            continue
        name = x[0]
        pool = MALE_POOL if is_male(name) else FEMALE_POOL
        voice = FIXED.get(name)
        if not voice or voice in used:
            voice = next((v for v in pool if v not in used), pool[len(voices) % len(pool)])
        voices[name] = voice
        used.add(voice)
    plan = [(narrator, text['title'] + '.')]
    for paragraph, x in zip(text['paragraphs'], lines):
        plan.append((voices[x[0]], x[1]) if x else (narrator, paragraph))
    return plan


def join(parts, path):
    """Joins MP3 parts into one file with GAP seconds of silence after each."""
    tool = audio_pad.ffmpeg()
    folder = tempfile.mkdtemp()
    try:
        inputs, chains = [], []
        for n, data in enumerate(parts):
            part = os.path.join(folder, f'{n}.mp3')
            open(part, 'wb').write(data)
            inputs += ['-i', part]
            chains.append(f'[{n}:a]aresample=24000,aformat=channel_layouts=mono,apad=pad_dur={GAP}[a{n}]')
        graph = ';'.join(chains) + ';' + ''.join(f'[a{n}]' for n in range(len(parts))) + f'concat=n={len(parts)}:v=0:a=1[out]'
        os.makedirs(os.path.dirname(path), exist_ok=True)
        subprocess.run([tool, '-y', '-loglevel', 'error', *inputs, '-filter_complex', graph, '-map', '[out]',
                        '-ac', '1', '-ar', '24000', '-c:a', 'libmp3lame', '-b:a', '64k', path], check=True)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


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
        texts = []
        for name in (f'daily_{level}.json', f'stories_{level}.json'):  # the daily texts and the path stories
            source = os.path.join(REPO, 'Resources', 'content', name)
            if os.path.exists(source):
                texts += json.load(open(source, encoding='utf-8'))['texts']
        for text in texts:
            for short in VOICES:
                plan = dialogue_plan(text, VOICES[short])
                content = spoken(text) if plan is None else json.dumps(plan, ensure_ascii=False)
                digest = hashlib.sha256(content.encode('utf-8')).hexdigest()[:16]
                path = os.path.join(SITE_AUDIO, short, f"{text['id']}.mp3")
                if index.get(text['id'], {}).get(short) == digest and os.path.exists(path):
                    continue
                jobs.append((text['id'], short, content, plan, digest, path))

    # Dialogue lines in the same voice are recorded once for both versions.
    pieces = {(VOICES[j[1]], j[2]) for j in jobs if j[3] is None} | {piece for j in jobs if j[3] for piece in j[3]}
    total = sum(len(words) for _, words in pieces)
    print(f'{len(jobs)} files to make ({sum(1 for j in jobs if j[3])} dialogues), {total:,} characters (limit {max_chars:,})')
    if dry or not jobs:
        return
    if total > max_chars:
        sys.exit('Over the limit: run fewer levels or pass --max-chars=N')

    key = google_key()
    made = 0
    recorded = {}
    for text_id, short, content, plan, digest, path in jobs:
        try:
            if plan is None:
                audio = synthesize(key, VOICES[short], content)
            else:
                for piece in plan:
                    if piece not in recorded:
                        recorded[piece] = synthesize(key, *piece)
        except urllib.error.HTTPError as e:
            print(f'  {text_id} {short}: error {e.code} {e.read()[:160]!r}')
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if plan is None:
            with open(path, 'wb') as f:
                f.write(audio)
        else:
            join([recorded[piece] for piece in plan], path)
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
