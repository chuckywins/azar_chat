<?php
require_once __DIR__ . '/config.php';

/* ── Supabase REST (PostgREST) — service role, sunucu tarafı ─────────────── */

function sb(string $method, string $path, ?array $body = null, array $headers = []): array {
  $ch = curl_init(SUPABASE_URL . $path);
  $hdrs = array_merge([
    'apikey: ' . SUPABASE_SERVICE_KEY,
    'Authorization: Bearer ' . SUPABASE_SERVICE_KEY,
    'Content-Type: application/json',
    'Prefer: return=representation',
  ], $headers);
  curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST  => $method,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER     => $hdrs,
    CURLOPT_TIMEOUT        => 15,
  ]);
  if ($body !== null) curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
  $raw  = curl_exec($ch);
  $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  $json = json_decode($raw ?: 'null', true);
  return ['ok' => $code >= 200 && $code < 300, 'code' => $code, 'data' => $json, 'raw' => $raw];
}

function sb_get(string $path): array   { return sb('GET', $path); }
function sb_post(string $path, array $b): array { return sb('POST', $path, $b); }
function sb_patch(string $path, array $b): array { return sb('PATCH', $path, $b); }
function sb_delete(string $path): array { return sb('DELETE', $path); }
function sb_rpc(string $fn, array $args = []): array { return sb('POST', "/rest/v1/rpc/$fn", $args); }

/** Exact count without fetching rows. */
function sb_count(string $pathQuery): int {
  $ch = curl_init(SUPABASE_URL . $pathQuery);
  curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST  => 'HEAD',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_NOBODY         => true,
    CURLOPT_HEADER         => true,
    CURLOPT_TIMEOUT        => 10,
    CURLOPT_HTTPHEADER     => [
      'apikey: ' . SUPABASE_SERVICE_KEY,
      'Authorization: Bearer ' . SUPABASE_SERVICE_KEY,
      'Prefer: count=exact',
      'Range: 0-0',
    ],
  ]);
  $raw = curl_exec($ch) ?: '';
  curl_close($ch);
  if (preg_match('/content-range:\s*\S+\/(\d+)/i', $raw, $m)) return (int)$m[1];
  return 0;
}

/* ── Auth (GoTrue password grant + rol kontrolü) ─────────────────────────── */

function admin_login(string $email, string $password): ?string {
  $ch = curl_init(SUPABASE_URL . '/auth/v1/token?grant_type=password');
  curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 15,
    CURLOPT_HTTPHEADER => ['apikey: ' . SUPABASE_ANON_KEY, 'Content-Type: application/json'],
    CURLOPT_POSTFIELDS => json_encode(['email' => $email, 'password' => $password]),
  ]);
  $raw = curl_exec($ch);
  curl_close($ch);
  $j = json_decode($raw ?: 'null', true);
  $uid = $j['user']['id'] ?? null;
  if (!$uid) return 'E-posta veya şifre hatalı.';

  $p = sb_get('/rest/v1/profiles?id=eq.' . urlencode($uid) . '&select=id,nickname,role');
  $row = $p['data'][0] ?? null;
  if (!$row || !in_array($row['role'], ['admin', 'moderator'], true)) {
    return 'Bu hesabın yönetim yetkisi yok.';
  }
  $_SESSION['uid']  = $uid;
  $_SESSION['nick'] = $row['nickname'] ?? $email;
  $_SESSION['role'] = $row['role'];
  return null;
}

function require_admin(): void {
  if (empty($_SESSION['uid'])) {
    header('Location: login.php');
    exit;
  }
}

function is_full_admin(): bool { return ($_SESSION['role'] ?? '') === 'admin'; }

function audit(string $action, ?string $targetId = null, array $details = []): void {
  sb_post('/rest/v1/audit_logs', [
    'actor_id'  => $_SESSION['uid'] ?? null,
    'action'    => $action,
    'target_id' => $targetId,
    'details'   => (object)($details + ['via' => 'webadmin']),
    'ip'        => $_SERVER['REMOTE_ADDR'] ?? null,
  ]);
}

/* ── UI yardımcıları ─────────────────────────────────────────────────────── */

function h(?string $s): string { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); }

function flash(?string $msg = null): ?string {
  if ($msg !== null) { $_SESSION['flash'] = $msg; return null; }
  $m = $_SESSION['flash'] ?? null;
  unset($_SESSION['flash']);
  return $m;
}

function rel_time(?string $iso): string {
  if (!$iso) return '—';
  $t = strtotime($iso);
  $d = time() - $t;
  if ($d < 60) return 'az önce';
  if ($d < 3600) return floor($d / 60) . ' dk';
  if ($d < 86400) return floor($d / 3600) . ' sa';
  if ($d < 604800) return floor($d / 86400) . ' gün';
  return date('d.m.Y', $t);
}

function layout_top(string $title, string $active): void {
  $nick = h($_SESSION['nick'] ?? '');
  $role = h($_SESSION['role'] ?? '');
  $items = [
    ['index.php',         'dashboard',     '📊', 'Pano'],
    ['users.php',         'users',         '👥', 'Kullanıcılar'],
    ['reports.php',       'reports',       '🚩', 'Şikayetler'],
    ['bans.php',          'bans',          '⛔', 'Yasaklar'],
    ['vip.php',           'vip',           '👑', 'VIP'],
    ['announcements.php', 'announcements', '📣', 'Duyurular'],
    ['gifts.php',         'gifts',         '🎁', 'Hediyeler'],
    ['packs.php',         'packs',         '💎', 'Paketler'],
    ['wheel.php',         'wheel',         '🎡', 'Çark'],
    ['audit.php',         'audit',         '🧾', 'Audit'],
  ];
  echo '<!doctype html><html lang="tr"><head><meta charset="utf-8">';
  echo '<meta name="viewport" content="width=device-width,initial-scale=1">';
  echo '<meta name="robots" content="noindex,nofollow">';
  echo '<title>' . h($title) . ' — kerochat admin</title>';
  echo '<link rel="preconnect" href="https://fonts.googleapis.com">';
  echo '<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">';
  echo '<link rel="stylesheet" href="assets/style.css">';
  echo '<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.4/dist/chart.umd.min.js"></script>';
  echo '</head><body><div class="shell">';
  echo '<aside class="side"><div class="brand"><span class="logo">K</span><div><b>kerochat</b><small>yönetim paneli</small></div></div><nav>';
  foreach ($items as [$href, $key, $ico, $label]) {
    $cls = $key === $active ? 'on' : '';
    echo "<a class=\"$cls\" href=\"$href\"><span>$ico</span>$label</a>";
  }
  echo '</nav><div class="side-foot"><div class="me"><b>' . $nick . '</b><small>' . $role . '</small></div>';
  echo '<a class="btn ghost sm" href="logout.php">Çıkış</a></div></aside>';
  echo '<main class="main"><header class="top"><h1>' . h($title) . '</h1></header>';
  $f = flash();
  if ($f) echo '<div class="flash">' . h($f) . '</div>';
}

function layout_bottom(): void {
  echo '</main></div></body></html>';
}

function badge(string $text, string $tone = 'muted'): string {
  return '<span class="badge ' . h($tone) . '">' . h($text) . '</span>';
}
