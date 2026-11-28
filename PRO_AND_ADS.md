# Pro ve reklamları geri açmak

27 Kasım 2026: Deschly ilk olarak **tamamen ücretsiz ve reklamsız** yayınlanıyor. Gelir (abonelik, ömür boyu satın
alma, AdMob) hukuki durum netleşince açılacak. Hiçbir şey silinmedi; bu dosya neyin nerede durduğunu ve geri açma
sırasını anlatır.

## Uygulamada hazır duranlar (kod silinmedi)

| Ne | Nerede | Şu an |
|---|---|---|
| Pro sayfası, hoş geldin, günlük limit (30 soru), ünite kilidi (ilk 3 ücretsiz) | `Sources/Features/Pro/` | `DeschlyFreeForAll = true` olduğu için görünmüyor |
| Satın alma (StoreKit 2), geri yükleme, abonelik yönetimi | `Sources/Core/Store/ProStore.swift` | Aynı |
| Erken kullanıcılara 30 gün Pro hediyesi (`ProGift`) | `ProStore.swift` | Satış açılınca ilk açılışta başlar |
| Bugün'de "kalan ücretsiz soru" şeridi | `TodayView.swift` | Sadece ücretsiz kullanıcıda |
| Reklam kodu (banner, tam ekran, ödüllü, UMP izni, ATT) | `Sources/Core/Services/Ads.swift` | Google paketleri yokken boş yer tutucular derlenir |

Ürün kimlikleri (App Store Connect'te birebir aynı olmalı):
`com.yasindeger.almanca.pro.yearly`, `com.yasindeger.almanca.pro.monthly`, `com.yasindeger.almanca.pro.lifetime`.

Kararlaştırılan fiyatlar: aylık 2,99, yıllık 19,99 (7 gün ücretsiz deneme), ömür boyu 39,99. ABD doları temel;
İsviçre'de aynı rakamlar CHF (yoksa en yakın fiyat noktası); Türkiye ve diğer ülkeler Apple'ın otomatik karşılığı.

## Geri açma sırası

### 1. Sadece Pro (reklamsız satış)
1. App Store Connect: Paid Apps sözleşmesi, banka, vergi; ürünleri oluştur (aşağıdaki "App Store Connect" bölümü).
2. `Info.plist`: `<key>DeschlyFreeForAll</key><false/>`
3. `Sources/Features/Today/StreakView.swift` kendiliğinden eski metne döner (`freeze.body`).
4. App Store metni: `../AppStore-Sayfasi-Pro-yedek.md` içindeki "ÜCRETSİZ VE DESCHLY PRO" bölümleri (üç dil) ve
   App Review notları. Reklam cümlelerini çıkar ("Ücretsiz sürümde reklam gösterilir." vb.).
5. Gizlilik sitesi: "Satın alımlar (Deschly Pro)" bölümünü geri koy (deschly-site git geçmişi, commit `c52fbf0e`).
6. İstersen Pro ve reklamlı deneme IPA'sını CI'a geri koy (28 Kasım 2026'da kaldırıldı). `.github/workflows/ios.yml`
   "Package IPA" adımında `du -h Deschly.ipa` satırının altına:
   ```bash
   rm -rf pro && mkdir -p pro/Payload
   cp -R "$app" pro/Payload/
   /usr/libexec/PlistBuddy -c "Set :DeschlyFreeForAll false" pro/Payload/Almanca.app/Info.plist
   /usr/libexec/PlistBuddy -c "Add :DeschlyPreviewPrices bool true" pro/Payload/Almanca.app/Info.plist
   (cd pro && ditto -c -k --keepParent Payload ../Deschly-Pro-Reklam.ipa)
   unzip -t Deschly-Pro-Reklam.ipa > /dev/null
   ```
   ve yükleme adımı (`actions/upload-artifact@v4`, name `Deschly-Pro-Reklam-IPA`, path `Deschly-Pro-Reklam.ipa`).

### 2. Reklamlar da
1. `project.yml` en üste, `targets:` satırından önce:
   ```yaml
   packages:
     GoogleMobileAds:
       url: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
       from: 12.0.0
     GoogleUserMessagingPlatform:
       url: https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git
       from: 3.0.0
   ```
   ve `Almanca` hedefinin `dependencies:` listesinde `- target: DeschlyWidgets` satırından önce:
   ```yaml
         - package: GoogleMobileAds
         - package: GoogleUserMessagingPlatform
   ```
   Paketler gelince `Ads.swift` içindeki gerçek kod kendiliğinden derlenir.
2. `Info.plist` içine (`DeschlyFreeForAll` satırının altına):
   ```xml
   <key>GADApplicationIdentifier</key><string>ca-app-pub-2051677494226499~9239410708</string>
   <key>DeschlyAdBanner</key><string>ca-app-pub-2051677494226499/6330623448</string>
   <key>DeschlyAdInterstitial</key><string>ca-app-pub-2051677494226499/4114563184</string>
   <key>DeschlyAdRewarded</key><string>ca-app-pub-2051677494226499/8856267329</string>
   ```
   ve `NSSpeechRecognitionUsageDescription` metninin altına:
   ```xml
   <key>NSUserTrackingUsageDescription</key>
   <string>Your choice decides whether ads in the free version can be personalised. Deschly works the same either way.</string>
   <key>SKAdNetworkItems</key>
   <array>
     <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
   </array>
   ```
3. Gizlilik sitesi: "Google AdMob" bölümü ve haklar paragrafındaki "Reklam gizlilik seçenekleri" (commit `c52fbf0e`).
4. App Store Connect → App Privacy: Device ID (takip, üçüncü taraf reklam), Product Interaction ve Advertising Data,
   Coarse Location, Crash ve Performance Data. Google'ın "App Store veri açıklaması" sayfasıyla karşılaştır.
5. AdMob: Privacy & messaging → GDPR mesajı (AB/UK/CH) yayınla; uygulama mağazaya çıkınca App Store'a bağla.

## App Store Connect (satış açılırken)
1. Business → Agreements: Paid Apps sözleşmesi, banka hesabı, vergi formu (W-8BEN). Durum "Active" olana kadar bekle.
2. Business → Compliance → Digital Services Act: satış varsa "trader" (adres ve telefon AB sayfasında görünür).
3. Small Business Program: developer.apple.com/app-store/small-business-program (komisyon %15).
4. Monetization → Subscriptions: grup "Deschly Pro"; yıllık (1 yıl, 7 gün ücretsiz deneme) ve aylık (1 ay), ikisi Level 1.
5. Monetization → In-App Purchases: Non-Consumable ömür boyu; Family Sharing kapalı.
6. Her ürüne: fiyat (temel ülke ABD), Türkçe ve İngilizce ad ve açıklama, Pro sayfasının ekran görüntüsü.
7. Users and Access → Sandbox: test hesabı; TestFlight'ta satın alma, iptal, geri yükleme dene.
8. Sürüm sayfasında "In-App Purchases and Subscriptions" bölümüne üç ürünü ekle, sürümle birlikte gönder.
