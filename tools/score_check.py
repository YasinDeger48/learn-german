"""Checks the writing / speaking score rules (Sources/Core/Services/TaskScore.swift) against graded sample answers.

    python -I -X utf8 tools/score_check.py requests     writes ../icerik/gorev/puanlama_istek_<level>.txt (Codex)
    python -I -X utf8 tools/score_check.py check        reads ../icerik/gorev/puanlama_cevap_<level>.txt, prints
                                                        every sample whose rule score is outside its band

A sample answer is one JSON line: {"task": "a1-m1", "kind": "writing" | "speaking", "band": "top" | "good" |
"weak" | "off", "text": "..."}. Bands: top 85-100, good 65-84, weak 35-64, off 0-34.
This is a Python copy of the rules that need no phone: content points, length, greeting / closing, Sie, linking
words, words per minute (speaking samples count as spoken in the task's seconds). The spell check and Lina only run
on the phone, so the language criterion is left out here. Keep the copy in step with TaskScore.swift.
"""
import json
import os
import re
import sys
import unicodedata

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
GOREV = os.path.join(os.path.dirname(REPO), 'icerik', 'gorev')
LEVELS = ('A1', 'A2', 'B1', 'B2')
BANDS = {'top': (85, 100), 'good': (65, 84), 'weak': (35, 64), 'off': (0, 34)}
CONNECTORS = set('weil dass denn deshalb deswegen darum aber sondern obwohl wenn falls damit trotzdem außerdem ob '
                 'während bevor nachdem zuerst danach schließlich jedoch allerdings daher einerseits andererseits'.split())



def load(name):
    return json.load(open(os.path.join(CONTENT, name), encoding='utf-8'))


def split(text):
    return [w for w in re.split(r'[ \n\-–/]+', text) if w]


def key(word):
    """Like SpeechScore.key: lower case, ß → ss, accents dropped (ä → a), letters and digits only."""
    w = unicodedata.normalize('NFKD', word.lower().replace('ß', 'ss'))
    return ''.join(c for c in w if c.isalnum() and not unicodedata.combining(c))


def close(a, b):
    if a == b:
        return True
    if len(a) < 5 or abs(len(a) - len(b)) > 1:
        return False
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1] <= 1


def same(heard, wanted):
    if len(wanted) <= 3:
        return heard == wanted
    return heard.startswith(wanted) or close(heard, wanted)


def mentions(text, phrases):
    heard = [k for k in map(key, split(text)) if k]
    for phrase in phrases:
        wanted = [k for k in map(key, split(phrase)) if k]
        if not wanted or len(heard) < len(wanted):
            continue
        for start in range(len(heard) - len(wanted) + 1):
            if all(same(heard[start + i], w) for i, w in enumerate(wanted)):
                return True
    return False


def rank(level):
    return LEVELS.index(level.upper()) if level.upper() in LEVELS else 0


def score_writing(task, text, greeting, closing):
    words = split(text)
    min_words = task.get('minWords') or 25
    points = task.get('points') or []
    covered = sum(1 for p in points if mentions(text, p['keys']))
    content = covered / len(points) if points else 1
    share = min(1, len(words) / max(1, min_words))
    if share < 0.5:
        content *= share * 2
    checks = []
    if task['kind'] != 'forum':
        checks += [mentions(text, greeting), mentions(text, closing)]
    checks.append(len(words) >= min_words)
    if task.get('formal'):
        plain = [w.strip('.,!?;:') for w in words]
        polite = any(w in ('Sie', 'Ihnen', 'Ihr', 'Ihre', 'Ihren', 'Ihrem', 'Ihrer') for w in plain)
        familiar = any(w.lower() in ('du', 'dich', 'dir', 'dein', 'deine', 'deinen', 'deinem') for w in plain)
        checks.append(polite and not familiar)
    if rank(task['level']) >= 2:
        checks.append(sum(1 for w in words if key(w) in {key(c) for c in CONNECTORS}) >= 2)
    form = sum(checks) / max(1, len(checks))
    return round((content * 0.5 + form * 0.25) / 0.75 * 100)


def score_speaking(task, text):
    words = split(text)
    points = task['points']
    covered = sum(1 for p in points if mentions(text, p['keys']))
    content = 0 if len(words) < 5 or not points else covered / len(points)
    per_minute = len(words) / max(10, task['seconds']) * 60
    base = [35, 45, 60, 75][rank(task['level'])]
    fluency = 1 if per_minute >= base else 0.66 if per_minute >= base * 0.7 else 0.33 if per_minute >= base * 0.45 else 0
    if len(words) < 5:
        fluency = 0
    # Clear speech cannot be judged from text: counted as clear.
    return round((content * 0.5 + fluency * 0.2 + 0.15) / 0.85 * 100)


def requests():
    writing = load('writing.json')
    speaking = load('speaking.json')['tasks']
    os.makedirs(GOREV, exist_ok=True)
    for level in LEVELS:
        lines = []
        for task in writing['tasks']:
            if task['level'] == level and task['kind'] != 'form':
                lines.append(json.dumps({'task': task['id'], 'kind': 'writing', 'prompt': task.get('prompt'),
                                         'points': [p['say'] for p in task.get('points') or []],
                                         'minWords': task.get('minWords'), 'formal': bool(task.get('formal'))},
                                        ensure_ascii=False))
        for task in speaking:
            if task['level'] == level:
                lines.append(json.dumps({'task': task['id'], 'kind': 'speaking', 'prompt': task['prompt'],
                                         'points': [p['say'] for p in task['points']], 'seconds': task['seconds']},
                                        ensure_ascii=False))
        head = f'''PUANLAMA ÖRNEKLERİ {level} — Deschly (yazma ve konuşma puanlayıcısını sınamak için)

Aşağıdaki her görev için 4 örnek cevap yaz: "top" (çok iyi, 85-100 puanlık), "good" (iyi, 65-84), "weak" (zayıf,
35-64), "off" (konu dışı ya da çok kısa, 0-34). Seviyeye uygun Almanca; gerçek bir öğrenci gibi.
- top: bütün noktalar, doğru dil, tam uzunluk (yazmada hitap ve kapanış, resmî görevde Sie).
- good: noktaların çoğu, birkaç küçük hata.
- weak: noktaların yarısı ya da daha azı, kısa, hatalı.
- off: başka konu ya da 1-2 cümle.
Konuşma örnekleri konuşmanın yazıya dökülmüş hali gibi olsun: noktalama yok, küçük harf olabilir, görevin
saniyesi kadar konuşulabilecek uzunlukta.

Cevap dosyası: icerik\\gorev\\puanlama_cevap_{level}.txt
Her örnek bir satır JSON, başka bir şey yazma:
{{"task": "<id>", "kind": "writing" | "speaking", "band": "top" | "good" | "weak" | "off", "text": "..."}}

GÖREVLER ({len(lines)} görev, {len(lines) * 4} örnek):
'''
        path = os.path.join(GOREV, f'puanlama_istek_{level}.txt')
        open(path, 'w', encoding='utf-8', newline='\n').write(head + '\n'.join(lines) + '\n')
        print(path, len(lines), 'tasks')


def check():
    writing = load('writing.json')
    tasks = {t['id']: t for t in writing['tasks']}
    talks = {t['id']: t for t in load('speaking.json')['tasks']}
    total = wrong = 0
    for level in LEVELS:
        path = os.path.join(GOREV, f'puanlama_cevap_{level}.txt')
        if not os.path.exists(path):
            continue
        for line in open(path, encoding='utf-8'):
            line = line.strip()
            if not line:
                continue
            sample = json.loads(line)
            if sample['kind'] == 'writing' and sample['task'] in tasks:
                got = score_writing(tasks[sample['task']], sample['text'], writing['greeting'], writing['closing'])
            elif sample['kind'] == 'speaking' and sample['task'] in talks:
                got = score_speaking(talks[sample['task']], sample['text'])
            else:
                print('unknown task', sample['task'])
                continue
            low, high = BANDS[sample['band']]
            total += 1
            # One band of slack: the language criterion (spell check, Lina) is missing here.
            if got < low - 15 or got > high + 15:
                wrong += 1
                print(f"{sample['task']:8} {sample['band']:5} expected {low}-{high}, rules gave {got}: {sample['text'][:70]}")
    print(f'{total - wrong}/{total} samples in their band')


if __name__ == '__main__':
    {'requests': requests, 'check': check}.get(sys.argv[1] if len(sys.argv) > 1 else '', lambda: print(__doc__))()
