# Deschly

Almanca öğrenme uygulaması (iPhone, SwiftUI, iOS 16+). Maskot: Lina. Slogan: „Deutsch lernen, leicht gemacht.“
Arayüz ve içerik dilleri: Türkçe, English, Español, Français, Italiano. Hesap ve sunucu yok; ilerleme cihazda kalır.

- **Bugün:** Lina'nın selamı, günün okuma metni, günün kelimesi, hızlı pratik
- **Günlük okuma:** her gün seviyeye uygun yeni metin, dokununca artikel/anlam, çeviri, sesli okuma, metinden quiz, yerel bildirim
- **Seviyeler:** A1 (2.085 kelime, 22 gramer konusu, sınav provası, dinleme, sayılar); A2, B1, B2 sırada
- **Videolar:** A1–C1 YouTube dersleri, izlenme ve not

Mimari ve veri akışı: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

İçeriği yeniden üretmek için:

```
python -X utf8 tools/a1_extras.py a1_base.json tools/data/a1_raw.json
python -X utf8 tools/build_core.py tools/data/a1_raw.json
python -I -X utf8 tools/pack_content.py tools/data/a1_raw.json Resources/content/a1.json
python -I -X utf8 tools/build_daily.py a1
```

## IPA dosyasını indir

1. GitHub deposunda **Actions → iPhone IPA** öğesini aç.
2. Son başarılı çalıştırmayı aç. Gerekirse **Run workflow** ile bir derleme başlat.
3. **Artifacts → Deschly-IPA** arşivini indir ve ZIP’ten `Deschly.ipa` dosyasını çıkar.

Bu dosya kişisel kurulum için hazırlanır. Telefonuna yüklerken Apple hesabınla imzalaman gerekir.

## Windows üzerinden iPhone’a kur

1. [AltStore Classic’in Windows kılavuzunu](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) takip ederek AltServer’ı bilgisayarına ve AltStore Classic’i iPhone’una kur.
2. IPA dosyasını iCloud Drive veya başka bir dosya aktarım yöntemiyle iPhone’daki **Dosyalar** uygulamasına koy.
3. iPhone’da **AltStore → My Apps → +** yolunu aç ve IPA dosyasını seç. AltServer bilgisayarda açık olmalı. Gerektiğinde telefonu USB ile bağla.
4. Derleme kurulduğunda **Deschly** simgesine dokun. Ücretsiz Apple hesabıyla uygulamayı yedi gün dolmadan AltStore üzerinden yenile. Bilgisayar, kurulum ve yenileme sırasında gerekir. Ders listesini kullanmak için bilgisayara bağlı olmak gerekmez.

Apple hesabı bilgilerini yalnızca kullandığın imzalama aracına gir. GitHub’a yükleme.