<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  if ($act === 'upsert') {
    $id = trim($_POST['pid'] ?? '');
    if ($id !== '') {
      sb('POST', '/rest/v1/coin_packs?on_conflict=id', [
        'id' => $id,
        'coins' => max(0, (int)($_POST['coins'] ?? 0)),
        'price_text' => trim($_POST['price'] ?? ''),
        'bonus_text' => trim($_POST['bonus'] ?? '') ?: null,
        'sort_order' => (int)($_POST['sort'] ?? 0),
        'popular' => isset($_POST['popular']),
        'active' => isset($_POST['active']),
      ], ['Prefer: resolution=merge-duplicates,return=representation']);
      audit('upsert_pack', null, ['pack' => $id]);
      flash('Paket kaydedildi');
    }
  } elseif ($act === 'delete' && !empty($_POST['pid'])) {
    sb_delete('/rest/v1/coin_packs?id=eq.' . urlencode($_POST['pid']));
    audit('delete_pack', null, ['pack' => $_POST['pid']]);
    flash('Paket silindi');
  }
  header('Location: packs.php');
  exit;
}

$rows = sb_get('/rest/v1/coin_packs?select=*&order=sort_order.asc&limit=50')['data'] ?? [];

layout_top('Coin Paketleri', 'packs');
?>
<div class="card">
  <h3>Paket ekle / güncelle</h3>
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="upsert">
    <input name="pid" placeholder="id (p1)" required style="width:90px">
    <input name="coins" type="number" placeholder="Elmas" style="width:100px">
    <input name="price" placeholder="₺29" style="width:90px">
    <input name="bonus" placeholder="+50 (ops.)" style="width:100px">
    <input name="sort" type="number" placeholder="Sıra" style="width:80px">
    <label><input type="checkbox" name="popular"> popüler</label>
    <label><input type="checkbox" name="active" checked> aktif</label>
    <button class="btn sm">Kaydet</button>
  </form>
</div>

<div class="card" style="margin-top:14px;padding:6px 10px">
<table class="tbl">
  <tr><th>ID</th><th>Elmas</th><th>Fiyat</th><th>Bonus</th><th>Durum</th><th></th></tr>
  <?php foreach ($rows as $p): ?>
  <tr>
    <td class="mono"><?= h($p['id']) ?></td>
    <td><b><?= (int)$p['coins'] ?></b></td>
    <td><?= h($p['price_text']) ?></td>
    <td><?= h($p['bonus_text'] ?? '—') ?><?= $p['popular'] ? ' ' . badge('popüler', 'accent') : '' ?></td>
    <td><?= $p['active'] ? badge('aktif', 'ok') : badge('pasif', 'muted') ?></td>
    <td>
      <form method="post" onsubmit="return confirm('Silinsin mi?')"><input type="hidden" name="act" value="delete"><input type="hidden" name="pid" value="<?= h($p['id']) ?>">
        <button class="btn danger sm">Sil</button></form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
