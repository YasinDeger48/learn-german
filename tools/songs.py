"""Songs (Şarkılar): rhythmic chants over a beat made here, karaoke in the app.

    python -I -X utf8 tools/songs.py import A1      reads ../icerik/sarki/A1_sarki_cevap_*.txt -> Resources/content/songs_a1.json
    python -I -X utf8 tools/songs.py audio A1       makes the missing or changed songs -> ../deschly-site/audio/songs/<id>.mp3
    python -I -X utf8 tools/songs.py audio A1 --dry only counts the characters

Lyrics by Codex (../icerik/sarki/A1_sarki_istek.txt). Every line starts on a bar of the beat:
  Lina  – Lina's voice (the female reading voice), Tom – a male voice,
  Alle  – three voices together (a small choir) for the chorus,
  Du    – Lina says it, then one free bar so the learner sings it back ("Sen de söyle!").
The beat (kick, clap, hi-hat, a plucked chord pattern C–G–Am–F and a bass) is generated with ffmpeg, so there
is no music by anyone else in the app. songs_<level>.json keeps each line's start and end second for the karaoke.
Push the site afterwards (Gizlilik-Sitesi-Yukle.cmd).
"""
import array
import glob
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio  # noqa: E402  (synthesize, google_key, voices)
import audio_pad  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(ROOT, 'icerik', 'sarki')
OUT = os.path.join(ROOT, 'deschly-site', 'audio', 'songs')
RATE = 24000
LINA = audio.FEMALE_POOL[0]
CHOIR = [audio.FEMALE_POOL[0], audio.MALE_POOL[0], audio.FEMALE_POOL[1]]
TOM = audio.MALE_POOL[0]
WHO = {'Lina', 'Alle', 'Du', 'Tom'}  # Tom: a second singer some songs have (male voice)
PARTS = {'intro', 'verse', 'chorus', 'call', 'answer', 'outro'}
BEAT_VOLUME = 0.42
VERSION = 2  # change when the sound changes, so every song is made again


def out_path(level):
    return os.path.join(CONTENT, f'songs_{level.lower()}.json')


# MARK: import

def problems_of(song):
    out = []
    if not song.get('id') or not song.get('title') or not song.get('lines'):
        return ['no id/title/lines']
    for n, line in enumerate(song['lines']):
        if line.get('who') not in WHO or line.get('part') not in PARTS:
            out.append(f'line {n + 1}: who/part')
        if not all(isinstance(line.get(k), str) and line[k].strip() for k in ('de', 'tr', 'en')):
            out.append(f'line {n + 1}: de/tr/en missing')
        elif any(re.search(r'\w\?\w', line[k]) for k in ('de', 'tr')):
            out.append(f'line {n + 1}: broken letter ("?" inside a word): {line["de"]}')
    if sum(1 for line in song['lines'] if line.get('who') == 'Du') < 2:
        out.append('fewer than 2 "Du" lines')
    if not 60 <= int(song.get('bpm') or 0) <= 140:
        out.append('bpm')
    questions = song.get('questions') or []
    if len(questions) < 2 or any(q.get('type') not in ('mc', 'tf') or
                                 (q['type'] == 'mc' and not (0 <= q.get('answer', -1) < len(q.get('options') or []))) or
                                 (q['type'] == 'tf' and q.get('answer') not in (0, 1)) for q in questions):
        out.append('questions')
    return out


def import_answers(level):
    level = level.lower()
    path = out_path(level)
    songs = {s['id']: s for s in json.load(open(path, encoding='utf-8'))['songs']} if os.path.exists(path) else {}
    problems = []
    for answer in sorted(glob.glob(os.path.join(FOLDER, f'{level.upper()}_sarki_cevap_*.txt'))):
        for n, raw in enumerate(open(answer, encoding='utf-8-sig'), 1):
            raw = raw.strip().strip(',')
            if not raw.startswith('{'):
                continue
            try:
                song = json.loads(raw)
            except json.JSONDecodeError:
                problems.append(f'{os.path.basename(answer)}:{n} not JSON')
                continue
            found = problems_of(song)
            if found:
                problems.append(f"{os.path.basename(answer)} {song.get('id')}: " + '; '.join(found))
                continue
            old = songs.get(song['id'], {})
            for key in ('timeline', 'duration', 'audio', 'hash'):  # keep the made audio's data
                if key in old:
                    song[key] = old[key]
            songs[song['id']] = song
    save(level, songs)
    print(f'{level.upper()}: {len(songs)} songs in {path}')
    for p in problems:
        print('  ', p)


def save(level, songs):
    ordered = sorted(songs.values(), key=lambda s: s['id'])
    with open(out_path(level), 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'level': level.upper(), 'songs': ordered}, f, ensure_ascii=False, indent=1)
        f.write('\n')


# MARK: audio

def beat_expression(bpm):
    b = 60.0 / bpm
    bar = 4 * b
    # Chord per bar: C, G, Am, F (root Hz, third ratio: major 1.26, minor 1.189).
    root = f'if(eq(mod(floor(t/{bar}),4),0),261.63,if(eq(mod(floor(t/{bar}),4),1),196.0,if(eq(mod(floor(t/{bar}),4),2),220.0,174.61)))'
    third = f'if(eq(mod(floor(t/{bar}),4),2),1.189,1.26)'
    kick = f'0.85*sin(2*PI*(48+70*exp(-mod(t,{2 * b})*28))*mod(t,{2 * b}))*exp(-mod(t,{2 * b})*8)'
    clap = f'0.30*(2*random(0)-1)*exp(-mod(t+{b},{2 * b})*24)'
    hat = f'0.07*(2*random(1)-1)*exp(-mod(t,{b / 2})*80)'
    pluck = (f'0.10*exp(-mod(t,{b / 2})*7)*(sin(2*PI*{root}*t)+0.7*sin(2*PI*{root}*{third}*t)'
             f'+0.6*sin(2*PI*{root}*1.498*t)+0.25*sin(4*PI*{root}*t))')
    bass = f'0.22*sin(PI*{root}*t)*exp(-mod(t,{b})*3)'
    return f'{kick}+{clap}+{hat}+{pluck}+{bass}'


def ffmpeg():
    return audio_pad.ffmpeg()


def to_samples(mp3_bytes, folder, name):
    """Decodes MP3 bytes to 24 kHz mono 16-bit samples."""
    src = os.path.join(folder, name + '.mp3')
    dst = os.path.join(folder, name + '.wav')
    open(src, 'wb').write(mp3_bytes)
    subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-i', src, '-ac', '1', '-ar', str(RATE), '-sample_fmt', 's16', dst], check=True)
    with wave.open(dst) as w:
        return array.array('h', w.readframes(w.getnframes()))


def beat_samples(bpm, seconds, folder):
    dst = os.path.join(folder, 'beat.wav')
    subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-f', 'lavfi', '-i',
                    f"aevalsrc=exprs='{beat_expression(bpm)}':s={RATE}:d={seconds:.3f}",
                    '-af', 'highpass=f=35,alimiter=limit=0.9', '-ac', '1', '-ar', str(RATE), '-sample_fmt', 's16', dst], check=True)
    with wave.open(dst) as w:
        return array.array('h', w.readframes(w.getnframes()))


def mix_into(track, samples, start, gain=1.0):
    at = int(start * RATE)
    end = min(len(track), at + len(samples))
    for i in range(at, end):
        track[i] += int(samples[i - at] * gain)


def song_hash(song):
    text = json.dumps([VERSION, song['bpm'], [(l['who'], l['de']) for l in song['lines']]], ensure_ascii=False)
    return hashlib.sha256(text.encode('utf-8')).hexdigest()[:16]


def make_song(song, key, cache):
    bpm = int(song['bpm'])
    bar = 4 * 60.0 / bpm
    with tempfile.TemporaryDirectory() as folder:
        pieces = []
        for n, line in enumerate(song['lines']):
            text = line['de']
            if line['who'] == 'Alle':
                voices = []
                for v in CHOIR:
                    if (v, text) not in cache:
                        cache[(v, text)] = audio.synthesize(key, v, text)
                    voices.append(to_samples(cache[(v, text)], folder, f'{n}-{CHOIR.index(v)}'))
                length = max(len(v) for v in voices)
                choir = array.array('i', [0]) * length
                for v in voices:
                    for i, s in enumerate(v):
                        choir[i] += int(s * 0.55)
                pieces.append(choir)
            else:
                voice = TOM if line['who'] == 'Tom' else LINA
                if (voice, text) not in cache:
                    cache[(voice, text)] = audio.synthesize(key, voice, text)
                pieces.append(to_samples(cache[(voice, text)], folder, str(n)))
        # Timeline: one bar of beat first, every line on a bar, "Du" lines get a free bar to sing back.
        t = bar
        timeline = []
        for line, piece in zip(song['lines'], pieces):
            seconds = len(piece) / RATE
            bars = max(1, math.ceil((seconds + 0.15) / bar))
            entry = {'start': round(t, 3), 'end': round(t + seconds, 3)}
            t += bars * bar
            if line['who'] == 'Du':
                entry['echo'] = [round(t, 3), round(t + max(bar, seconds + 0.6), 3)]
                t += max(1, math.ceil((seconds + 0.6) / bar)) * bar
            timeline.append(entry)
        total = t + bar
        track = array.array('i', [0]) * int(total * RATE + RATE)
        beat = beat_samples(bpm, total + 0.5, folder)
        mix_into(track, beat, 0, BEAT_VOLUME)
        for entry, piece in zip(timeline, pieces):
            mix_into(track, piece, entry['start'], 1.0)
        peak = max(1, max(abs(x) for x in track))
        scale = min(1.0, 30000 / peak)
        pcm = array.array('h', (int(x * scale) for x in track))
        wav = os.path.join(folder, 'song.wav')
        with wave.open(wav, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        os.makedirs(OUT, exist_ok=True)
        mp3 = os.path.join(OUT, f"{song['id']}.mp3")
        subprocess.run([ffmpeg(), '-y', '-loglevel', 'error', '-i', wav, '-ac', '1', '-ar', str(RATE),
                        '-c:a', 'libmp3lame', '-b:a', '80k', mp3], check=True)
    return timeline, round(total, 3)


def make_audio(level, dry):
    level = level.lower()
    path = out_path(level)
    songs = {s['id']: s for s in json.load(open(path, encoding='utf-8'))['songs']}
    todo = [s for s in songs.values()
            if s.get('hash') != song_hash(s) or not os.path.exists(os.path.join(OUT, f"{s['id']}.mp3"))]
    chars = sum(len(l['de']) * (3 if l['who'] == 'Alle' else 1) for s in todo for l in s['lines'])
    print(f'{len(todo)} songs to make, about {chars:,} characters')
    if dry or not todo:
        return
    key = audio.google_key()
    cache = {}
    for song in todo:
        timeline, total = make_song(song, key, cache)
        song['timeline'] = timeline
        song['duration'] = total
        song['audio'] = f"songs/{song['id']}.mp3"
        song['hash'] = song_hash(song)
        save(level, songs)
        print(f"  {song['id']}: {total:.0f} s")


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else ''
    if command == 'import':
        import_answers(sys.argv[2])
    elif command == 'audio':
        make_audio(sys.argv[2], '--dry' in sys.argv)
    else:
        print(__doc__)
