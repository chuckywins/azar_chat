<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['act'] ?? '') === 'unban') {
  $uid = $_POST['uid'] ?? '';
  if ($uid) {
    sb_patch('/rest/v1/profiles?id=eq.' . urlencode($uid), [
      'is_banned' => false, 'banned_until' => null, 'ban_reason' => null,
    ]);
    audit('unban_user', $uid);
    flash('Ban kaldırıldı');
  }
  header('Location: bans.php');
  exit;
}

$rows = sb_get('/rest/v1/profiles?is_banned=eq.true&select=id,nickname,ban_reason,banned_until,country,created_at&order=updated_at.desc&limit=200')['data'] ?? [];

layout_top('Yasaklar', 'bans');
?>
<div class="card" style="padding:6px 10px">
<table class="tbl">
  <tr><th>Kullanıcı</th><th>Sebep</th><th>Bitiş</th><th></th></tr>
  <?php if (!$rows): ?><tr><td colspan="4"><small>Aktif ban yok</small></td></tr><?php endif; ?>
  <?php foreach ($rows as $u): ?>
  <tr>
    <td><b><?= h($u['nickname'] ?? '—') ?></b><div class="mono"><?= h(substr($u['id'], 0, 13)) ?>… · <?= h($u['country'] ?? '?') ?></div></td>
    <td><small><?= h($u['ban_reason'] ?? '—') ?></small></td>
    <td><?= $u['banned_until'] ? badge(date('d.m.Y H:i', strtotime($u['banned_until'])), 'warn') : badge('SÜRESİZ', 'danger') ?></td>
    <td>
      <form method="post"><input type="hidden" name="uid" value="<?= h($u['id']) ?>">
        <button class="btn ok sm" name="act" value="unban">Banı kaldır</button></form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
