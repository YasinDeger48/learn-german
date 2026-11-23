"""English explanations for the A2 grammar items, built from the 195 distinct Turkish explanations.

    python -I -X utf8 tools/a2_grammar_en.py .
"""
import json, re, sys
ROOT = sys.argv[1]
d = json.load(open(ROOT + '/tools/data/a2_raw.json', encoding='utf-8'))

RULES = [
    (r'^Alıcı Dativ alır: (.*)$', r'The recipient takes the Dativ: \1'),
    (r'^Bu cümlenin Perfekt yapısı: (.*)$', r'The Perfekt in this sentence: \1'),
    (r'^Doğrudan nesne Akkusativ alır: (.*)$', r'The direct object takes the Akkusativ: \1'),
    (r'^Der ile isimden önce Superlativ: (.*)$', r'Superlative before a noun with der: \1'),
    (r'^(\S+) ayrılabilir\. Ana cümlede (\S+) sona gider\.$', r'\1 is separable. In a main clause \2 goes to the end.'),
    (r'^(sich \S+) dönüşlüdür\. (\S+) için zamir (\S+) olur\.$', r'\1 is reflexive. For \2 the pronoun is \3.'),
]
FIXED = {
    'Wo? Konum bildirirken auf + Dativ.': 'Wo? For a position: auf + Dativ.',
    'Wohin? Hedef bildirirken auf + Akkusativ.': 'Wohin? For a direction: auf + Akkusativ.',
    'Sebep bildiren weil yan cümlesinde çekimli fiil sonda yer alır.': 'In a weil clause (reason) the conjugated verb goes to the end.',
    'Nehmen fiilinin doğrudan nesnesi Akkusativ alır.': 'The direct object of nehmen takes the Akkusativ.',
    'Bir bilgiyi aktaran dass yan cümlesinde çekimli fiil sona gider.': 'In a dass clause the conjugated verb goes to the end.',
    'Müssen özneye göre çekimlenir. Asıl fiil sonda mastar hâlindedir.': 'müssen agrees with the subject. The main verb goes to the end as an infinitive.',
    'Sein fiilinin ich biçimi war olur.': 'The ich form of sein in the past is war.',
    'Haben, wir ile hatten olur.': 'haben with wir becomes hatten.',
    'Du ile sein → warst.': 'sein with du → warst.',
    'Yanında bir şey bulunması burada haben ile anlatılır.': 'Having something with you is expressed with haben here.',
    'Ihr ile sein → wart.': 'sein with ihr → wart.',
    'Çoğul özneyle waren kullanılır.': 'With a plural subject use waren.',
    'Zorunluluk için müssen → musste.': 'For an obligation: müssen → musste.',
    'Können, çoğul özneyle konnten olur.': 'können with a plural subject becomes konnten.',
    'Geçmişte izin bildiren dürfen, du ile durftest olur.': 'dürfen (permission in the past) with du becomes durftest.',
    'Aktarılan öneri için wir sollten kullanılır.': 'For reported advice use wir sollten.',
    'Geçmişteki niyet için ich wollte kullanılır.': 'For an intention in the past use ich wollte.',
    'Durum bildiren offen, sein ile kullanılır.': 'offen describes a state and is used with sein.',
    'Ihr ile haben → hattet.': 'haben with ihr → hattet.',
    'Eine Frage haben geçmişte eine Frage hatte olur.': 'eine Frage haben becomes eine Frage hatte in the past.',
    'Als ile karşılaştırmada schneller kullanılır.': 'In a comparison with als use schneller.',
    "Kalt sözcüğü Komparativ'de kälter olur.": 'kalt becomes kälter in the comparative.',
    'So … wie yapısında sıfat temel biçimdedir.': 'In so … wie the adjective stays in its basic form.',
    'Von allen grubunda en küçük olanı am kleinsten ile belirtirsin.': 'For the smallest of all (von allen) use am kleinsten.',
    'Gern sözcüğünün Komparativ biçimi lieber olur.': 'The comparative of gern is lieber.',
    'Viel sözcüğünün karşılaştırması mehr olur.': 'The comparative of viel is mehr.',
    'Zarf görevindeki Superlativ, am längsten biçimindedir.': 'As an adverb the superlative is am längsten.',
    'Gut sözcüğünün Komparativ biçimi besser olur.': 'The comparative of gut is besser.',
    "Fark bildiren Komparativ'den sonra als gelir.": 'After a comparative of difference comes als.',
    'Einfach → einfacher + als.': 'einfach → einfacher + als.',
    'Zaman zarfı olarak Superlativ am frühesten olur.': 'As a time adverb the superlative is am frühesten.',
    'Als ile fark bildirirken später kullanılır.': 'For a difference with als use später.',
    'Genauso … wie eşitlik bildirir.': 'genauso … wie expresses equality.',
    'Einen sonrası eril Akkusativ sıfat eki -en olur.': 'After einen (masculine Akkusativ) the adjective ending is -en.',
    'Die + dişil Akkusativ ile sıfat -e alır.': 'With die + feminine Akkusativ the adjective takes -e.',
    'Einem + Dativ sonrası sıfat -en alır.': 'After einem (Dativ) the adjective takes -en.',
    'Ein + nötr Nominativ ile sıfat -es alır.': 'With ein + neuter Nominativ the adjective takes -es.',
    'Die + çoğul Akkusativ ile sıfat -en alır.': 'With die + plural Akkusativ the adjective takes -en.',
    'Ein + eril Nominativ ile sıfat -er alır.': 'With ein + masculine Nominativ the adjective takes -er.',
    "Artikelsiz nötr Akkusativ'de sıfat -es alır.": 'Without an article, neuter Akkusativ: the adjective takes -es.',
    'Einer + Dativ sonrası sıfat -en alır.': 'After einer (Dativ) the adjective takes -en.',
    'Welche + dişil Nominativ ile sıfat -e alır.': 'With welche + feminine Nominativ the adjective takes -e.',
    'Der + eril Nominativ ile sıfat -e alır.': 'With der + masculine Nominativ the adjective takes -e.',
    'Den + çoğul Dativ sonrası sıfat -en alır.': 'After den (plural Dativ) the adjective takes -en.',
    'Keine + çoğul Akkusativ sonrası sıfat -en alır.': 'After keine (plural Akkusativ) the adjective takes -en.',
    "Artikelsiz eril Nominativ'de sıfat -er alır.": 'Without an article, masculine Nominativ: the adjective takes -er.',
    'Artikelsiz dişil Akkusativ ile sıfat -e alır.': 'Without an article, feminine Akkusativ: the adjective takes -e.',
    'Geçmişte bir kez yaşanan olay için als kullanılır.': 'For a single event in the past use als.',
    'Gelecekteki bir zaman veya koşul için wenn kullanılır.': 'For a future time or a condition use wenn.',
    'Geçmişte tekrar eden olaylarda immer wenn kullanılır.': 'For repeated events in the past use immer wenn.',
    'Tarihi belli tek bir geçmiş olay için als kullanılır.': 'For a single past event at a known time use als.',
    'Bugün için geçerli koşul wenn ile kurulur.': 'A condition for today is formed with wenn.',
    'O tek geçmiş olayın zamanını als belirtir.': 'als gives the time of that single past event.',
    'Şimdiki zamandaki koşul için wenn kullanılır.': 'For a condition in the present use wenn.',
    'Zum ersten Mal, yaşanmış tek olayı işaret ediyor.': 'zum ersten Mal points to a single event that happened.',
    'Henüz gerçekleşmemiş koşul için wenn kullanılır.': 'For a condition that has not happened yet use wenn.',
    'Jedes Mal, tekrar anlamı verir ve wenn ile kullanılır.': 'jedes Mal expresses repetition and is used with wenn.',
    'Bir kez yaşanan doğum gibi geçmiş olaylarda als kullanılır.': 'For one-time past events such as a birth use als.',
    'Yardım, adresi gönderme koşuluna bağlıdır.': 'The help depends on the condition of sending the address.',
    'Dünkü tek elektrik kesintisi als ile anlatılır.': "Yesterday's single power cut is described with als.",
    'Tekrar eden bir durumda wenn kullanılır.': 'For a repeated situation use wenn.',
    'Geben fiilinin du emir biçimi gib olur.': 'The du imperative of geben is gib.',
    'Birden fazla kişiye ihr emir biçimiyle seslenilir.': 'Several people are addressed with the ihr imperative.',
    'Kibar emir biçimi fiil + Sie şeklindedir.': 'The polite imperative is verb + Sie.',
    'Sein, du emir biçiminde sei olur.': 'The du imperative of sein is sei.',
    'Sprechen fiilinin ihr emir biçimi sprecht olur.': 'The ihr imperative of sprechen is sprecht.',
    'Mitbringen fiilinde mit cümlenin sonuna gider.': 'With mitbringen, mit goes to the end of the sentence.',
    'Lesen, du emir biçiminde lies olur.': 'The du imperative of lesen is lies.',
    'Werfen fiilinin ihr emir biçimi werft olur.': 'The ihr imperative of werfen is werft.',
    'Resmî hitapta gehen Sie kullanılır.': 'In formal address use gehen Sie.',
    'Abstellen, du ile stell … ab olur.': 'abstellen with du becomes stell … ab.',
    'Sein, ihr emir biçiminde seid olur.': 'The ihr imperative of sein is seid.',
    'Kibar emir biçiminde setzen Sie sich kullanılır.': 'In the polite imperative use setzen Sie sich.',
    'Essen, du emir biçiminde iss olur.': 'The du imperative of essen is iss.',
    'Waschen, ihr emir biçiminde wascht olur.': 'The ihr imperative of waschen is wascht.',
    "Versuchen'dan sonra zu + mastar kullanılır.": 'After versuchen use zu + infinitive.',
    'Ayrılabilir fiilde zu önek ile kök arasına gelir.': 'With a separable verb, zu goes between the prefix and the stem.',
    'Es ist einfach yapısında eylem zu + mastarla ifade edilir.': 'After es ist einfach the action is expressed with zu + infinitive.',
    'Aufstehen fiilinde zu, auf ve stehen arasına gelir.': 'In aufstehen, zu goes between auf and stehen.',
    'Absagen ayrılabilir. Doğru mastar abzusagen olur.': 'absagen is separable. The correct form is abzusagen.',
    'Lust haben yapısından sonra zu + mastar gelebilir.': 'After Lust haben you can use zu + infinitive.',
    'Hoffen + zu, özne iki eylemde de aynıysa kullanılabilir.': 'hoffen + zu works when the subject is the same for both actions.',
    'Ayrılabilir einpacken fiilinde zu araya girer.': 'In the separable verb einpacken, zu goes in the middle.',
    'Beschließen + zu, karar verilen eylemi belirtir.': 'beschließen + zu names the action that was decided.',
    'Aussprechen ayrılabilir. Zu, aus ve sprechen arasına gelir.': 'aussprechen is separable. zu goes between aus and sprechen.',
    'Anrufen fiilinin zu biçimi anzurufen olur.': 'The zu form of anrufen is anzurufen.',
    'Bitten + zu yapısı, birinden bir şey istemeyi ifade eder.': 'bitten + zu expresses asking someone to do something.',
    'Bu kullanımda lernen + zu, öğrenilen eylemi belirtir.': 'Here lernen + zu names the action being learned.',
    'Vorbeikommen ayrılabilir. Doğru biçim vorbeizukommen.': 'vorbeikommen is separable. The correct form is vorbeizukommen.',
}


def translate(expl):
    if expl in FIXED:
        return FIXED[expl]
    for pattern, repl in RULES:
        if re.match(pattern, expl):
            return re.sub(pattern, repl, expl)
    return None


raw = [l.rstrip('\n').split('|') for l in open(ROOT + '/tools/levels/a2/grammar.txt', encoding='utf-8') if l.strip()]
expl_of = {}
for topic, q, answer, wrong, why, q_tr in raw:
    m = re.match(r'^.{3,60}?: „(.*)“$', q)
    if m:
        q = m.group(1)
    expl_of.setdefault((q, answer), why)

lines, missing = [], set()
for i, item in enumerate(d['grammarItems']):
    expl = expl_of[(item['q'], item['options'][0])]
    en = translate(expl)
    if en is None:
        missing.add(expl)
        continue
    lines.append(f'a2.gi.{i} :: {en}')
open(ROOT + '/tools/i18n/en/36_a2_grammar_items.txt', 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
print(len(lines), 'translated; missing:', len(missing))
for m in sorted(missing):
    print('  ', m)
