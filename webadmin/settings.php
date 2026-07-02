<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';

  if ($act === 'save_settings' && is_array($_POST['s'] ?? null)) {
    $n = 0;
    foreach ($_POST['s'] as $key => $val) {
      $val = trim((string)$val);
      if ($val === '' || !preg_match('/^\d+$/', $val)) continue;
      sb_patch('/rest/v1/app_settings?key=eq.' . urlencode($key), ['value' => $val]);
      $n++;
    }
    audit('update_settings', null, ['count' => $n]);
    $r = signal_api('POST', '/admin/refresh');
    flash("$n ayar kaydedildi" . ($r['ok'] ? ' ve sunucuya anında uygulandı ⚡' : ' (sunucu 60 sn içinde alır)'));
  }

  elseif ($act === 'topic_add' && trim($_POST['title'] ?? '') !== '') {
    sb_post('/rest/v1/system_room_topics', [
      'title' => trim($_POST['title']),
      'topic' => trim($_POST['topic'] ?? 'Sohbet') ?: 'Sohbet',
      'sort'  => (int)($_POST['sort'] ?? 0),
    ]);
    audit('topic_add', null, ['title' => trim($_POST['title'])]);
    signal_api('POST', '/admin/refresh');
    flash('Oda konusu eklendi ve sunucuya uygulandı');
  }

  elseif ($act === 'topic_toggle' && !empty($_POST['id'])) {
    sb_patch('/rest/v1/system_room_topics?id=eq.' . urlencode($_POST['id']),
             ['active' => ($_POST['to'] ?? '') === '1']);
    signal_api('POST', '/admin/refresh');
    flash('Konu güncellendi');
  }

  elseif ($act === 'topic_delete' && !empty($_POST['id'])) {
    sb_delete('/rest/v1/system_room_topics?id=eq.' . urlencode($_POST['id']));
    signal_api('POST', '/admin/refresh');
    flash('Konu silindi');
  }

  elseif ($act === 'push_now') {
    $r = signal_api('POST', '/admin/refresh');
    flash($r['ok'] ? 'Sunucu ayarları yeniden yükledi ⚡' : 'Sunucuya ulaşılamadı (' . $r['code'] . ')');
  }

  header('Location: settings.php');
  exit;
}

$settings = sb_get('/rest/v1/app_settings?select=*&order=key.asc')['data'] ?? [];
$topics   = sb_get('/rest/v1/system_room_topics?select=*&order=sort.asc')['data'] ?? [];
$live     = signal_api('GET', '/admin/state');
$liveCfg  = $live['data']['settings'] ?? null;

/* gruplu, okunur etiketler */
$groups = [
  'Birebir Sesli Eşleşme' => [
    'voice_call_sec'        => 'Görüşme süresi (sn)',
    'voice_ext_sec'         => 'Uzatma — normal üye (sn)',
    'voice_ext_vip_sec'     => 'Uzatma — VIP (sn)',
    'daily_free_extensions' => 'Günlük ücretsiz uzatma hakkı',
  ],
  'Odalar' => [
    'system_room_sec'      => 'Sistem odası süresi (sn)',
    'system_room_min_open' => 'Minimum açık sistem odası',
    'system_room_cap_min'  => 'Sistem odası min. kapasite',
    'system_room_cap_max'  => 'Sistem odası max. kapasite',
    'room_vip_sec'         => 'VIP odası süresi (sn)',
    'room_ext_sec'         => 'Oda uzatma miktarı (sn)',
    'room_ext_coin_cost'   => 'Oda uzatma bedeli (elmas)',
    'room_max_ahead_sec'   => 'Süre üst sınırı (sn)',
  ],
  'Ekonomi & Limitler' => [
    'filter_match_cost'    => 'Filtreli eşleşme bedeli (elmas)',
    'friend_limit'         => 'Maksimum arkadaş sayısı',
    'nickname_max_changes' => 'Kullanıcı adı değiştirme hakkı',
  ],
  'Kazanç (Referans & Reklam)' => [
    'referral_bonus_inviter'  => 'Davet eden: kayıt başına elmas',
    'referral_bonus_referred' => 'Davetle gelen: elmas',
    'ad_daily_limit'          => 'Günlük reklam izleme hakkı',
    'ad_reward_coins'         => 'Reklam başına elmas',
  ],
];
$byKey = [];
foreach ($settings as $s) $byKey[$s['key']] = $s;

layout_top('Ayarlar', 'settings');
?>
<div class="formrow">
  <?php if ($liveCfg): ?>
    <?= badge('sunucu bağlı — canlı değerler yüklü', 'ok') ?>
  <?php else: ?>
    <?= badge('sunucuya ulaşılamadı — değişiklikler 60 sn içinde işlenir', 'warn') ?>
  <?php endif; ?>
  <span class="spacer"></span>
  <form method="post"><input type="hidden" name="act" value="push_now">
    <button class="btn ghost sm">⚡ Sunucuya şimdi uygula</button></form>
</div>

<form method="post">
  <input type="hidden" name="act" value="save_settings">
  <?php foreach ($groups as $gname => $keys): ?>
  <div class="section-title"><?= h($gname) ?></div>
  <div class="card">
    <table class="tbl">
      <?php foreach ($keys as $key => $label): $row = $byKey[$key] ?? null; ?>
      <tr>
        <td style="width:340px"><b><?= h($label) ?></b>
          <div class="mono"><?= h($key) ?></div></td>
        <td style="width:140px">
          <input type="text" name="s[<?= h($key) ?>]"
                 value="<?= h($row['value'] ?? '') ?>" style="width:110px"
                 <?= $row ? '' : 'placeholder="şema v12 gerekli" disabled' ?>>
        </td>
        <td><small><?= $row ? 'güncelleme: ' . rel_time($row['updated_at']) : '—' ?></small></td>
      </tr>
      <?php endforeach; ?>
    </table>
  </div>
  <?php endforeach; ?>
  <div style="margin-top:14px"><button class="btn" type="submit">Tümünü kaydet ve uygula</button></div>
</form>

<div class="section-title">Sistem Odası Konuları <small>(otomatik açılan odaların ad havuzu)</small></div>
<div class="card">
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="topic_add">
    <input name="title" placeholder="Oda adı (örn: Gece Kuşları)" required style="width:220px">
    <input name="topic" placeholder="Konu etiketi (örn: Sohbet)" style="width:170px">
    <input name="sort" type="number" placeholder="Sıra" style="width:80px">
    <button class="btn sm">Ekle</button>
  </form>
  <table class="tbl">
    <tr><th>Oda adı</th><th>Konu</th><th>Sıra</th><th>Durum</th><th></th></tr>
    <?php foreach ($topics as $t): ?>
    <tr>
      <td><b><?= h($t['title']) ?></b></td>
      <td><?= badge($t['topic'], 'accent') ?></td>
      <td><?= (int)$t['sort'] ?></td>
      <td><?= $t['active'] ? badge('aktif', 'ok') : badge('pasif', 'muted') ?></td>
      <td><div class="row">
        <form method="post"><input type="hidden" name="act" value="topic_toggle"><input type="hidden" name="id" value="<?= h($t['id']) ?>"><input type="hidden" name="to" value="<?= $t['active'] ? '0' : '1' ?>">
          <button class="btn ghost sm"><?= $t['active'] ? 'Pasifleştir' : 'Aktifleştir' ?></button></form>
        <form method="post" onsubmit="return confirm('Silinsin mi?')"><input type="hidden" name="act" value="topic_delete"><input type="hidden" name="id" value="<?= h($t['id']) ?>">
          <button class="btn danger sm">Sil</button></form>
      </div></td>
    </tr>
    <?php endforeach; ?>
  </table>
</div>
<?php layout_bottom(); ?>
