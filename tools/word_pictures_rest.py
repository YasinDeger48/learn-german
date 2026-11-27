"""Pictures for the A1 nouns that have none yet (the 16 per unit and the extra grids are done), in two steps:

    python -I -X utf8 tools/word_pictures_rest.py ask        writes ../icerik/gorseller/A1_resim_secim_istek.txt:
                                                             Codex marks which nouns a small picture can show
    python -I -X utf8 tools/word_pictures_rest.py prompts    reads A1_resim_secim_cevap.txt, makes 4×4 grids of 16
                                                             (tools/word_pictures_rest.json) and the drawing requests
                                                             ../icerik/gorseller/KELIME_IZGARALARI_A1_KALAN.txt
    python -I -X utf8 tools/word_pictures_rest.py cut-all    cuts every words-a1-kalan-NN.(jpg|png|webp) into
                                                             Resources/Covers/wp-a1-<id>.jpg (like word_pictures.py)
    python -I -X utf8 tools/word_pictures_rest.py status

Abstract nouns stay letter cards in the app (a clear letter card beats a misleading drawing).
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from word_pictures import COVERS, GORSELLER, STYLE, cut_grid, words  # noqa: E402

TOOLS = os.path.dirname(os.path.abspath(__file__))
GRIDS = os.path.join(TOOLS, 'word_pictures_rest.json')
ASK = os.path.join(GORSELLER, 'A1_resim_secim_istek.txt')
ANSWER = os.path.join(GORSELLER, 'A1_resim_secim_cevap.txt')
PROMPTS = os.path.join(GORSELLER, 'KELIME_IZGARALARI_A1_KALAN.txt')


def missing():
    """A1 nouns without a picture, by id."""
    return [w for w in sorted(words().values(), key=lambda w: w['id'])
            if w.get('type') in ('der', 'die', 'das') and not os.path.exists(os.path.join(COVERS, f"wp-a1-{w['id']}.jpg"))]


def ask():
    nouns = missing()
    lines = ['A1 RESİM SEÇİMİ — hangi kelime küçük bir resimle net gösterilebilir?',
             '',
             'Aşağıdaki her A1 ismi için karar ver: küçük, basit bir çıkartma resmiyle (yazısız) bir öğrenci kelimeyi',
             'hemen tanır mı? Somut nesneler, hayvanlar, yiyecekler, yerler, meslekler, vücut, giysi: EVET.',
             'Soyut kelimeler (Idee, Zeit, Problem, Termin, Information …) ve resmi yanıltacak olanlar: HAYIR.',
             '',
             f'Cevap dosyası: icerik\\gorseller\\A1_resim_secim_cevap.txt',
             'Sadece EVET olanları yaz, her satıra bir tane: id | ne çizilecek (İngilizce, kısa)',
             'Örnek:  412 | a red apple',
             'Başka bir şey yazma.',
             '',
             f'KELİMELER ({len(nouns)}): id | Almanca | İngilizce anlamı']
    lines += [f"{w['id']} | {w['type']} {w['de']} | {w['mean']['en']}" for w in nouns]
    os.makedirs(GORSELLER, exist_ok=True)
    open(ASK, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines) + '\n')
    print('->', ASK, len(nouns), 'nouns')


def read_answer():
    picked = {}
    for line in open(ANSWER, encoding='utf-8-sig'):
        head, _, what = line.partition('|')
        if head.strip().isdigit() and what.strip():
            picked[int(head.strip())] = what.strip()
    return picked


def prompts():
    lookup = words()
    picked = {wid: what for wid, what in read_answer().items() if wid in {w['id'] for w in missing()}}
    ids = sorted(picked)
    grids = {f'a1-kalan-{n // 16 + 1:02d}': ids[n:n + 16] for n in range(0, len(ids), 16)}
    # A last grid with fewer than 16 is filled up with its own first words (the cut needs 16 stickers).
    for gid, members in grids.items():
        while len(members) < 16:
            members.append(members[len(members) % max(1, len(members))])
    json.dump(grids, open(GRIDS, 'w', encoding='utf-8', newline='\n'), indent=1)
    lines = [f'A1 KALAN KELİMELER — {len(grids)} resim, her biri 16 çıkartma',
             'Her istek: aşağıdaki ÜSLUP paragrafı + o resmin 16 maddelik listesi.',
             f'Kaydet: words-a1-kalan-01.jpg … words-a1-kalan-{len(grids):02d}.jpg (bu klasöre).',
             'Not: yazı ve rakam olmasın.', '', 'ÜSLUP:', STYLE, '']
    for gid, members in grids.items():
        lines.append(f'--- words-{gid}.jpg ---')
        for n, wid in enumerate(members, 1):
            w = lookup[wid]
            lines.append(f"{n}. {picked[wid]}   [{w['type']} {w['de']}]")
        lines.append('')
    open(PROMPTS, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(lines))
    print('->', PROMPTS, len(ids), 'words in', len(grids), 'grids')


def cut_all():
    grids = json.load(open(GRIDS, encoding='utf-8'))
    for gid, members in grids.items():
        found = [p for ext in ('jpg', 'jpeg', 'png', 'webp') for p in glob.glob(os.path.join(GORSELLER, f'words-{gid}.{ext}'))]
        if found:
            cut_grid(gid, found[0], [f'wp-a1-{wid}' for wid in members])


def status():
    print(len(missing()), 'A1 nouns without a picture')
    if os.path.exists(GRIDS):
        grids = json.load(open(GRIDS, encoding='utf-8'))
        done = sum(1 for g in grids if glob.glob(os.path.join(GORSELLER, f'words-{g}.*')))
        print(f'{len(grids)} grids planned, {done} drawn')


if __name__ == '__main__':
    {'ask': ask, 'prompts': prompts, 'cut-all': cut_all}.get(sys.argv[1] if len(sys.argv) > 1 else '', status)()
