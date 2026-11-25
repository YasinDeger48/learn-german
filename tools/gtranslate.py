"""Machine translation of the learner-language content with Google Cloud Translation (instead of ChatGPT by hand).

    python -I -X utf8 tools/gtranslate.py --dry                    characters still missing, per language and set
    python -I -X utf8 tools/gtranslate.py ku a2                    translate what is missing in one language / set
    python -I -X utf8 tools/gtranslate.py all all --max-chars=450000

Uses the same lists and memory as tools/translate.py: the English text is the source, the result goes to
tools/i18n/content_<lang>.json and into the content files. Answers from ChatGPT imported later replace a machine
translation (better quality); tools/i18n/machine_<lang>.json lists which texts came from Google.
German inside the English (words with umlauts, quoted German, "der Bahnhof", grammar terms, {0}) is protected so
it stays German. Key: ../tts/anahtarlar.txt (GOOGLE_KEY); the Cloud Translation API must be enabled for it.
Never costs money: Google gives 500,000 characters a month for free. Every character sent is counted in
tools/i18n/gtranslate_usage.json per calendar month (counted with the protection tags, so a little more than Google
counts) and a run stops at 450,000 for the month; the rest waits for next month. --max-chars only lowers that.
"""
import datetime
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import translate  # noqa: E402

KEYS = os.path.join(os.path.dirname(translate.REPO), 'tts', 'anahtarlar.txt')
AGENT = 'translate-batch-script/1.0'
BATCH_ITEMS = 100
BATCH_CHARS = 20000
MONTHLY_LIMIT = 450_000  # Google's free tier is 500,000 characters a month
USAGE = os.path.join(translate.MEMORY, 'gtranslate_usage.json')


def usage():
    month = datetime.date.today().strftime('%Y-%m')
    data = json.load(open(USAGE, encoding='utf-8')) if os.path.exists(USAGE) else {}
    return month, data


def add_usage(chars):
    month, data = usage()
    data[month] = data.get(month, 0) + chars
    os.makedirs(translate.MEMORY, exist_ok=True)
    json.dump(data, open(USAGE, 'w', encoding='utf-8', newline='\n'), indent=1)
GRAMMAR = ['Nominativ', 'Akkusativ', 'Dativ', 'Genitiv', 'Präsens', 'Präteritum', 'Perfekt', 'Plusquamperfekt',
           'Futur', 'Konjunktiv', 'Imperativ', 'Infinitiv', 'Partizip', 'Passiv', 'Modalverb', 'Nebensatz']
PROTECT = re.compile(
    r'\{\d+\}'                                   # placeholders
    r'|„[^“”"]*[“”"]|"[^"]+"|«[^»]+»'            # quoted German
    r'|\b(?:der|die|das|den|dem|des|ein|eine|einen|einem|einer)\s+[A-ZÄÖÜ][\wäöüß-]*'  # article + noun
    r'|\b[\w-]*[äöüßÄÖÜ][\w-]*'                  # any word with an umlaut or ß
    r'|\b(?:' + '|'.join(GRAMMAR) + r')\b')


def google_key():
    for line in open(KEYS, encoding='utf-8-sig'):
        if line.startswith('GOOGLE_KEY='):
            return line.split('=', 1)[1].strip()
    sys.exit('No GOOGLE_KEY in ' + KEYS)


def keep_as_is(en):
    """Lines that are German examples or formulas (ChatGPT kept them unchanged too)."""
    return '→' in en or not re.search('[A-Za-z]{3}', PROTECT.sub('', en))


def to_html(text):
    out, last = [], 0
    for m in PROTECT.finditer(text):
        out.append(html.escape(text[last:m.start()], quote=False))
        out.append(f'<span translate="no">{html.escape(m.group(0), quote=False)}</span>')
        last = m.end()
    out.append(html.escape(text[last:], quote=False))
    return ''.join(out).replace('\n', '<br>')


def from_html(text):
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'</?span[^>]*>', '', text)
    return html.unescape(text).replace(' \n', '\n').strip()


def tidy(text, lang):
    """Google leaves a space before punctuation next to a protected German word ("Dativ :", "für ،").
    French keeps its space before : ; ! ? (that is French typography)."""
    marks = r'[,.،؛]' if lang == 'fr' else r'[,.:;!?،؛]'
    return re.sub(r'[ \u00a0]+(' + marks + ')', r'\1', text)


def call(key, texts, lang):
    body = json.dumps({'q': [to_html(t) for t in texts], 'source': 'en', 'target': lang, 'format': 'html'}).encode()
    request = urllib.request.Request(f'https://translation.googleapis.com/language/translate/v2?key={key}', data=body,
                                     headers={'Content-Type': 'application/json', 'User-Agent': AGENT})
    for attempt in range(6):
        try:
            with urllib.request.urlopen(request, timeout=60) as reply:
                return [tidy(from_html(t['translatedText']), lang) for t in json.load(reply)['data']['translations']]
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 503):
                message = json.load(e).get('error', {}).get('message', '')
                sys.exit(f'Google Translation {e.code}: {message[:200]}')
        except OSError:
            if attempt >= 3:
                raise
        time.sleep(min(60, 4 * 2 ** attempt))
    sys.exit('Google Translation: too many retries')


def missing(lang, set_name):
    return [en for _, en, _ in translate.content_missing(lang, set_name)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry' in sys.argv
    month, data = usage()
    left = max(0, MONTHLY_LIMIT - data.get(month, 0))
    limit = min(left, next((int(a.split('=')[1]) for a in sys.argv if a.startswith('--max-chars=')), left))
    print(f'free characters left this month ({month}): {left:,}; this run at most {limit:,}')
    langs = list(translate.LANGS) if not args or args[0] == 'all' else [args[0]]
    sets = [s for s in translate.SETS] if len(args) < 2 or args[1] == 'all' else [args[1]]
    plan = []
    for lang in langs:
        for set_name in sets:
            texts = missing(lang, set_name)
            chars = sum(len(to_html(t)) for t in texts if not keep_as_is(t))
            print(f'{lang} {set_name}: {len(texts)} texts, {chars:,} characters to translate')
            plan.append((lang, set_name, texts))
    if dry:
        return
    if limit <= 0:
        sys.exit('The free characters of this month are used up: run again next month.')
    key = google_key()
    used = 0
    for lang, set_name, texts in plan:
        if not texts:
            continue
        mem_path, known = translate.memory(lang)
        machine_path = os.path.join(translate.MEMORY, f'machine_{lang}.json')
        machine = set(json.load(open(machine_path, encoding='utf-8'))) if os.path.exists(machine_path) else set()
        todo = []
        for en in texts:
            if keep_as_is(en):
                known[en] = en
            else:
                todo.append(en)
        done = 0
        batch, size = [], 0
        for en in todo + [None]:
            full = en is None or len(batch) >= BATCH_ITEMS or size + len(en) > BATCH_CHARS
            if full and batch:
                if used + size > limit:
                    print(f'  stop: the --max-chars limit ({limit:,}) is reached')
                    break
                add_usage(size)  # counted before the call, so a failed run never under-counts
                for source, result in zip(batch, call(key, batch, lang)):
                    if result:
                        known[source] = result
                        machine.add(source)
                        done += 1
                used += size
                batch, size = [], 0
            if en is not None:
                batch.append(en)
                size += len(to_html(en))
        os.makedirs(translate.MEMORY, exist_ok=True)
        json.dump(known, open(mem_path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
        json.dump(sorted(machine), open(machine_path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=0)
        written = translate.apply(lang, known)
        print(f'{lang} {set_name}: {done} translated by Google, written into content {written}')
        if used >= limit:
            break
    print(f'characters sent: {used:,}')


if __name__ == '__main__':
    main()
