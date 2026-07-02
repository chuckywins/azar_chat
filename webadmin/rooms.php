<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  if ($act === 'create') {
    $mins = max(0, (int)($_POST['mins'] ?? 0));
    $r = signal_api('POST', '/admin/room', [
      'title' => trim($_POST['title'] ?? ''),
      'topic' => trim($_POST['topic'] ?? ''),
      'cap'   => (int)($_POST['cap'] ?? 4),
      'lifetimeSec' => $mins * 60,
    ]);
    audit('room_create_manual', null, ['title' => trim($_POST['title'] ?? ''), 'mins' => $mins]);
    flash($r['ok'] ? 'Oda açıldı 🎙' : 'Oda açılamadı (' . $r['code'] . ')');
  } elseif ($act === 'close' && !empty($_POST['id'])) {
    $r = signal_api('POST', '/admin/room/close', ['id' => $_POST['id']]);
    audit('room_close_manual', null, ['room' => $_POST['id']]);
    flash($r['ok'] ? 'Oda kapatıldı' : 'Kapatılamadı (' . $r['code'] . ')');
  }
  header('Location: rooms.php');
  exit;
}

$state = signal_api('GET', '/admin/state');
$ok    = $state['ok'];
$rooms = $state['data']['rooms'] ?? [];
usort($rooms, fn($a, $b) => ($b['count'] <=> $a['count']) ?: strcmp($a['title'], $b['title']));

layout_top('Odalar (Canlı)', 'rooms');

function room_kind(array $r): string {
  if (!empty($r['manual'])) return badge('MANUEL', 'accent');
  if (!empty($r['system'])) return badge('SİSTEM', 'muted');
  return badge('VIP KULLANICI', 'vip');
}
function remain(array $r): string {
  if (empty($r['expiresAt'])) return !empty($r['system']) && empty($r['manual']) && $r['count'] == 0
      ? 'ilk katılımda başlar' : 'süresiz';
  $s = (int)(($r['expiresAt'] / 1000) - time());
  if ($s <= 0) return 'doldu';
  return sprintf('%02d:%02d', intdiv($s, 60), $s % 60);
}
?>
<?php if (!$ok): ?>
  <div class="card"><b>⚠ Sinyal sunucusuna ulaşılamadı.</b><br>
  <small>Sunucunun güncel (admin API'li) sürümle çalıştığından emin ol: <code>bash /opt/azar_chat/infra/vps-update.sh</code></small></div>
<?php else: ?>

<div class="grid c4">
  <div class="card stat hot"><h3>Çevrimiçi soket</h3><div class="num"><?= (int)($state['data']['peers'] ?? 0) ?></div></div>
  <div class="card stat"><h3>Kuyruk</h3><div class="num"><?= (int)($state['data']['queue'] ?? 0) ?></div></div>
  <div class="card stat"><h3>Aktif oda</h3><div class="num"><?= count($rooms) ?></div></div>
  <div class="card stat"><h3>Odalardaki kişi</h3><div class="num"><?= array_sum(array_column($rooms, 'count')) ?></div></div>
</div>

<div class="card" style="margin-top:14px">
  <h3>Manuel oda aç</h3>
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="create">
    <input name="title" placeholder="Oda adı (örn: Cuma Buluşması)" required style="width:220px">
    <input name="topic" placeholder="Konu" style="width:130px">
    <input name="cap" type="number" min="2" max="10" value="4" style="width:90px" title="Kapasite (2-10)">
    <input name="mins" type="number" min="0" value="0" style="width:110px" title="Süre (dakika)">
    <small>süre 0 = süresiz</small>
    <button class="btn sm">Odayı aç</button>
  </form>
</div>

<div class="card" style="margin-top:14px;padding:6px 10px">
<table class="tbl">
  <tr><th>Oda</th><th>Tür</th><th>Doluluk</th><th>Kalan süre</th><th>Üyeler</th><th></th></tr>
  <?php if (!$rooms): ?><tr><td colspan="6"><small>Aktif oda yok</small></td></tr><?php endif; ?>
  <?php foreach ($rooms as $r): ?>
  <tr>
    <td><b><?= h($r['title']) ?></b>
      <?php if (!empty($r['topic'])): ?><div class="mono"># <?= h($r['topic']) ?> · <?= h($r['id']) ?></div><?php endif; ?></td>
    <td><?= room_kind($r) ?></td>
    <td><b><?= (int)$r['count'] ?></b> / <?= (int)$r['cap'] ?></td>
    <td><?= h(remain($r)) ?></td>
    <td><small><?= h(implode(', ', array_map(fn($m) => $m['name'] . ($m['muted'] ? ' 🔇' : ' 🎙'), $r['members'] ?? []))) ?: '—' ?></small></td>
    <td>
      <form method="post" onsubmit="return confirm('Oda kapatılsın mı? İçindekiler dışarı alınır.')">
        <input type="hidden" name="act" value="close"><input type="hidden" name="id" value="<?= h($r['id']) ?>">
        <button class="btn danger sm">Kapat</button></form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<div style="margin-top:10px"><a class="btn ghost sm" href="rooms.php">↻ Yenile</a></div>
<?php endif; ?>
<?php layout_bottom(); ?>
