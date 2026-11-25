"""Repairs text whose non-ASCII characters became question marks (UTF-8 bytes → '?': ü → ??, … → ???).

    python -I -X utf8 tools/fix_broken_text.py              dry run: what would change, what stays unclear
    python -I -X utf8 tools/fix_broken_text.py --write      writes the repaired content files

Only strings of {"tr": …, "en": …} objects are touched, and only when they contain '??'. The Turkish text of the same
object is intact and is the reference:
  * a run of '?' inside a word (w??rde) is a letter: the spelling that exists elsewhere in the content wins (würde);
  * other runs are punctuation (… · → „ “ – ’): taken from the Turkish text in the same order, matched by byte length;
    a trailing real '?' is kept (Sie ???? → Sie …?).
Strings it cannot repair with certainty are left unchanged and listed, for ChatGPT.
"""
import glob
import itertools
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
LETTERS = 'A-Za-zÀ-ÖØ-öø-ÿ'
CANDIDATES = ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü', 'é', 'è', 'à', 'ç', 'ı', 'ş', 'ğ']
TOKEN = re.compile(rf'[{LETTERS}?]*[{LETTERS}][{LETTERS}?]*|[{LETTERS}?]*\?\?[{LETTERS}?]*[{LETTERS}][{LETTERS}?]*')


def walk_strings(o, out):
    if isinstance(o, str):
        out.append(o)
    elif isinstance(o, dict):
        for v in o.values():
            walk_strings(v, out)
    elif isinstance(o, list):
        for v in o:
            walk_strings(v, out)


def vocabulary():
    """How often each correctly written word occurs in the content (lower case)."""
    from collections import Counter
    words = Counter()
    for path in glob.glob(os.path.join(CONTENT, '*.json')):
        found = []
        walk_strings(json.load(open(path, encoding='utf-8')), found)
        for text in found:
            if '??' not in text:
                words.update(w.lower() for w in re.findall(rf'[{LETTERS}]+', text))
    return words


def fix_word(token, vocab, reference=''):
    """'w??rde' → 'würde'. First the intact reference text (same spelling there), then the content's vocabulary
    (a clear favourite by frequency). None when unclear."""
    trail = re.search(r'(?<!\?)\?$', token)  # a real question mark after the word: wor??ber?
    if trail and not token.endswith('??'):
        fixed = fix_word(token[:-1], vocab, reference)
        return None if fixed is None else fixed + '?'
    parts = re.split(r'(\?\?)', token)
    holes = [i for i, p in enumerate(parts) if p == '??']
    if not holes or any('?' in p for i, p in enumerate(parts) if i not in holes):
        return None
    # 1. The reference has the word: build a pattern with one letter per hole.
    pattern = ''.join('([^\W\d_])' if i in holes else re.escape(p) for i, p in enumerate(parts))
    hits = {m.group(0) for m in re.finditer(rf'(?<![{LETTERS}]){pattern}(?![{LETTERS}])', reference, re.IGNORECASE)}
    hits = {h for h in hits if all(ord(c) > 127 for c, i in zip(re.fullmatch(pattern, h, re.IGNORECASE).groups(), holes))}
    if len({h.lower() for h in hits}) == 1:
        h = hits.pop()
        # keep the token's own capitalisation of the first letter
        return (h[0].upper() if token[0].isupper() else h[0].lower()) + h[1:] if parts[0] else h
    # 2. The vocabulary: capitals only at the start of the word.
    found = {}
    for combo in itertools.product(CANDIDATES, repeat=len(holes)):
        if any(c.isupper() and i != 0 for c, i in zip(combo, holes)):
            continue
        trial = list(parts)
        for i, c in zip(holes, combo):
            trial[i] = c
        word = ''.join(trial)
        count = vocab.get(word.lower(), 0)
        if count:
            found[word] = count
    if not found:
        return None
    ranked = sorted(found.items(), key=lambda kv: -kv[1])
    lowered = {w.lower() for w in found}
    if len(lowered) == 1:
        # same word, only the capital differs: follow the token (a hole at the start of a sentence is a capital)
        return next((w for w in found if w[0].isupper() == (holes[0] == 0 and parts[0] == '' and token[:1] == '?')), ranked[0][0])
    best, second = ranked[0][1], ranked[1][1]
    return ranked[0][0] if best >= 3 * second else None


def punctuation(reference):
    """Non-ASCII, non-letter characters of the intact text, in order."""
    return [c for c in reference if ord(c) > 127 and not c.isalpha()]


def repair(text, reference, vocab):
    """Returns (repaired text or None, list of problems)."""
    problems = []

    def word(m):
        token = m.group(0)
        if '??' not in token or not re.search(rf'[{LETTERS}]', token):
            return token
        fixed = fix_word(token, vocab, reference)
        if fixed is None:
            problems.append(f'word {token!r}')
            return token
        return fixed

    text = re.sub(rf'[{LETTERS}?]*[{LETTERS}][{LETTERS}?]*', lambda m: word(m) if re.search(rf'[{LETTERS}]\?\?|\?\?[{LETTERS}]', m.group(0)) else m.group(0), text)

    marks = punctuation(reference)
    out, i = [], 0
    for m in re.finditer(r'\?{2,}', text):
        out.append(text[i:m.start()])
        run = len(m.group(0))
        replaced = None
        # The next mark(s) of the reference, if their UTF-8 length is exactly the run (or the run minus a real '?'
        # at the end, for runs of 4+: Sie ???? → Sie …?). A mark of another length is not used: the reference may
        # simply have fewer marks than the broken text.
        for keep_question in ((False, True) if run >= 4 else (False,)):
            need = run - (1 if keep_question else 0)
            taken, size = [], 0
            for c in marks:
                if size >= need:
                    break
                taken.append(c)
                size += len(c.encode('utf-8'))
            if size == need and taken:
                del marks[:len(taken)]
                replaced = ''.join(taken) + ('?' if keep_question else '')
                break
        if replaced is None:
            replaced = {3: '…', 4: '…?', 2: '·', 6: '……'}.get(run)
            if replaced is None:
                problems.append(f'mark run of {run}')
                replaced = m.group(0)
            else:
                problems.append(f'guessed {m.group(0)} as {replaced}')
        out.append(replaced)
        i = m.end()
    out.append(text[i:])
    return ''.join(out), problems


def visit(o, vocab, report):
    if isinstance(o, dict):
        if isinstance(o.get('en'), str) and isinstance(o.get('tr'), str) and '??' in o['en'] and '??' not in o['tr']:
            fixed, problems = repair(o['en'], o['tr'], vocab)
            hard = [p for p in problems if not p.startswith('guessed')]
            report.append((o['en'], fixed, problems))
            if not hard and '??' not in fixed:
                o['en'] = fixed
        for v in o.values():
            visit(v, vocab, report)
    elif isinstance(o, list):
        for v in o:
            visit(v, vocab, report)


def main():
    write = '--write' in sys.argv
    vocab = vocabulary()
    total_fixed = total_left = 0
    leftovers = []
    for path in sorted(glob.glob(os.path.join(CONTENT, '*.json'))):
        raw = open(path, encoding='utf-8').read()
        if '??' not in raw:
            continue
        data = json.loads(raw)
        report = []
        visit(data, vocab, report)
        fixed = [r for r in report if not [p for p in r[2] if not p.startswith('guessed')] and '??' not in r[1]]
        left = [r for r in report if r not in fixed]
        total_fixed += len(fixed)
        total_left += len(left)
        leftovers += [(os.path.basename(path), r) for r in left]
        print(f'{os.path.basename(path)}: {len(fixed)} repaired, {len(left)} unclear')
        for before, after, problems in fixed[:3]:
            print(f'   {before[:90]}\n → {after[:90]}')
        guessed = sum(1 for r in fixed for p in r[2] if p.startswith('guessed'))
        if guessed:
            print(f'   ({guessed} marks guessed without a matching mark in the Turkish text)')
        if write and fixed:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                if raw.startswith('{"'):
                    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
                else:
                    json.dump(data, f, ensure_ascii=False, indent=1)
                    f.write('\n')
    for name, (before, _, problems) in leftovers[:20]:
        print(f'UNCLEAR {name}: {before[:80]}  [{"; ".join(problems[:3])}]')
    print(f'repaired {total_fixed}, unclear {total_left}' + ('' if write else '  (dry run; --write to save)'))


if __name__ == '__main__':
    main()
