# KEROCHAT — Kapsamlı Sistem Dokümanı

> **Bu dokümanın amacı:** kerochat'in mimarisini, tüm özelliklerini, kullanıcı ve admin
> yeteneklerini en ince ayrıntısına kadar tek yerde anlatmak. Doküman, dış gözlerden
> (yapay zeka asistanları / danışmanlar) ürün ve teknik geri bildirim almak için
> hazırlanmıştır. Sondaki "Bilinen Eksikler" ve "Geri Bildirim İstenen Konular"
> bölümleri özellikle önemlidir.

---

## 1. Ürün Vizyonu

**kerochat**, iki başarılı ürünün melezi olarak konumlanan bir sosyal keşif uygulamasıdır:

- **Azar** tarafı: yabancılarla rastgele **birebir görüntülü** eşleşme (yüz yüze tanışma).
- **BlindID** tarafı: **anonim, sesli, konu odaklı** tanışma + Clubhouse tarzı **sesli grup odaları**.

Temel tez: görüntülü keşfin heyecanı ile sesli anonimliğin psikolojik güvenliğini tek
uygulamada birleştirmek. Kimlik varsayılan olarak gizli (rastgele kullanıcı adı + çizgi
avatar), kullanıcı ne kadar açılacağına kendi karar verir.

Hedef pazar: öncelikle Türkiye (UI Türkçe), ileride yurt dışı.
Yaş hedefi: 18+.
Gelir modeli (planlanan): coin ("elmas") ekonomisi + hediyeler + VIP abonelik + ödüllü reklam.
**Şu an gerçek ödeme entegrasyonu YOK** — mağaza UI hazır, satın alma butonu placeholder.

---

## 2. Teknik Mimari

Üç bağımsız bileşen:

| Bileşen | Teknoloji | Barındırma | Görev |
|---|---|---|---|
| **Uygulama** | Flutter (tek kod tabanı) | Web: Netlify CDN · Mobil: Android (build alınabiliyor, store'da değil) | Tüm kullanıcı arayüzü |
| **Sinyal sunucusu** | Node.js + `ws` WebSocket | Kendi VPS (AlmaLinux, systemd servis, Caddy reverse proxy + otomatik HTTPS) — `wss://ws.klslog.com` | Eşleştirme kuyruğu, WebRTC sinyalleşme, sesli oda yönetimi, oda süre sayacı |
| **Veritabanı + Auth** | Supabase (Postgres + GoTrue + Realtime + RLS) | Supabase cloud (Frankfurt) | Kullanıcılar, profiller, mesajlar, ekonomi, moderasyon — tüm kalıcı veri |

### Veri akışları

- **Görüntü/ses**: WebRTC ile **P2P** (uçtan uca, sunucudan geçmez). NAT delinemezse
  TURN relay devreye girer. TURN şu an ücretsiz/garantisiz OpenRelay (bilinen zayıflık).
- **Eşleşme + oda sinyali**: WebSocket üzerinden JSON mesajlar. Sunucu durumu tamamen
  **in-memory** (kuyruk, eşleşmeler, odalar) — restart'ta odalar kapanır.
- **In-call chat / emoji / mini oyunlar**: WebRTC **data channel** (P2P, sunucu görmez).
- **Oda içi yazılı sohbet**: WS üzerinden sunucu broadcast'i (odadaki herkese).
- **Kalıcı veriler**: Flutter → Supabase (RLS korumalı) doğrudan; hassas işlemler
  `security definer` RPC fonksiyonlarıyla.
- **Kimlik doğrulama**: Supabase JWT. Sinyal sunucusu JWT'yi bağlantıda doğrular
  (ES256 JWKS veya HS256), kullanıcının profilini (rol, VIP, nickname, avatar) service
  role ile çeker. **İsim istemciden alınmaz** — sunucu profildeki nickname'i dayatır
  (isim taklidi engellenir).

---

## 3. Kullanıcı Tipleri

| Tip | Nasıl olunur | Farkları |
|---|---|---|
| **Misafir (anonim auth)** | "Misafir olarak devam" — Supabase anonymous sign-in | Tam kullanım; ancak beğenilemez/hediye alamaz (karşı taraf için "misafir" kısıtları), çark ve davetler auth gerektirdiğinden çoğunu kullanabilir |
| **Kayıtlı** | Google OAuth veya e-posta | Tüm özellikler |
| **VIP** | Şu an: admin grant veya çarktan çıkan ödül (satış yok) | Oda açınca 3 dk yerine **7 dk** başlangıç süresi. (Planlanan: cinsiyet filtresi, sınırsız arkadaş, reklamsız, ekstra çark) |
| **Moderatör** | Admin atar (`profiles.role`) | Admin panelinin çoğu (kullanıcı yönetimi, ban, coin grant) |
| **Admin** | DB'de rol ataması | Her şey + rol değiştirme + VIP grant + çark yönetimi. Odalarda adının yanında kırmızı **ADMIN** rozeti görünür |

---

## 4. Kullanıcının Yapabildikleri (özellik özellik)

### 4.1 Kayıt, anonimlik ve profil
- İlk kayıtta sistem **otomatik rastgele Türkçe kullanıcı adı** üretir: sıfat+hayvan+sayı
  ("MorKedi42", "GizliBaykuş77"; 16×16 kombinasyon + 2 haneli sayı). Gerçek ad hiçbir
  yerde istenmez/gösterilmez.
- Kullanıcı adını **toplam 2 kez** değiştirebilir. Limit veritabanı seviyesinde kilitli:
  değişiklik sadece özel RPC ile yapılabilir, doğrudan UPDATE trigger'la reddedilir
  (admin/moderatör muaf). Profil ekranı kalan hakkı gösterir.
- **Çizgi avatar**: profilde avatara dokununca galeri açılır — 5 stil (Macera, Emoji,
  Robot, Çizgi, Karakter) × 12 varyant, DiceBear API (ücretsiz, depolama gerektirmez,
  avatar = URL). "Avatarı kaldır" seçilirse renkli monogram (isim baş harfi) kullanılır.
  Avatar her yerde görünür: eşleşme kartı, oda kartları, oda destesi önizlemesi, profil.
- Profilde: coin bakiyesi, güven puanı (trust score 0-100), rol rozeti, VIP durumu,
  davet istatistikleri (kaç kişi davet etti / kaçı aktif), günlük bonus butonu,
  engellenenler listesi, bildirim ayarları, çıkış.

### 4.2 Birebir görüntülü eşleşme (Azar modu)
- Ana ekran: kendi kamera önizlemesi + çevrimiçi sayacı + filtre çipleri
  (cinsiyet — VIP kilidi arkasında; bölge; çeviri dili — henüz kozmetik).
- "Görüntülü" butonu → kuyruk → sunucu uyumlu iki kişiyi eşler (cinsiyet tercihi
  karşılıklı kontrol edilir, aynı kullanıcının iki soketi eşleşmez).
- Eşleşince **2.2 saniyelik tanıtım kartı**: isim, ülke bayrağı (IP'den sunucu tespit
  eder), cinsiyet — sonra görüntü akar.
- Görüşme içi araçlar: mikrofon aç/kapa · kamera çevir · **beğeni** (karşılıklı olursa
  arkadaşlık) · **mini oyunlar** · **hediye gönder** (elmas harcar, alıcının ekranında
  hediye yağmuru animasyonu — Supabase Realtime ile anlık) · yazılı chat + emoji
  patlatma (P2P data channel) · DM'e geç · **Sonraki** (yeni eşleşme) · kapat ·
  şikayet et / engelle.
- **Mini oyunlar** (data channel üzerinden P2P, davet-kabul akışıyla): XOX,
  Adam Asmaca, Doğruluk/Cesaret. Karşı taraf davet gönderince panel otomatik açılır.

### 4.3 Birebir sesli eşleşme (BlindID modu)
- "Sesli" butonu → önce **konu seçimi**: 🎲 Rastgele · 👋 Tanışalım · 💭 Dertleş ·
  🤫 İtiraf Et · 🎵 Müzik · 🇬🇧 English.
- Eşleştirme kuralı: aynı konuyu seçenler eşleşir; "Rastgele" herkesle eşleşebilir
  (küçük havuzda bekleme süresini kısaltmak için). Eşleşmede geçerli konu her iki
  tarafa bildirilir ve ekranda `# Müzik` rozeti olarak görünür.
- Sesli aramanın **kendine ait ekranı** var: gece mavisi/turkuaz ambiyans (görüntülü
  ekranın pembe kimliğinden bilinçli olarak farklı), nabız halkalı büyük avatar,
  "🎭 Anonim sesli sohbet" vurgusu, süre sayacı.
- Kamera hiç açılmaz (getUserMedia yalnızca mikrofon). Diğer tüm in-call araçlar
  (beğeni, oyun, hediye, DM, sonraki) aynen çalışır.

### 4.4 Sesli grup odaları (Clubhouse tarzı)
- Alt barda ayrı **Odalar** sekmesi. Oda listesi **yatay kaydırmalı kart destesi**
  (BlindID görünümü): her oda canlı renkli büyük bir kart; kartta oda adı, `# konu`
  rozeti, doluluk (örn 3/10), **2×2 üye önizleme ızgarası** (ilk 4 üyenin avatarı +
  adı; boş slotlar "+ Sohbete Katıl" olarak tıklanabilir; 4'ten kalabalıksa "+N"),
  altta mavi **Katıl** butonu. Üstte toplam oda/kişi sayacı.
- **Oda kurma**: ad (60 karakter) + konu seçimi (Sohbet, Müzik, Oyun, Dertleşme,
  İtiraf, English).
- **Ses mimarisi**: full-mesh WebRTC (herkes herkese ses bağlantısı) — bu yüzden oda
  tavanı **10 kişi**. SFU yok (bilinen ölçek sınırı).
- **Roller**: kurucu (👑) açık mikrofonla başlar; katılanlar **susturulmuş (dinleyici)**
  başlar, istediklerinde "Söz al" ile mikrofonlarını açar. Kurucu ayrılırsa odadaki en
  eski üyeye devir. Oda boşalınca silinir.
- **Oda süresi**: kurulunca **3 dk** (kurucu VIP ise **7 dk**) geri sayım. Sayaç
  başlıkta; son 60 saniyede kırmızı. Süre dolunca sunucu odayı kapatır, herkes listeye
  döner. **Uzatma**: herhangi bir üye "+3 dk" uzatabilir — ya çarktan kazanılan
  **süre kartı** ile ya da **20 elmas** harcayarak. Tavan: mevcut andan en fazla
  30 dk ileri. Uzatınca odadaki herkese "X odayı 3 dk uzattı!" bildirimi düşer.
- **Üye kartları**: 2 sütunlu büyük avatar kartları; konuşan (mikrofonu açık) üyede
  yeşil parlayan çerçeve; kurucuda 👑, platform admini odadaysa kırmızı **ADMIN**
  rozeti. Kendi kartına dokunmak mikrofonu açar/kapar.
- **Üye popup'ı** (herhangi bir üyeye dokununca): Beğen & Arkadaş ol · Şikayet et ·
  (kurucuysa ek olarak) Sustur · Odadan At.
- **Oda sohbeti**: ekranı kaplamaz — alt dock'taki "Sohbet" butonu okunmamış sayacı
  gösterir, basınca bottom sheet açılır (mesaj listesi + yazma alanı). Mesajlar WS
  broadcast, oda kapanınca kaybolur (kalıcı değil).
- **Arkadaş daveti**: dock'taki "Davet" → arkadaş listesi → "Davet et" → arkadaşa
  bildirim gider, bildirimdeki **Katıl** butonu doğrudan odaya sokar. Sunucu kuralları:
  yalnızca karşılıklı arkadaşlar davet edilebilir + aynı kişiye 2 dakikada 1 davet.
- Kısıtlar: oda listesinde arama/filtre yok; oda şifresi/özel oda yok; el kaldırma
  yok (herkes kendi kendine söz alabiliyor).

### 4.5 Arkadaşlık ve beğeni
- Beğeni tek yönlü; **karşılıklı beğeni = arkadaşlık** (eşleşme sırasında, odada veya
  DM üzerinden beğenilebilir).
- **Arkadaş limiti: 20** (herkes için; DB trigger'ı limiti dolduran tarafın
  arkadaşlığını tamamlayacak beğeniyi reddeder). Limit dolunca kullanıcıya
  "Arkadaş listen dolu (20/20) — VIP yakında 👑" mesajı gösterilir (VIP'te limitin
  kalkması planlı).
- Trust score: 0-100 arası güven puanı (rapor/aktivite bazlı), profilde rozet.

### 4.6 Mesajlaşma (DM)
- Arkadaşlar/eşleşilenler ile kalıcı yazılı sohbet (Supabase; Realtime ile anlık).
- Sohbetler sekmesi: konuşma listesi, okunmamış sayaçları; uygulama içi global toast
  ("💬 Yeni mesaj: ...").
- **Fotoğraf gönderme**: DM'de foto paylaşılabilir. Fotoğraf **görüntülendikten sonra
  otomatik silinir** (Snapchat mantığı, depolama da temizlenir); görüntüleyicide ekran
  görüntüsü caydırma önlemleri; gönderirken "karşı taraf kaydedebilir" uyarısı.
- Misafir kullanıcılarla DM başlatılamaz.

### 4.7 Ekonomi (elmas/coin)
- **Kazanma yolları** (tümü gerçek, DB'de işliyor):
  - Hoş geldin bonusu: **+100** (ilk profil oluşturulunca, tek sefer)
  - Günlük bonus: **5 + seri×5** (1. gün 10, 2. gün 15… tavan 100) — seri kırılırsa başa döner
  - Davet (referral): davet eden **+50**, edilen **+25**
  - **Şans çarkı** (aşağıda)
- **Harcama yolları**: hediye gönderme (Gül 9 · Kalp 19 · Yıldız 29 · Taç 99 ·
  Roket 149 · Yüzük 299 elmas) · oda süre uzatma (20 elmas).
- Bakiye `coin_transactions` audit kaydından trigger'la senkronize edilir (her hareket
  loglu, negatife düşemez). Yetersiz bakiyede kullanıcı mağazaya yönlendirilir.
- **Mağaza**: coin paketleri DB'den gelir (100/₺29 · 550+50/₺99 · 1200+200/₺199 ·
  3000+750/₺449) — **satın alma butonu henüz ödeme sistemine bağlı değil**.

### 4.8 Şans Çarkı
- Ana ekran başlığındaki 🎡 buton; **günde 1 ücretsiz çevirme** (gün UTC bazlı).
- Ödüller ve olasılıklar tamamen **admin panelinden yönetilir** (bkz. 5.9). Varsayılan
  dağılım: Boş %35 · 10 elmas %30 · 25 elmas %15 · 50 elmas %5 · süre kartı %13 ·
  1 ay VIP %2.
- **Oran gizliliği üç katmanlı**: (1) ödül tablosunu RLS gereği yalnızca admin
  okuyabilir; (2) kullanıcıya giden RPC yalnızca etiket+emoji döner, ağırlık asla;
  (3) çark ekranında tüm dilimler **eşit boyutta** çizilir. Çekiliş sunucuda (Postgres
  fonksiyonu) yapılır; istemci yalnızca sonucu animasyonla gösterir → istemci
  manipülasyonu imkânsız.
- Ödül türleri: boş · elmas (miktar serbest) · oda süre kartı (envantere eklenir) ·
  VIP (gün sayısı serbest). Her çevirme loglanır (kim, ne, ne zaman, hangi ödül satırı).

### 4.9 Bildirimler
- Uygulama içi bildirim merkezi: beğeni, eşleşme, mesaj, hediye, coin, VIP, sistem,
  admin duyuruları, **oda daveti** (Katıl aksiyonuyla). Realtime + okundu yönetimi.
- Admin duyuruları herkese yayınlanabilir.
- **Push bildirimi (FCM) YOK** — uygulama kapalıyken kullanıcıya ulaşma imkânı yok
  (bilinen kritik eksik).

---

## 5. Adminin / Moderatörün Yapabildikleri

Admin paneli uygulama içinde ayrı ekran (rol kontrolü ile), 11 sekme:

1. **PANO** — canlı istatistikler: çevrimiçi kullanıcı, aktif eşleşme/kuyruk, günlük
   kayıt/aktivite grafikleri (sinyal sunucusu periyodik olarak `live_stats` tablosuna yazar).
2. **GELİR** — coin hareketleri üzerinden günlük gelir/harcama dökümü (grafikli).
3. **RAPORLAR** — kullanıcı şikayetleri kuyruğu: şikayet nedeni, notu, hedef kullanıcı;
   inceleme/karar durumu (pending → resolved).
4. **KULLANICILAR** — arama (nickname), listeleme; kullanıcı detayında: profil düzenleme
   (nickname dahil — admin muafiyeti), rol atama (user/moderator/admin), coin
   grant/eksiltme, VIP verme/alma, ban.
5. **YASAKLAR** — aktif banlar; süreli/süresiz ban, sebep; süre dolunca otomatik açılır.
   Sunucu tarafı ek koruma: **ban kaçağı tespiti** — banlı hesabın IP'si veya cihaz
   parmak izi (UA+ekran+timezone+dil SHA-256) yeni hesapla eşleşirse bağlantı reddedilir.
6. **DUYURULAR** — tüm kullanıcılara bildirim yayınlama.
7. **HEDİYELER** — hediye kataloğu CRUD (emoji, ad, maliyet, sıra, aktif/pasif).
8. **PAKETLER** — coin paketi CRUD (fiyat metni, bonus, popüler rozeti).
9. **ÇARK** — ödül CRUD: etiket, emoji, tür (boş/elmas/süre kartı/VIP gün), miktar,
   **ağırlık**, sıra, aktif/pasif. Her satırda hesaplanmış gerçek yüzde; bugünkü
   çevirme sayısı. Değişiklikler anında geçerli (uygulama güncellemesi gerekmez).
10. **FOTOĞRAFLAR** — DM fotoğraflarının moderasyon görünümü.
11. **AUDIT** — tüm admin eylemlerinin değiştirilemez logu (kim, ne, kime, ne zaman).

Ek admin görünürlükleri: admin odalara girince ADMIN rozetiyle görünür; sunucu
sağlık endpoint'i (`/health`) anlık peer/kuyruk/oda sayısı verir.

---

## 6. Güvenlik ve Kötüye Kullanım Önlemleri

- **Auth**: Supabase JWT; sinyal sunucusu her bağlantıda doğrular (JWKS/HS256).
- **RLS**: tüm tablolarda satır seviyesi güvenlik; hassas işlemler security definer
  RPC'lerle (ör. hediye gönderme atomik: bakiye kontrol + düş + logla).
- **Sunucu tarafı yaptırımlar**: banlı kullanıcı kuyruğa/odaya giremez; ban kaçağı
  (IP/cihaz parmak izi) bağlantıda reddedilir; nickname sunucu dayatmalı; oda süre
  uzatma harcaması yalnızca service-role RPC ile (istemci fonksiyonu çağıramaz).
- **İçerik**: şikayet sistemi (eşleşmede + odada), engelleme (bir daha eşleşmez),
  foto otomatik imha + ekran görüntüsü caydırma.
- **Ekonomi**: tüm coin hareketleri audit trail'de; çark sonucu sunucuda üretilir;
  arkadaş/nickname/çark limitleri DB trigger'larıyla (istemci atlatamaz).
- **Eksikler** (bilinçli, aşağıda da listeli): 18+ yaş kapısı yok, NSFW görüntü
  tespiti yok, chat kelime filtresi yok, otomatik ban eşiği yok, selfie doğrulama yok.

---

## 7. Veritabanı Şeması (19 tablo, özet)

`profiles` (kimlik+rol+ban+coins+time_cards+nickname_changes+streak+presence) ·
`sessions` (eşleşme kayıtları) · `likes` (beğeni; karşılıklı=arkadaş) · `blocks` ·
`bans` · `reports` · `messages` (DM) · `chat_photos` (otomatik imhalı) ·
`notifications` (payload jsonb; room_invite dahil) · `gifts` (katalog) ·
`gift_transactions` · `coin_packs` · `coin_transactions` (audit; bakiye trigger'ı) ·
`vip_subscriptions` · `wheel_prizes` (admin-only RLS) · `wheel_spins` (log) ·
`announcements` · `audit_logs` · `live_stats`.

Önemli RPC'ler: `change_nickname` (2 hak) · `spin_wheel` (günlük+ağırlıklı) ·
`wheel_prizes_public` (oransız liste) · `use_room_extension` (kart/elmas düş;
service-role-only) · `invite_to_room` (arkadaş+rate-limit) · `claim_daily_bonus` ·
`send_gift` (atomik) · `get_signaling_profile` (sunucu için rol+vip+nick+avatar) ·
`is_vip` · `check_ban_evasion` · `my_friends` · `friend_count` · admin grant fonksiyonları.

---

## 8. Sinyal Protokolü (WebSocket, JSON)

**İstemci→Sunucu**: `hello` (isim/cinsiyet/tercih/mod/konu/deviceFp/token) ·
`enqueue` (mod+konu) · `signal` (SDP/ICE relay) · `next` · `leave` ·
`room_create` · `room_join` · `room_leave` · `room_list` · `room_signal` ·
`room_chat` · `room_state` (kendi mute durumu) · `room_kick` · `room_mute` (kurucu) ·
`room_extend` (kart/elmas).

**Sunucu→İstemci**: `welcome` (selfId + ICE sunucuları) · `searching` · `matched`
(peer bilgisi + polite bayrağı + mod + konu) · `signal` · `peer_left` ·
`room_joined` (oda+üyeler+expiresAt) · `room_peer_joined/left` · `room_list`
(önizlemeli) · `room_signal` · `room_chat` · `room_member_state` ·
`room_extended` · `room_expired` · `room_kicked` · `room_force_muted` · `error` (kodlu).

WebRTC: perfect-negotiation deseni (polite/impolite), oda içinde yeni katılan herkese
offer açar (deterministik, glare yok).

---

## 9. Bilinen Eksikler / Teknik Borç / Riskler

**Ürün tarafı:**
1. **Push bildirimi yok** (FCM) — uygulama kapanınca kullanıcıyı geri çağıran hiçbir şey yok.
2. **Ödeme yok** — coin/VIP satın alınamıyor (Play Billing / Stripe entegre değil).
3. Birebir aramada **süre limiti + karşılıklı beğeniyle uzatma mekaniği yok**
   (BlindID'nin imza mekaniği; odalarda var, birebirde yok — planlı).
4. "İkinci şans" (son eşleşilene geri dönme) yok.
5. 18+ yaş kapısı, NSFW tespiti, kelime filtresi, rapor-eşiği otomasyonu,
   selfie doğrulama yok (store onayı ve kadın kullanıcı güvenliği için kritik).
6. Ülke/bölge ve çeviri dili filtreleri UI'da var ama **sunucuda uygulanmıyor** (kozmetik).
7. Analitik (PostHog vb.) ve hata takibi (Sentry) yok — kullanım verisi toplanmıyor.
8. iOS build hiç denenmedi; Android store'a çıkılmadı; çoklu dil (i18n) yok.

**Teknik tarafı:**
9. TURN = ücretsiz OpenRelay (best-effort) — NAT arkasındaki kullanıcılarda (%15-20)
   arama kalitesi/kurulumu riskli. Kendi coturn'umuz kurulmalı.
10. Odalar full-mesh → 10 kişi tavanı; büyümek için SFU (LiveKit/mediasoup) gerekir.
11. Sinyal sunucusu tek instance + in-memory state → restart odaları düşürür,
    yatay ölçekleme yok (Redis/pub-sub gerekir).
12. Oda sohbeti ve oda geçmişi kalıcı değil (bilinçli MVP tercihi).
13. E2E/entegrasyon test kapsamı dar (sunucu smoke testleri var, Flutter widget testi yok).
14. DiceBear avatarları dış API'ye bağımlı (çökerse monogram fallback çalışır).

---

## 10. Düşünülen Yol Haritası (henüz yapılmadı)

Kısa vade: birebir sesli aramada süre limiti + karşılıklı istekle ücretsiz uzatma /
tek taraf isterse elmasla · İkinci Şans · FCM push · analitik+Sentry · güvenlik paketi
(18+, karantina havuzu: düşük trust birbirine eşleşir, kelime filtresi) · buz kırıcı
soru kartları · ülke filtresini gerçek yapmak.

Orta vade: VIP satışa açma (cinsiyet filtresi, sınırsız arkadaş, 7dk oda, 2. çark hakkı,
"beni kim beğendi", reklamsız) + Play Billing · ödüllü reklam · günlük görevler ·
XP/seviye · oda içi herkese görünür hediye · planlı odalar · selfie doğrulama rozeti ·
davet linki (web deep link) · çarka pity sistemi + elmasla ekstra çevirme · coturn.

Uzun vade: SFU ile büyük odalar + el kaldırma/sahne · yayıncı ekonomisi (hediye gelir
paylaşımı) · iOS · çoklu dil / yurt dışı.

---

## 11. Geri Bildirim İstenen Konular

Bu dokümanı okuyan asistandan şunlar hakkında görüş bekliyoruz:

1. Ürün konumlandırması (Azar × BlindID melezi) mantıklı mı; hangi tarafa ağırlık verilmeli?
2. Eksik/zayıf gördüğün özellikler neler; yol haritası önceliklendirmesi doğru mu?
3. Ekonomi dengesi (bonus miktarları, hediye fiyatları, çark dağılımı, 20 arkadaş limiti,
   oda süre/uzatma fiyatı) hakkında ne düşünüyorsun?
4. Retention için ilk 3 hamle ne olmalı?
5. Güvenlik/moderasyon eksiklerinden hangileri lansman engelleyicidir?
6. Mimari riskler (mesh, tek sunucu, ücretsiz TURN) hangi kullanıcı sayısında patlar;
   geçiş sıralaması ne olmalı?
7. Google Play onayı açısından riskli gördüğün noktalar?
8. Bu dokümanda anlatılmayan ama sorulması gereken sorular neler?
