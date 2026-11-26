"""More B2 writing (Schreiben) and speaking (Sprechen) tasks, written by ChatGPT/Codex from request files.

    python -I -X utf8 tools/tasks_upper.py export     ../icerik/gorev/B2_yazma_istek_NN.txt, B2_konusma_istek_NN.txt
    python -I -X utf8 tools/tasks_upper.py import     reads the *_cevap_NN.txt answers, checks them, keeps them in
                                                      tools/tasks_extra.json and puts them into writing.json and
                                                      speaking.json (by id, the other tasks and translations untouched)
    python -I -X utf8 tools/tasks_upper.py status

tools/writing.py and tools/speaking.py add tools/tasks_extra.json when they rebuild their files.
"""
import glob
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT = os.path.join(REPO, 'Resources', 'content')
EXTRA = os.path.join(REPO, 'tools', 'tasks_extra.json')
FOLDER = os.path.join(os.path.dirname(REPO), 'icerik', 'gorev')
GREETING = ['liebe', 'lieber', 'hallo', 'hi', 'sehr geehrte', 'sehr geehrter', 'guten tag']
CLOSING = ['grüße', 'gruß', 'bis bald', 'tschüss', 'bis dann', 'bis morgen', 'bis gleich']

# (file, ids, what) per request.
WRITING = [
    ('B2_yazma_istek_01.txt', ['b2-m5', 'b2-m6', 'b2-m7', 'b2-m8'],
     'Forum yazısı (Goethe B2 Schreiben Teil 1), en az 150 kelime, informal (formal:false). Konular: '
     '1) evden çalışma mı ofis mi, 2) okullarda akıllı telefon yasağı, 3) et yemeğine vergi, 4) yaşlılar için ortak '
     'konut projeleri. Noktalar: görüş, artı/eksi, örnek, ülkendeki durum ya da kendi deneyimin, sonuç.'),
    ('B2_yazma_istek_02.txt', ['b2-m9', 'b2-m10', 'b2-m11'],
     'Resmî e-posta (Goethe B2 Schreiben Teil 2), en az 100 kelime, formal:true, "Sehr geehrte …" ve '
     '"Mit freundlichen Grüßen". Konular: 1) ev sahibine nem/küf şikâyeti ve tamir talebi, 2) bir dil okuluna kurs '
     'iptali ve ücret iadesi talebi, 3) şefe bir haftalık ücretsiz izin isteği (gerekçe ve iş devri planıyla). '
     'Noktalar: sebep, ayrıntı, talep, süre/öneri.'),
]
SPEAKING = [
    ('B2_konusma_istek_01.txt', ['b2-7', 'b2-8', 'b2-9', 'b2-10', 'b2-11'],
     'Sunum (Goethe B2 Sprechen Teil 1, 120 saniye). Konular: 1) yapay zekâ okulda, 2) şehirde kiraların '
     'artması, 3) gönüllü çalışma zorunlu olmalı mı, 4) yurt dışında okumak, 5) fast fashion. Noktalar: konuyu tanıt, '
     'avantajlar, dezavantajlar, örnek, ülkendeki durum, görüşün ve sonuç.'),
    ('B2_konusma_istek_02.txt', ['b2-12', 'b2-13', 'b2-14', 'b2-15', 'b2-16'],
     'Tartışma (Goethe B2 Sprechen Teil 2, 120 saniye): bir soruya görüş, gerekçe, karşı görüşe cevap, uzlaşma '
     'önerisi. Konular: 1) toplu taşıma ücretsiz olmalı mı, 2) çocuklara cep harçlığı, 3) emeklilik yaşı yükselmeli '
     'mi, 4) şirketlerde kadın kotası, 5) restoranlarda bahşiş.'),
    ('B2_konusma_istek_03.txt', ['b2-17', 'b2-18', 'b2-19', 'b2-20'],
     'Günlük ve resmî durumlar (90 saniye): 1) bir iş görüşmesinde kendini ve deneyimini tanıt, 2) bankayı arayıp '
     'kartını bloke ettir ve yeni kart iste, 3) bir toplantıda bir projeyi kısaca özetle ve sonraki adımları öner, '
     '4) komşuyla gürültü sorununu kibarca konuş ve çözüm bul. Noktalar duruma uygun (selam, sorun, talep, öneri, '
     'kapanış gibi).'),
]

PROMPT = '''Sen deneyimli bir Almanca (DaF) sınav hazırlayıcısısın (Goethe-Zertifikat B2). Deschly uygulaması için
{COUNT} yeni {KIND} görevi yaz. Uygulama öğrencinin cevabında "keys" listesindeki ifadeleri arar (küçük harfle,
cümlenin içinde geçerse nokta sayılır), sonra örnek cevabı gösterir.

GÖREVLER
{WHAT}
Kimlikler (id) sırayla: {IDS}

KURALLAR
- "prompt": görev metni Almanca, sınavdaki gibi (Sie ile).
- "title" ve "help": Türkçe ("tr") ve İngilizce ("en"); help kısa bir yol tarifi (ne yazmalı/söylemeli).
- "points": 4–6 nokta. Her noktada "label" (tr/en), "say" (Almanca örnek başlangıç, … ile biter) ve "keys":
  3–6 küçük harfli Almanca ifade; bunlardan EN AZ BİRİ örnek cevapta ("sample") birebir geçmeli.
- "sample": doğal, hatasız B2 Almancası; şablon cümle kullanma, her görev farklı olsun.
{EXTRA}
BİÇİM: Her görev bir satır JSON (JSONL), toplam {COUNT} satır, başka hiçbir şey yazma, kod bloğu kullanma:
{SHAPE}

ŞU AN VAR OLAN B2 GÖREVLERİ (aynısını yazma):
{EXISTING}
'''
WRITING_EXTRA = ('- "kind":"message", "level":"B2", "minWords": forumda 150, e-postada 100; örnek cevap bu sayıdan uzun olmalı.\n'
                 '- Örnek cevap bir selamla başlar (Liebe …, Hallo …, Sehr geehrte …) ve bir kapanışla biter '
                 '(Viele Grüße, Mit freundlichen Grüßen) ve imza.\n')
SPEAKING_EXTRA = '- "level":"B2", "seconds": sunum ve tartışmada 120, günlük durumlarda 90. Örnek cevap 110–170 kelime.\n'
WRITING_SHAPE = ('{"id":"b2-m5","level":"B2","kind":"message","title":{"tr":"Forum: …","en":"Forum: …"},"prompt":"…",'
                 '"help":{"tr":"…","en":"…"},"points":[{"label":{"tr":"Görüş","en":"Opinion"},"say":"Ich bin der Meinung, dass …",'
                 '"keys":["meiner meinung","ich bin der meinung","ich finde"]}],"minWords":150,"sample":"Hallo zusammen, …","formal":false}')
SPEAKING_SHAPE = ('{"id":"b2-7","level":"B2","seconds":120,"title":{"tr":"Sunum: …","en":"Presentation: …"},"prompt":"…",'
                  '"help":{"tr":"…","en":"…"},"points":[{"label":{"tr":"Konuyu tanıt","en":"Introduce the topic"},'
                  '"say":"Mein Thema ist …","keys":["mein thema","es geht um","in meinem vortrag"]}],"sample":"…"}')


def load(name):
    return json.load(open(os.path.join(CONTENT, name), encoding='utf-8'))


def export():
    os.makedirs(FOLDER, exist_ok=True)
    writing = [t['title']['tr'] for t in load('writing.json')['tasks'] if t['level'] == 'B2']
    speaking = [t['title']['tr'] for t in load('speaking.json')['tasks'] if t['level'] == 'B2']
    for jobs, kind, extra, shape, existing in ((WRITING, 'yazma (Schreiben)', WRITING_EXTRA, WRITING_SHAPE, writing),
                                               (SPEAKING, 'konuşma (Sprechen)', SPEAKING_EXTRA, SPEAKING_SHAPE, speaking)):
        for name, ids, what in jobs:
            body = PROMPT.format(COUNT=len(ids), KIND=kind, WHAT=what, IDS=', '.join(ids), EXTRA=extra, SHAPE=shape,
                                 EXISTING='\n'.join(f'- {t}' for t in existing))
            open(os.path.join(FOLDER, name), 'w', encoding='utf-8', newline='\r\n').write(body)
    print(f'{len(WRITING) + len(SPEAKING)} requests -> {FOLDER}')


def problems_of(t, kind, ids):
    out = []
    if t.get('id') not in ids or t.get('level') != 'B2':
        return ['unknown id or level']
    for key in ('title', 'help'):
        if not isinstance(t.get(key), dict) or not t[key].get('tr') or not t[key].get('en'):
            out.append(f'{key} needs tr and en')
    sample = str(t.get('sample', ''))
    low = sample.lower()
    if not t.get('prompt') or not sample:
        out.append('no prompt or sample')
    points = t.get('points') or []
    if not 3 <= len(points) <= 6:
        out.append('3-6 points')
    for p in points:
        if not (isinstance(p.get('label'), dict) and p['label'].get('tr') and p['label'].get('en') and p.get('say')
                and isinstance(p.get('keys'), list) and p['keys']):
            out.append('a point misses label/say/keys')
        elif not any(str(k).lower() in low for k in p['keys']):
            out.append(f"sample has none of the keys of \"{p['label'].get('en')}\"")
    if kind == 'writing':
        if t.get('kind') != 'message' or not isinstance(t.get('minWords'), int):
            out.append('kind/minWords')
        elif len(sample.split()) < t['minWords']:
            out.append(f"sample {len(sample.split())} words < {t['minWords']}")
        if not any(g in low for g in GREETING) or not any(c in low for c in CLOSING):
            out.append('sample needs a greeting and a closing')
        if not isinstance(t.get('formal'), bool):
            out.append('formal true/false')
    else:
        if t.get('seconds') not in (90, 120):
            out.append('seconds 90 or 120')
    return out


def clean(t, kind):
    """Only the fields the app reads, keys in lower case."""
    point = lambda p: {'label': {'tr': p['label']['tr'], 'en': p['label']['en']}, 'say': p['say'],
                       'keys': [str(k).lower() for k in p['keys']]}
    base = {'id': t['id'], 'level': 'B2', 'title': {'tr': t['title']['tr'], 'en': t['title']['en']}, 'prompt': t['prompt'],
            'help': {'tr': t['help']['tr'], 'en': t['help']['en']}, 'points': [point(p) for p in t['points']],
            'sample': t['sample']}
    if kind == 'writing':
        base.update({'kind': 'message', 'minWords': t['minWords'], 'formal': t['formal']})
    else:
        base = {'id': base['id'], 'level': 'B2', 'seconds': t['seconds'], **{k: v for k, v in base.items() if k not in ('id', 'level')}}
    return base


def merge_into(name, tasks):
    """Puts the tasks into a content file by id: replaced in place, new ones after the file's last B2 task."""
    path = os.path.join(CONTENT, name)
    data = json.load(open(path, encoding='utf-8'))
    have = {t['id']: i for i, t in enumerate(data['tasks'])}
    for t in tasks:
        if t['id'] in have:
            old = data['tasks'][have[t['id']]]
            # keep translations of fields that did not change
            data['tasks'][have[t['id']]] = t if old.get('sample') != t['sample'] else {**t, **{k: old[k] for k in ('title', 'help') if k in old}}
        else:
            last = max([i for i, x in enumerate(data['tasks']) if x['level'] == 'B2'] or [len(data['tasks']) - 1])
            data['tasks'].insert(last + 1, t)
            have = {x['id']: i for i, x in enumerate(data['tasks'])}
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')


def import_answers():
    extra = json.load(open(EXTRA, encoding='utf-8')) if os.path.exists(EXTRA) else {'writing': [], 'speaking': []}
    problems = []
    for kind, jobs in (('writing', WRITING), ('speaking', SPEAKING)):
        known = {t['id']: t for t in extra[kind]}
        for name, ids, _ in jobs:
            answer = os.path.join(FOLDER, name.replace('_istek_', '_cevap_'))
            if not os.path.exists(answer):
                continue
            for n, raw in enumerate(open(answer, encoding='utf-8-sig'), 1):
                raw = raw.strip().strip(',')
                if not raw.startswith('{'):
                    continue
                try:
                    t = json.loads(raw)
                except json.JSONDecodeError:
                    problems.append(f'{os.path.basename(answer)}:{n} not JSON')
                    continue
                found = problems_of(t, kind, ids)
                if found:
                    problems.append(f"{os.path.basename(answer)}:{n} {t.get('id')}: " + '; '.join(found))
                    continue
                known[t['id']] = clean(t, kind)
        order = [i for _, ids, _ in jobs for i in ids]
        extra[kind] = sorted(known.values(), key=lambda t: order.index(t['id']) if t['id'] in order else 99)
    with open(EXTRA, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(extra, f, ensure_ascii=False, indent=1)
        f.write('\n')
    merge_into('writing.json', extra['writing'])
    merge_into('speaking.json', extra['speaking'])
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import content_edits  # hand edits made in Deschly Studio survive the rewrite
    content_edits.apply_all(quiet=True)
    print(f"B2: {len(extra['writing'])}/{sum(len(i) for _, i, _ in WRITING)} writing, "
          f"{len(extra['speaking'])}/{sum(len(i) for _, i, _ in SPEAKING)} speaking tasks")
    for p in problems:
        print('  ', p)


def status():
    extra = json.load(open(EXTRA, encoding='utf-8')) if os.path.exists(EXTRA) else {'writing': [], 'speaking': []}
    print(f"B2 extra: {len(extra['writing'])} writing, {len(extra['speaking'])} speaking")


if __name__ == '__main__':
    command = sys.argv[1] if len(sys.argv) > 1 else 'status'
    {'export': export, 'import': import_answers}.get(command, status)()
