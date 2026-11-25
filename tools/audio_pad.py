"""Adds a short silence before and after recorded audio, so the first syllable is not lost while the iPhone
wakes up its speaker or Bluetooth headphones (a clip that starts right with "das" sounded cut).

    python -I -X utf8 tools/audio_pad.py          pads every MP3 in ../deschly-site/audio that is not padded yet

audio/padded.json lists the files already padded, so running it again changes nothing.
tools/audio.py and tools/word_audio.py pad new files themselves.
"""
import glob
import json
import os
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(REPO)
AUDIO = os.path.join(ROOT, 'deschly-site', 'audio')
LIST = os.path.join(AUDIO, 'padded.json')
BEFORE_MS = 300
AFTER_S = 0.25


def ffmpeg():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        found = glob.glob(os.path.join(ROOT, 'tts', 'piper-env', 'Lib', 'site-packages', 'imageio_ffmpeg', 'binaries', 'ffmpeg-*.exe'))
        if not found:
            sys.exit('ffmpeg not found: pip install imageio-ffmpeg')
        return found[0]


def load():
    return set(json.load(open(LIST, encoding='utf-8'))) if os.path.exists(LIST) else set()


def save(done):
    json.dump(sorted(done), open(LIST, 'w', encoding='utf-8'), indent=0)


def pad(path, tool=None):
    """Rewrites one MP3 with silence before and after (mono, 24 kHz)."""
    tool = tool or ffmpeg()
    handle, temp = tempfile.mkstemp(suffix='.mp3', dir=os.path.dirname(path))
    os.close(handle)
    try:
        subprocess.run([tool, '-y', '-loglevel', 'error', '-i', path,
                        '-af', f'adelay={BEFORE_MS}:all=1,apad=pad_dur={AFTER_S}',
                        '-ac', '1', '-ar', '24000', '-c:a', 'libmp3lame', '-b:a', '64k', temp], check=True)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.remove(temp)


def mark(paths):
    done = load()
    done.update(os.path.relpath(p, AUDIO).replace('\\', '/') for p in paths)
    save(done)


def main():
    tool = ffmpeg()
    done = load()
    files = [p for p in glob.glob(os.path.join(AUDIO, '**', '*.mp3'), recursive=True)
             if os.path.relpath(p, AUDIO).replace('\\', '/') not in done and os.path.getsize(p) > 500]
    print(f'{len(files)} files to pad')
    for n, path in enumerate(files, 1):
        pad(path, tool)
        done.add(os.path.relpath(path, AUDIO).replace('\\', '/'))
        if n % 500 == 0:
            save(done)
            print(f'  {n}/{len(files)}')
    save(done)
    print('done')


if __name__ == '__main__':
    main()
