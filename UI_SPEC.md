# KEROCHAT — UI Tasarım Brief'i (Tüm Ekranlar ve Özellikler)

> **Tasarımcıya/Yapay zekaya not:** kerochat, Azar (rastgele görüntülü eşleşme) ile
> BlindID (anonim sesli sohbet + sesli odalar) melezidir. Aşağıda uygulamanın TÜM
> ekranları, her ekrandaki TÜM elemanlar, durumlar ve akışlar listelenmiştir.
> Senden beklenen: bu yapıyı koruyarak modern, karakterli, mobil öncelikli yeni bir
> UI tasarlamak. Akışları ve özellik setini değiştirme; görsel dili özgürce yeniden
> yorumlayabilirsin. Platform: Flutter (mobil dikey öncelikli + web'de çalışıyor).

---

## 1. Marka ve Mevcut Görsel Kimlik (referans — değiştirilebilir)

- **İsim:** kerochat · **Ton:** genç, gece hayatı, flörtöz ama güvenli; Türkçe, samimi ("sen" dili, bol emoji)
- **Tema:** koyu (arka plan #0B0B10, yüzeyler #14141A / #1C1C24, çizgiler #262630)
- **Ana gradyan:** pembe→mor (#FF3B81 → #8B5CF6) — CTA'lar, vurgular
- **İkincil kimlikler:** SESLİ mod = gece mavisi/turkuaz (#102433 zemin, #2BD9C8 vurgu) — görüntülüden bilinçli olarak farklı; VIP = altın (#F7C948); tehlike #FF5862; çevrimiçi yeşili #2BE0A6; uyarı #FFD460
- **Tipografi:** başlıklar Sora (bold, sıkı letter-spacing), metin Manrope
- **Bileşen dili:** 16-28px radius kartlar, pill butonlar, blur'lu cam (glassmorphism) alt bar, bottom-sheet ağırlıklı etkileşim, üstten düşen toast bildirimleri
- **Avatarlar:** kullanıcılar gerçek fotoğraf KULLANMAZ — DiceBear çizgi avatarları veya renkli monogram (anonimlik ürünün kalbi)

## 2. Navigasyon Haritası

Alt bar 4 sekme: **Keşfet · Odalar · Sohbetler · Profil**
Sekme dışı ekranlar (üste açılır): Eşleşme arama, Görüntülü arama, Sesli arama,
Oda içi, DM thread, Bildirimler, Mağaza, 18+ onayı, Gelen arama (overlay).
Sheet'ler (bottom sheet): konu seçimi, filtreler, çark, avatar galerisi, kullanıcı
adı, referans/davet, hediye, şikayet, oda kurma, oda sohbeti, oda uzatma, oda üye
menüsü, oda arkadaş daveti, e-posta girişi.

---

## 3. EKRANLAR

### 3.1 Onboarding / Giriş
- Arka plan: koyu + iki "aurora" ışık lekesi + 4 adet hafifçe yüzen/dönen kullanıcı kartı kolajı (isim+yaş etiketli, çevrimiçi noktası)
- "şu an **48.213** kişi çevrimiçi" canlı rozeti (yeşil nokta parlamalı)
- Büyük başlık: "Dünyayla göz göze gel" + alt metin (anlık çeviri vaadi)
- CTA: **Google ile devam** (birincil, gradyan) · **E-posta ile devam** (ikincil hayalet)
- E-posta sheet'i: GİRİŞ/KAYIT sekmesi, e-posta+şifre alanları, hata kutusu, tek CTA
- Yasal satır: Kullanım Koşulları + Gizlilik + "kerochat 18 yaş ve üzeri içindir"
- ❗ Misafir girişi YOK

### 3.2 Yaş Onayı (18+) — kayıttan hemen sonra, tek seferlik
- Ortada büyük "18+" amblemi, "Yaş doğrulaması" başlığı, açıklama
- Onay kutusu kartı: "18 yaşından büyük olduğumu beyan ve onay ediyorum"
- CTA (kutu işaretlenmeden pasif): "Onayla ve devam et"
- İkincil link: "18 yaşından küçüğüm — çıkış yap"

### 3.3 Keşfet (ana sekme)
- **Üst bar:** kendi avatarın (tıkla→profil) · "İyi akşamlar 👋 / {isim}" · 🎡 çark butonu · 🔔 bildirim (unread sayaç rozetli) · 💎 elmas bakiyesi pill'i (+ butonu → mağaza)
- **Filtre çipleri** (yatay kaydırma): Cinsiyet (Herkes/Kadın/Erkek) · Bölge (Tüm dünya/Türkiye/Avrupa/Asya/Amerika) · Dil (Farketmez/TR/EN/ES/DE). "Farketmez" dışı her seçim ücretlidir → seçiliyken yanında "💎 5/eşleşme" bilgi çipi belirir. Filtre sheet'lerinde ücretli seçeneklerin yanında küçük 💎5 rozeti + açıklama satırı
- **Orta alan:** kendi kamera önizlemen (büyük kart), üstünde "N çevrimiçi" rozeti, kamera çevir + güzelleştirme mini butonları
- **Alt CTA'lar:** yan yana iki buton — **🎥 Görüntülü** (birincil gradyan) · **🎙 Sesli** (cam/ghost)
- Sesli'ye basınca **konu seçim sheet'i**: 2 sütun 6 kart — 🎲 Rastgele · 👋 Tanışalım · 💭 Dertleş · 🤫 İtiraf Et · 🎵 Müzik · 🇬🇧 English ("aynı konuyu seçenle eşleşirsin" alt metni)
- **Çark sheet'i:** eşit dilimli renkli çark (dilimler sunucudan gelir: emoji+etiket; oranlar ASLA gösterilmez), üstte işaretçi ok, "Çevir!" CTA, dönüş animasyonu ~3.5sn, sonuç rozeti (+10 elmas / süre kartı / VIP / boş), "günde 1 ücretsiz çevirme" bilgisi, hak bitmişse "yarın tekrar gel 🌙"

### 3.4 Eşleşme Aranıyor
- Sesli modda gece mavisi radyal zemin; görüntülüde kendi kamera önizlemen (karartılmış)
- Merkez: 3 katmanlı pulse halka + ortada dönen avatar önizleme
- Durum başlığı: "Bağlanıyor… / Eşleşme aranıyor…" + alt açıklama
- Etiket pill'leri: mod (🎥/🎙), # konu (sesli), cinsiyet, bölge, dil
- Alt: "Vazgeç" (cam buton)

### 3.5 Görüntülü Arama (1-1)
- Karşı tarafın videosu tam ekran; alt/üst okunabilirlik gradyanları
- **Eşleşme intro'su (2.2sn):** karartma üzerinde "⚡ Eşleşme bulundu" rozeti + büyük monogram/avatar + isim + ülke bayrağı + cinsiyet çipleri + "Bağlantı kuruluyor…"
- **Üst bar:** karşı tarafın avatarı+ismi+geçen süre pill'i · 🚩 şikayet butonu
- **Self PiP:** sağ üstte küçük kendi kameran (radius 18, gölgeli)
- **Kontrol dock'u (alt):** Mikrofon · Kamera çevir · ❤️ Beğen · 🎮 Oyun · 🎁 Hediye (vurgulu) · 💬 Mesaj — altında geniş **"Sonraki"** + kırmızı **kapat**
- **Hediye sheet'i:** 3 sütun grid (emoji + ad + 💎fiyat: Gül 9 · Kalp 19 · Yıldız 29 · Taç 99 · Roket 149 · Yüzük 299); gönderince tam ekran **hediye yağmuru** animasyonu (iki tarafta da)
- **Oyun paneli (overlay):** XOX · Adam Asmaca · Doğruluk/Cesaret; davet→kabul akışı; davet gelince panel kendiliğinden açılır
- **Şikayet sheet'i:** Şikayet et (moderasyon) · Engelle (bir daha eşleşmez)
- In-call yazılı chat + uçuşan emoji tepkileri

### 3.6 Sesli Arama (1-1) — görüntülüden AYRI kimlik
- Gece mavisi/turkuaz ambiyans, kamera yok
- Merkez: turkuaz pulse halkalı büyük avatar + isim + ülke bayrağı + "🎭 Anonim sesli sohbet"
- **Üst bar:** **geri sayım pill'i** (rastgele eşleşme 2:00'dan sayar; son 30sn kırmızı; üstünde ⏱+ ikonu — TIKLA=SÜRE UZAT) · ortada # konu rozeti (turkuaz) · 🚩 şikayet
- Süre uzatma: günde 2 ücretsiz hak, sonra süre kartı; normal +2:30, VIP +4:00; uzatınca iki tarafa toast ("⏱ X süreyi uzattı!"); süre dolunca "⏰ Görüşme süresi doldu"
- Kontroller görüntülüyle aynı, kamera butonları yok
- Arkadaş aramalarında süre sınırı yok → pill geçen süreyi gösterir

### 3.7 Gelen Arama (tam ekran overlay)
- Karartılmış zemin, ortada parlayan gradyan avatar, isim, "📹 Görüntülü arıyor… / 📞 Sesli arıyor…"
- Alt: kırmızı **Reddet** ve yeşil **Kabul et** yuvarlak butonları (45sn sonra kendini kapatır)

### 3.8 Odalar (sekme) — yatay kaydırmalı kart destesi
- Başlık "Odalar" + "Kaydır, beğendiğine katıl 🎙" + sağda 🏠oda/👤kişi sayaç pill'i + yenile
- **Deste:** PageView, yandaki kartlar kenardan görünür; her kart doygun renkli
  (pembe/mor/indigo/turuncu/yeşil/turkuaz rotasyon):
  - Oda adı (büyük, ortalı) · altında "# konu" ve "👤 2/4" rozetleri
  - **Üye slot ızgarası** (kapasite kadar, 3-4 slot): dolu slot = üye avatar kartı + isim pill'i; boş slot = "+ Sohbete Katıl" (tıklanabilir); taşarsa son slotta "+N"
  - Altta mavi **"Katıl"** CTA
- Dolu odalar listede HİÇ görünmez (sistem otomatik yenisini açar)
- Odalar sistem tarafından otomatik üretilir (Tanışalım, Şarkını Söyle, Dertleşelim, İtiraf Saati, Gece Sohbeti, English Time, Oyun & Eğlence…)
- "Oda Kur" FAB → **yalnızca VIP** (değilse açıklayıcı toast); kurma sheet'i: oda adı + konu çipleri
- Boş durum: ikon + "Şu an açık oda yok" + Oda Kur

### 3.9 Oda İçi
- **Başlık:** oda ikonu · oda adı · "# konu · N kişi · geçen süre" · **geri sayım pill'i** (yeşil→son 60sn kırmızı; tıkla=uzatma sheet'i) · çıkış butonu
- Sistem odası süresi 3:20 — **ilk kişi katılınca başlar**; dolunca oda kapanır, sistem yenisini açar
- **Üye kartları (2 sütun, büyük):** gradyan/avatar zemin, alt scrim üzerinde 🎙/🔇 durum rozeti + isim + 👑 (kurucu); sol üstte rozetler: kırmızı **ADMIN** (kalkanlı), altın **VIP 👑**; **konuşan üyede yeşil parlayan çerçeve**; kendi kartına dokun = mikrofonu aç/kapat
- **Üye popup'ı (herkese açık):** ❤️ **Beğen** ("beğenin odadaki HERKESE görünür" — toast yayını) · 🤝 **Arkadaşlık isteği gönder** (onaylarsa arkadaş) · 🚩 Şikayet et · [kurucu ise] 🔇 Sustur. ❗ Odadan atma YOK
- **Alt dock (3-4 yuvarlak buton + etiket):** 🎙 Söz al/Sustur (aktifken gradyan) · 💬 Sohbet (okunmamış rozeti) · 👥 Davet · ⏱ Uzat
- **Sohbet sheet'i:** mesaj listesi (👑 işaretli, kendi mesajın vurgulu) + yazma alanı — ekranı kaplamaz, istenince açılır
- **Uzatma sheet'i:** 🎟 Süre kartı kullan (+3dk) · 💎 20 elmas harca (+3dk); uzatınca odaya "X odayı 3 dk uzattı!" duyurusu
- **Davet sheet'i:** arkadaş listesi — avatar + yeşil çevrimiçi noktası + "Çevrimiçi/son görülme" + "Davet et" butonu (davet edilen bildirimden tek dokunuşla katılır)

### 3.10 Sohbetler (sekme)
- Başlık + arama kutusu + iki çip: **Mesajlar** / **Arkadaşlar**
- **Mesajlar:** satır = avatar · isim + bayrak · son mesaj önizleme · zaman · unread rozeti; boş durum metinli
- **Arkadaşlar:** satır = avatar (**yeşil çevrimiçi noktası**) · isim · durum satırı ("Çevrimiçi" yeşil / "23 dk önce" gri) · 4 aksiyon butonu: 💬 DM · 📞 sesli ara · 📹 görüntülü ara · 👋 dürt (çevrimdışını uygulamaya çağırır); çevrimiçi olanlar üstte; arkadaş limiti 20

### 3.11 DM Thread
- Klasik mesajlaşma: baloncuklar, zaman, foto gönderme
- **Fotoğraflar imhalı:** karşı taraf görüntüleyince otomatik silinir; görüntüleyici ekran görüntüsünü caydırır; gönderirken uyarı
- Üstten: sesli/görüntülü arama kısayolları eklenebilir (tasarımcı önerisi serbest)

### 3.12 Bildirimler
- "Tümünü oku" aksiyonu; satırlar tür ikonlu ve renk kodlu: beğeni, eşleşme, mesaj, hediye, elmas, VIP, sistem/duyuru, **arkadaşlık isteği (✓ / ✕ butonları satır içinde)**, **oda daveti ("Katıl" butonu → direkt odaya)**, dürtme, arama; okunmamışlar vurgulu

### 3.13 Profil (sekme)
- **Kimlik kartı:** büyük avatar + düzenleme rozeti (tıkla → **avatar galerisi sheet'i**: 8 stil çipi — 5 ücretsiz + 3 "👑 VIP" kilitli — her stilde 12 varyant grid + "avatarı kaldır") · isim + VIP rozeti · e-posta/rol · güven puanı rozeti (0-100, renk kademeli)
- Butonlar: **Kullanıcı adı** (sheet: rastgele üretilmiş adını değiştir — toplam 2 hak, kalan hak gösterilir) · **Coin al**
- **Elmas kartı:** bakiye + Mağaza + **Günlük bonus** satırı (seri/streak: 5+seri×5, tavan 100)
- **VIP banner'ı** (gradyan): aktifse bitiş tarihi, değilse satış vaadi
- **Davet linkim kartı:** "X davet · Y aktif · kişi başı elmas kazan" → **referans sheet'i**: davet linki + Kopyala + "Kodun: abc123" + (davet edilmemişse) kod girme alanı
- Ayar grupları: filtre tercihleri, dil, doğrulama, gizlilik · bildirimler, engellenenler · çıkış
- Moderatör/admin görürse: Admin paneli girişi

### 3.14 Mağaza
- Elmas bakiye başlığı; **coin paketleri** kartları (100/₺29 · 550+50/₺99 · 1200+200/₺199 POPÜLER · 3000+750/₺449), seçili kart vurgulu, altta yapışkan satın al CTA'sı
- VIP tanıtım bölümü (avantajlar: oda kurma, 7dk oda, +4dk uzatma, özel avatarlar, taç…)
- **Ücretsiz kazan:** "Arkadaşını davet et +20" (→ referans sheet) · "Reklam izle +5" (→ ödüllü reklam akışı: günde 5 hak; reklam diyaloğu; ödül toast'ı "bugün kalan: N")

### 3.15 Genel Bileşenler
- **Toast:** üstten süzülen blur pill (2.4sn)
- **Bottom sheet:** üst tutamaç çizgisi, başlık, 28 radius üst köşeler
- **Tab bar:** blur cam pill, aktif sekme yumuşak vurgu halkası
- **Rozet dili:** ADMIN (kırmızı+kalkan), VIP (altın gradyan+taç), çevrimiçi (yeşil nokta parlamalı), unread (gradyan sayı pill'i)
- Boş/yükleniyor/hata durumları her listede tanımlı (ikon + başlık + tek satır yönlendirme)

---

## 4. Önemli Ürün Kuralları (UI bunları hissettirmeli)
1. **Anonimlik önce:** gerçek isim/fotoğraf yok; rastgele isimler + çizgi avatarlar övünülecek bir özellik gibi sunulmalı
2. **İki mod iki kimlik:** görüntülü = pembe enerji, sesli = gece mavisi gizem — kullanıcı hangi moddayken nerede olduğunu renkten anlamalı
3. **Kıtlık mekanikleri görünür ama sıkıcı değil:** geri sayımlar oyunlaştırılmış (son saniye kırmızısı, tek dokunuş uzatma), elmas bedelleri küçük rozetlerle dürüstçe belirtilir
4. **VIP hissettirilir:** taç, altın vurgular, kilitli stiller — ama ücretsiz deneyim asla "kısıtlanmış" hissettirmemeli
5. Türkçe, samimi, emoji'li mikro-metinler ("yarın tekrar gel 🌙", "hadi gel!")

## 5. Kapsam Dışı
Web yönetim paneli (ayrı üründür), sunucu/DB detayları, ödeme akışının içi (henüz entegre değil — buton placeholder).
