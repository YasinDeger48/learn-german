"""Builds Widgets/Resources/widget_words.json: a compact word list per level for the widgets.

    python -I -X utf8 tools/widget_words.py

Each word: d (German), a (der/die/das or ""), tr, en (meaning), x (example), xtr, xen (example meaning).
The widget extension cannot read the app's data, so it carries its own copy. Run again after content changes.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CORE_THEME = 15          # A1 "core" phrases (A1BankBuilder.coreTheme)
PER_LEVEL = 600


def main():
    out = {}
    for level in ('a1', 'a2', 'b1', 'b2'):
        data = json.load(open(os.path.join(REPO, 'Resources', 'content', f'{level}.json'), encoding='utf-8'))
        words = []
        for w in data['words']:
            if w.get('theme') == CORE_THEME or not w.get('ex') or w['type'] == 'pl':
                continue
            ex = w['ex'][0]
            mean, exmean = w['mean'], ex['mean']
            words.append({
                'd': w['de'],
                'a': w['type'] if w['type'] in ('der', 'die', 'das') else '',
                'tr': mean.get('tr', ''),
                'en': mean.get('en') or mean.get('tr', ''),
                'x': ex['de'],
                'xtr': exmean.get('tr', ''),
                'xen': exmean.get('en') or exmean.get('tr', ''),
            })
        # Spread over the list so a capped set still mixes nouns, verbs and other words.
        step = max(1, len(words) // PER_LEVEL)
        out[level.upper()] = words[::step][:PER_LEVEL]
    dest = os.path.join(REPO, 'Widgets', 'Resources', 'widget_words.json')
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    json.dump(out, open(dest, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, separators=(',', ':'))
    print({k: len(v) for k, v in out.items()}, f'{os.path.getsize(dest) // 1024} KB → {dest}')


if __name__ == '__main__':
    main()
