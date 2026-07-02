<?php
/**
 * kerochat web admin — yapılandırma.
 *
 * GÜVENLİK: SERVICE_ROLE anahtarı yalnızca sunucu tarafında (bu PHP) yaşar,
 * tarayıcıya asla gitmez. Bu dosyayı web dışına taşımak istersen config.local.php
 * oluştur — varsa o yüklenir (git'e girmez).
 */

if (file_exists(__DIR__ . '/config.local.php')) {
  require __DIR__ . '/config.local.php';
}

// Supabase project (Project Settings → API)
if (!defined('SUPABASE_URL'))          define('SUPABASE_URL', 'https://YOUR-PROJECT.supabase.co');
if (!defined('SUPABASE_ANON_KEY'))     define('SUPABASE_ANON_KEY', 'YOUR_ANON_KEY');
if (!defined('SUPABASE_SERVICE_KEY'))  define('SUPABASE_SERVICE_KEY', 'YOUR_SERVICE_ROLE_KEY');

// Sinyal sunucusu health endpoint'i (canlı peer/oda sayıları için)
if (!defined('SIGNALING_HEALTH_URL'))  define('SIGNALING_HEALTH_URL', 'https://ws.klslog.com/health');

session_name('kerochat_admin');
session_start();
