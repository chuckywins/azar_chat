<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  if ($act === 'upsert') {
    $id = trim($_POST['gid'] ?? '');
    if ($id !== '') {
      $body = [
        'id' => $id,
        'name' => trim($_POST['name'] ?? ''),
        'glyph' => trim($_POST['glyph'] ?? '🎁'),
        'cost' => max(0, (int)($_POST['cost'] ?? 0)),
        'sort_order' => (int)($_POST['sort'] ?? 0),
        'active' => isset($_POST['active']),
      ];
      sb('POST', '/rest/v1/gifts?on_conflict=id', $body, ['Prefer: resolution=merge-duplicates,return=representation']);
      audit('upsert_gift', null, ['gift' => $id]);
      flash('Hediye kaydedildi');
    }
  } elseif ($act === 'delete' && !empty($_POST['gid'])) {
    sb_delete('/rest/v1/gifts?id=eq.' . urlencode($_POST['gid']));
    audit('delete_gift', null, ['gift' => $_POST['gid']]);
    flash('Hediye silindi');
  }
  header('Location: gifts.php');
  exit;
}

$rows = sb_get('/rest/v1/gifts?select=*&order=sort_order.asc&limit=100')['data'] ?? [];

layout_top('Hediyeler', 'gifts');
?>
<div class="card">
  <h3>Hediye ekle / güncelle (aynı ID = güncelleme)</h3>
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="upsert">
    <input name="gid" placeholder="id (rose)" required style="width:110px">
    <input name="name" placeholder="İsim" required style="width:130px">
    <input name="glyph" placeholder="🎁" style="width:64px">
    <input name="cost" type="number" placeholder="Elmas" style="width:90px">
    <input name="sort" type="number" placeholder="Sıra" style="width:80px">
    <label><input type="checkbox" name="active" checked> aktif</label>
    <button class="btn sm">Kaydet</button>
  </form>
</div>

<div class="card" style="margin-top:14px;padding:6px 10px">
<table class="tbl">
  <tr><th></th><th>İsim</th><th>Elmas</th><th>Sıra</th><th>Durum</th><th></th></tr>
  <?php foreach ($rows as $g): ?>
  <tr>
    <td style="font-size:22px"><?= h($g['glyph']) ?></td>
    <td><b><?= h($g['name']) ?></b><div class="mono"><?= h($g['id']) ?></div></td>
    <td><b><?= (int)$g['cost'] ?></b></td>
    <td><?= (int)$g['sort_order'] ?></td>
    <td><?= $g['active'] ? badge('aktif', 'ok') : badge('pasif', 'muted') ?></td>
    <td>
      <form method="post" onsubmit="return confirm('Silinsin mi?')"><input type="hidden" name="act" value="delete"><input type="hidden" name="gid" value="<?= h($g['id']) ?>">
        <button class="btn danger sm">Sil</button></form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
