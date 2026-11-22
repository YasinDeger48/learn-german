# Almanca Derslerim

SwiftUI ile hazırlanmış kişisel iPhone uygulaması. iOS 16 veya üstünü gerektirir. A1–C1 arasındaki 298 ders cihazda listelenir. Videolar YouTube’da açılır ve izlenme işaretleri cihazda saklanır.

## A1 Hazırlık sekmesi

`a1.json`, „Almanca A1 Kelimeler, Gramer ve Sınav Hazırlık“ PDF'inden üretilir (`tools/`):

- 693 A1 kelimesi, 1386 örnek cümle, okunuşlar, 22 gramer konusu, 20 okuma metni
- Ek olarak sık kullanılan ~1390 kelime (`tools/words/*.txt`): artikel, okunuş, Türkçe, 1 örnek cümle
- Oyunlar: artikel, kelime ↔ Türkçe, cümle anlamı, boşluk doldurma, cümle kurma, dinleme, sınav dinlemesi (122 diyalog, anons ve telefon mesajı; kadın, erkek ve anons sesi; sınavdaki gibi 2 kez), yazma/dikte, çoğul, fiiller/Perfekt, gramer, sayı-saat-tarih, okuma, „Ne dersin?“ / „Hatayı bul“, artikel yarışı, eşleştirme, 30 soruluk sınav provası
- Görülen soru tekrar sorulmaz; yanlışlar „Hatalarım“da toplanır. İlerleme yedek dosyasına da yazılır.

Veriyi yeniden üretmek için (Windows, Python 3 + pdftotext):

```
pdftotext -enc UTF-8 Almanca_A1_Kelimeler_Gramer_ve_Sinav_Hazirlik.pdf a1raw.txt
python -X utf8 tools/parse_a1_pdf.py a1raw.txt a1_base.json
python -X utf8 tools/a1_extras.py a1_base.json a1.json
python -X utf8 tools/build_core.py a1.json
```

## IPA dosyasını indir

1. GitHub deposunda **Actions → iPhone IPA** öğesini aç.
2. Son başarılı çalıştırmayı aç. Gerekirse **Run workflow** ile bir derleme başlat.
3. **Artifacts → Almanca-Derslerim-IPA** arşivini indir ve ZIP’ten `Almanca-Derslerim.ipa` dosyasını çıkar.

Bu dosya kişisel kurulum için hazırlanır. Telefonuna yüklerken Apple hesabınla imzalaman gerekir.

## Windows üzerinden iPhone’a kur

1. [AltStore Classic’in Windows kılavuzunu](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows) takip ederek AltServer’ı bilgisayarına ve AltStore Classic’i iPhone’una kur.
2. IPA dosyasını iCloud Drive veya başka bir dosya aktarım yöntemiyle iPhone’daki **Dosyalar** uygulamasına koy.
3. iPhone’da **AltStore → My Apps → +** yolunu aç ve IPA dosyasını seç. AltServer bilgisayarda açık olmalı. Gerektiğinde telefonu USB ile bağla.
4. Derleme kurulduğunda **Almanca Derslerim** simgesine dokun. Ücretsiz Apple hesabıyla uygulamayı yedi gün dolmadan AltStore üzerinden yenile. Bilgisayar, kurulum ve yenileme sırasında gerekir. Ders listesini kullanmak için bilgisayara bağlı olmak gerekmez.

Apple hesabı bilgilerini yalnızca kullandığın imzalama aracına gir. GitHub’a yükleme.