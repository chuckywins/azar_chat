# kerochat — Web Yönetim Paneli

Uygulamadan bağımsız, PHP tabanlı yönetim paneli (XAMPP/Apache + PHP 7.4+).
Adres: `http://localhost/azar_chat/webadmin/` (veya sunucuya kopyala).

## Kurulum (2 dakika)

1. `webadmin/config.local.php` oluştur (git'e girmez):

```php
<?php
define('SUPABASE_URL',         'https://XXXX.supabase.co');
define('SUPABASE_ANON_KEY',    'eyJ...anon...');
define('SUPABASE_SERVICE_KEY', 'eyJ...service_role...');   // GİZLİ — sadece sunucuda
define('SIGNALING_HEALTH_URL', 'https://ws.klslog.com/health');
```

2. Tarayıcıdan `login.php`'yi aç, **admin veya moderatör rollü** hesabının
   e-posta/şifresiyle gir. (Google-only hesap kullanıyorsan Supabase
   Authentication → Users'tan hesabına şifre tanımla.)

## Sayfalar

| Sayfa | İçerik |
|---|---|
| Pano | Çevrimiçi/kuyruk/oda canlı sayıları, kullanıcı-şikayet-VIP-çark özetleri, 14 günlük kayıt ve elmas grafikleri |
| Kullanıcılar | Arama, ban (süreli/süresiz), ban kaldırma, ± elmas, VIP verme, rol değiştirme (yalnız admin) |
| Şikayetler | Bekleyen/tümü; incelendi/yoksay/işlem yapıldı |
| Yasaklar | Aktif ban listesi + kaldırma |
| VIP | Aktif VIP listesi + iptal |
| Duyurular | Yayınla / pasifleştir / sil |
| Hediyeler & Paketler | Katalog CRUD |
| Çark | Ödül CRUD + ağırlık (gerçek % burada görünür) + günlük çevirme sayısı |
| Audit | Tüm admin eylemlerinin logu (panel eylemleri de loglanır) |

## Güvenlik notları

- `SERVICE_ROLE` anahtarı yalnızca PHP tarafında kalır, tarayıcıya gitmez.
- Giriş Supabase GoTrue üzerinden yapılır; oturum PHP session'dadır ve rol
  (`admin`/`moderator`) veritabanından doğrulanır.
- Rol değişikliği yalnızca `admin` rolüne açıktır; tüm eylemler `audit_logs`a yazılır.
- Canlıya alırken: HTTPS zorunlu yap, `webadmin/` dizinine ek olarak IP kısıtı
  veya HTTP Basic Auth (Apache `.htaccess`) eklemek iyi bir ikinci katmandır.
