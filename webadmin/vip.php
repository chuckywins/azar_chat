<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['act'] ?? '') === 'revoke') {
  $id = $_POST['id'] ?? '';
  if ($id) {
    sb_patch('/rest/v1/vip_subscriptions?id=eq.' . urlencode($id), ['active' => false]);
    audit('revoke_vip', $_POST['uid'] ?? null, ['sub_id' => $id]);
    flash('VIP iptal edildi');
  }
  header('Location: vip.php');
  exit;
}

$rows = sb_get('/rest/v1/vip_subscriptions?active=eq.true&select=id,user_id,tier,source,starts_at,expires_at&order=created_at.desc&limit=200')['data'] ?? [];
$ids = array_column($rows, 'user_id');
$names = [];
if ($ids) {
  $ps = sb_get('/rest/v1/profiles?id=in.(' . rawurlencode(implode(',', array_unique($ids))) . ')&select=id,nickname')['data'] ?? [];
  foreach ($ps as $p) $names[$p['id']] = $p['nickname'];
}

layout_top('VIP Üyeler', 'vip');
?>
<div class="card" style="padding:6px 10px">
<table class="tbl">
  <tr><th>Kullanıcı</th><th>Paket</th><th>Kaynak</th><th>Bitiş</th><th></th></tr>
  <?php if (!$rows): ?><tr><td colspan="5"><small>Aktif VIP yok</small></td></tr><?php endif; ?>
  <?php foreach ($rows as $v): ?>
  <tr>
    <td><b><?= h($names[$v['user_id']] ?? '—') ?></b><div class="mono"><?= h(substr($v['user_id'], 0, 13)) ?>…</div></td>
    <td><?= badge($v['tier'], 'vip') ?></td>
    <td><small><?= h($v['source']) ?></small></td>
    <td><small><?= $v['expires_at'] ? date('d.m.Y', strtotime($v['expires_at'])) : 'süresiz' ?></small></td>
    <td>
      <form method="post"><input type="hidden" name="id" value="<?= h($v['id']) ?>"><input type="hidden" name="uid" value="<?= h($v['user_id']) ?>">
        <button class="btn danger sm" name="act" value="revoke" onclick="return confirm('VIP iptal edilsin mi?')">İptal</button></form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
