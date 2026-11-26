"""Verb lab (Fiil Laboratuvarı): every tense, questions, common phrases and complex sentences for each verb.

    python -I -X utf8 tools/verblab.py export A1     ../icerik/fiil/A1_fiil_istek_NN.txt (prompt + 15 verbs each)
    python -I -X utf8 tools/verblab.py import A1     reads ../icerik/fiil/A1_fiil_cevap_*.txt -> Resources/content/verbs_a1.json
    python -I -X utf8 tools/verblab.py status

Each verb appears once, at the lowest level that has it. Export only lists verbs that are not imported yet.
Import rejects a whole answer file when its sentences come from a template (the same opening in many verbs: a sign
that a script filled them in) and single lines whose irregular forms are wrong (see IRREGULAR).
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'fiil')
LEVELS = ['a1', 'a2', 'b1', 'b2']
BATCH = 15
PERSONS = 6  # ich, du, er/sie/es, wir, ihr, sie/Sie


def verbs_by_level():
    seen, out = set(), {}
    for level in LEVELS:
        out[level] = []
        for w in json.load(open(os.path.join(CONTENT, f'{level}.json'), encoding='utf-8'))['words']:
            if w['type'] != 'verb':
                continue
            key = w['de'].strip().lower()
            if key in seen:
                continue
            seen.add(key)
            out[level].append(w)
    return out


def out_path(level):
    return os.path.join(CONTENT, f'verbs_{level}.json')


def load(level):
    path = out_path(level)
    return json.load(open(path, encoding='utf-8'))['verbs'] if os.path.exists(path) else []


PROMPT = '''Sen deneyimli bir Almanca öğretmenisin. Deschly uygulamasının "Fiil Laboratuvarı" için her fiilin bütün hallerini hazırlıyorsun. Öğrenciler Türkçe ve İngilizce konuşuyor; seviye: {LEVEL}.

Aşağıdaki her fiil için TEK satırlık bir JSON yaz (JSONL). Başka hiçbir şey yazma; bütün cevabı tek bir kod bloğuna koy. Yarıda kalırsa "devam" yazdığımda kaldığın fiilden devam et.

Biçim (örnek: gehen):
{"v":"gehen","tr":"gitmek","en":"to go","praesens":["gehe","gehst","geht","gehen","geht","gehen"],"praeteritum":["ging","gingst","ging","gingen","gingt","gingen"],"perfekt":"ist gegangen","futur":"wird gehen","imperativ":["geh!","geht!","gehen Sie!"],"trennbar":false,"reflexiv":false,"rektion":"gehen + zu/in (Wohin?)","examples":[{"t":"praesens","de":"Ich gehe heute früh ins Bett.","tr":"Bugün erken yatıyorum.","en":"I'm going to bed early today."},{"t":"praeteritum","de":"Gestern ging er allein nach Hause.","tr":"Dün eve yalnız gitti.","en":"Yesterday he went home alone."},{"t":"perfekt","de":"Wir sind am Sonntag in den Park gegangen.","tr":"Pazar günü parka gittik.","en":"We went to the park on Sunday."},{"t":"futur","de":"Nächstes Jahr wird sie nach Berlin gehen.","tr":"Gelecek yıl Berlin'e gidecek.","en":"Next year she will go to Berlin."}],"questions":[{"de":"Gehst du mit ins Kino?","tr":"Sinemaya benimle geliyor musun?","en":"Are you coming to the cinema?"},{"de":"Wohin gehen Sie heute Abend?","tr":"Bu akşam nereye gidiyorsunuz?","en":"Where are you going tonight?"}],"common":[{"de":"Wie geht es dir?","tr":"Nasılsın?","en":"How are you?"},{"de":"Das geht nicht.","tr":"Bu olmaz.","en":"That's not possible."},{"de":"Es geht um …","tr":"Mesele … ile ilgili.","en":"It's about …"}],"complex":[{"de":"Ich gehe nach Hause, weil ich müde bin.","tr":"Eve gidiyorum çünkü yorgunum.","en":"I'm going home because I'm tired.","note":"weil: fiil sona gider"},{"de":"Wenn es regnet, gehen wir nicht spazieren.","tr":"Yağmur yağarsa yürüyüşe çıkmayız.","en":"If it rains, we don't go for a walk.","note":"wenn-cümlesi önde: ana cümlede fiil başa gelir"}]}

Kurallar:
- "praesens" ve "praeteritum": 6 kişi sırayla: ich, du, er/sie/es, wir, ihr, sie/Sie. Sadece fiil biçimi (ayrılabilen fiillerde ön ek dahil: "stehe auf").
- "perfekt": yardımcı fiil (er için) + Partizip II, ör. "hat gemacht", "ist gefahren". "futur": "wird + Infinitiv".
- "imperativ": du, ihr, Sie biçimleri.
- "trennbar": ayrılabilen fiil mi; "reflexiv": dönüşlü mü (sich freuen → true); "rektion": hangi hal / edatla kullanılır, kısa.
- "examples": 4 cümle, her zamandan bir tane (praesens, praeteritum, perfekt, futur), {LEVEL} seviyesine uygun, doğal, günlük hayattan.
- "questions": 2 soru: biri Ja/Nein sorusu, biri W-sorusu.
- "common": bu fiille en sık kullanılan 3 kalıp ya da ifade.
- "complex": 2 yan cümleli örnek (weil, dass, wenn, als, obwohl, damit, ob, Relativsatz arasından), "note" alanında Türkçe kısa açıklama.
- Türkçe ve İngilizce çeviriler doğal olsun. Listedeki her fiil için bir satır yaz, sırayı koru, hiçbirini atlama.
- ÇOK ÖNEMLİ: Program, betik ya da şablon KULLANMA. Her cümleyi o fiil için ayrı düşünerek yaz: nesnesi, yeri, zamanı olan,
  gerçek hayatta söylenebilecek bir cümle. "Ich habe gestern …", "Ich glaube, dass du heute …", "Wenn ich Zeit habe, …",
  "Wann … du heute?" gibi her fiilde aynı kalıbı tekrarlama; bu tür cevaplar otomatik reddedilir.
- Düzensiz fiillerin Präteritum ve Partizip II biçimlerini kontrol et (gefallen → gefiel, hat gefallen; werden → werdet!).
- Emir kipi olmayan ya da çok garip olan fiillerde (wissen, mögen, gefallen, kennen …) "imperativ" için ["—","—","—"] yaz.

'''


def priority(level, word):
    """A1: the "important verbs" theme first (sein, haben, modal verbs …), then the verbs of the path's themes,
    then the long frequency list (the last theme). Other levels keep the file order. Used for the requests and
    for the order in the app. (File order had put sein / haben far back.)"""
    if level.lower() != 'a1':
        return 0
    themes = json.load(open(os.path.join(CONTENT, 'a1.json'), encoding='utf-8'))['themes']
    core, important = max(t['id'] for t in themes), 12
    return 0 if word['theme'] == important else (2 if word['theme'] == core else 1)


def export(level):
    level = level.lower()
    done = {v['v'].lower() for v in load(level)}
    verbs = [w for w in verbs_by_level()[level] if w['de'].lower() not in done]
    verbs.sort(key=lambda w: priority(level, w))
    os.makedirs(FOLDER, exist_ok=True)
    for old in glob.glob(os.path.join(FOLDER, f'{level.upper()}_fiil_istek_*.txt')):
        os.remove(old)
    batches = [verbs[i:i + BATCH] for i in range(0, len(verbs), BATCH)]
    for n, batch in enumerate(batches, 1):
        lines = [f"{w['de']} ({w['mean'].get('tr', '')})" for w in batch]
        body = PROMPT.replace('{LEVEL}', level.upper()) + f'LİSTE {n:02d}/{len(batches):02d} · {len(batch)} fiil:\n' + '\n'.join(lines) + '\n'
        open(os.path.join(FOLDER, f'{level.upper()}_fiil_istek_{n:02d}.txt'), 'w', encoding='utf-8', newline='\r\n').write(body)
    print(f'{level.upper()}: {len(verbs)} verbs -> {len(batches)} lists in {FOLDER}')


# Spot checks for common irregular verbs: ich-form Präteritum and Perfekt (er).
IRREGULAR = {
    'sein': ('war', 'ist gewesen'), 'haben': ('hatte', 'hat gehabt'), 'werden': ('wurde', 'ist geworden'),
    'gehen': ('ging', 'ist gegangen'), 'kommen': ('kam', 'ist gekommen'), 'fahren': ('fuhr', 'ist gefahren'),
    'essen': ('aß', 'hat gegessen'), 'trinken': ('trank', 'hat getrunken'), 'sehen': ('sah', 'hat gesehen'),
    'lesen': ('las', 'hat gelesen'), 'schreiben': ('schrieb', 'hat geschrieben'), 'sprechen': ('sprach', 'hat gesprochen'),
    'nehmen': ('nahm', 'hat genommen'), 'geben': ('gab', 'hat gegeben'), 'finden': ('fand', 'hat gefunden'),
    'helfen': ('half', 'hat geholfen'), 'gefallen': ('gefiel', 'hat gefallen'), 'schlafen': ('schlief', 'hat geschlafen'),
    'bleiben': ('blieb', 'ist geblieben'), 'bringen': ('brachte', 'hat gebracht'), 'denken': ('dachte', 'hat gedacht'),
    'wissen': ('wusste', 'hat gewusst'), 'kennen': ('kannte', 'hat gekannt'), 'laufen': ('lief', 'ist gelaufen'),
    'tragen': ('trug', 'hat getragen'), 'treffen': ('traf', 'hat getroffen'), 'vergessen': ('vergaß', 'hat vergessen'),
    'verlieren': ('verlor', 'hat verloren'), 'liegen': ('lag', 'hat gelegen'), 'sitzen': ('saß', 'hat gesessen'),
    'stehen': ('stand', 'hat gestanden'), 'rufen': ('rief', 'hat gerufen'), 'heißen': ('hieß', 'hat geheißen'),
    'beginnen': ('begann', 'hat begonnen'), 'fliegen': ('flog', 'ist geflogen'), 'waschen': ('wusch', 'hat gewaschen'),
    'tun': ('tat', 'hat getan'), 'ziehen': ('zog', 'ist gezogen'), 'singen': ('sang', 'hat gesungen'), 'sterben': ('starb', 'ist gestorben'),
}


def template_frames(entries):
    """Openings (first three words) shared by many verbs of one answer file: the mark of a filled-in template."""
    from collections import Counter
    counts = Counter()
    for e in entries:
        frames = set()
        for key in ('examples', 'questions', 'common', 'complex'):
            for x in e.get(key) or []:
                if isinstance(x, dict) and x.get('de'):
                    words = x['de'].replace(',', ' ').split()
                    frames.add(' '.join(words[:3]).lower())
        counts.update(frames)
    limit = max(4, len(entries) * 0.4)
    return [f for f, n in counts.items() if n > limit] if len(entries) >= 8 else []


def valid(e):
    """Problems of one answer line (empty list = fine)."""
    problems = []
    for key in ('v', 'tr', 'en', 'perfekt', 'futur'):
        if not str(e.get(key, '')).strip():
            problems.append(f'no {key}')
    for key in ('praesens', 'praeteritum'):
        if not isinstance(e.get(key), list) or len(e[key]) != PERSONS or not all(str(x).strip() for x in e[key]):
            problems.append(f'{key} needs {PERSONS} forms')
    if not isinstance(e.get('imperativ'), list) or len(e['imperativ']) != 3:
        problems.append('imperativ needs 3 forms')
    elif any('?' in str(x) or '...' in str(x) for x in e['imperativ']):
        problems.append('imperativ is not an imperative')
    known = IRREGULAR.get(str(e.get('v', '')).lower())
    if known and isinstance(e.get('praeteritum'), list) and e['praeteritum']:
        if str(e['praeteritum'][0]).strip() != known[0] or not str(e.get('perfekt', '')).strip().startswith(known[1]):
            problems.append(f'wrong forms (expected {known[0]}, {known[1]})')
    tenses = {x.get('t') for x in e.get('examples', []) if isinstance(x, dict)}
    if not {'praesens', 'praeteritum', 'perfekt', 'futur'} <= tenses:
        problems.append('examples miss a tense')
    for key, n in (('questions', 2), ('common', 2), ('complex', 2)):
        items = e.get(key)
        if not isinstance(items, list) or len(items) < n or not all(isinstance(x, dict) and x.get('de') and x.get('tr') for x in items):
            problems.append(f'{key} incomplete')
    return problems


def check_file(level, path):
    """Dry run of import for one answer file: how many lines are usable, and why the others are not."""
    level = level.lower()
    known = {w['de'].lower() for w in verbs_by_level()[level]}
    entries, problems = [], []
    for n, line in enumerate(open(path, encoding='utf-8-sig'), 1):
        line = line.strip().rstrip(',')
        if not line.startswith('{'):
            continue
        try:
            entries.append((n, json.loads(line)))
        except json.JSONDecodeError:
            problems.append(f'line {n}: not JSON')
    frames = template_frames([e for _, e in entries])
    if frames:
        return {'lines': len(entries), 'ok': 0,
                'problems': ['WHOLE FILE REJECTED: template sentences (' + ' | '.join(frames[:4]) + ')'] + problems}
    ok = 0
    for n, e in entries:
        why = valid(e)
        if str(e.get('v', '')).lower() not in known:
            why.append(f'"{e.get("v")}" is not a {level.upper()} verb')
        if why:
            problems.append(f'line {n} ({e.get("v", "?")}): ' + '; '.join(why))
        else:
            ok += 1
    return {'lines': len(entries), 'ok': ok, 'problems': problems}


def import_answers(level):
    level = level.lower()
    known = {w['de'].lower(): w for w in verbs_by_level()[level]}
    verbs = {v['v'].lower(): v for v in load(level)}
    added, skipped = 0, []
    for path in sorted(glob.glob(os.path.join(FOLDER, f'{level.upper()}_fiil_cevap_*.txt'))):
        entries = []
        for line in open(path, encoding='utf-8-sig'):
            line = line.strip().rstrip(',')
            if line.startswith('{'):
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
        frames = template_frames(entries)
        if frames:
            skipped.append((os.path.basename(path), 0, 'WHOLE FILE REJECTED, template sentences: ' + ' | '.join(frames[:4])))
            continue
        for n, line in enumerate(open(path, encoding='utf-8-sig'), 1):
            line = line.strip().rstrip(',')
            if not line.startswith('{'):
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                skipped.append((os.path.basename(path), n, 'not JSON'))
                continue
            problems = valid(e)
            if e.get('v', '').lower() not in known:
                problems.append(f'"{e.get("v")}" is not a {level.upper()} verb')
            if problems:
                skipped.append((os.path.basename(path), n, '; '.join(problems)))
                continue
            e['v'] = known[e['v'].lower()]['de']
            e['trennbar'] = bool(e.get('trennbar'))
            e['reflexiv'] = bool(e.get('reflexiv'))
            verbs[e['v'].lower()] = e
            added += 1
    ranked = sorted(known, key=lambda w: priority(level, known[w]))  # stable: file order inside a group
    ordered = [verbs[w] for w in ranked if w in verbs]
    with open(out_path(level), 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'level': level.upper(), 'verbs': ordered}, f, ensure_ascii=False, separators=(',', ':'))
    print(f'{level.upper()}: read {added}, skipped {len(skipped)}; {len(ordered)}/{len(known)} verbs ready')
    for name, n, why in skipped[:25]:
        print(f'  {name}:{n} {why}')


def status():
    by_level = verbs_by_level()
    for level in LEVELS:
        print(f'{level.upper()}: {len(load(level))}/{len(by_level[level])} verbs')


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if command == 'export':
        export(sys.argv[2])
    elif command == 'import':
        import_answers(sys.argv[2])
    else:
        status()
