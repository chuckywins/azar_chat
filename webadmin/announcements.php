<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  if ($act === 'create' && trim($_POST['title'] ?? '') !== '') {
    sb_post('/rest/v1/announcements', [
      'title' => trim($_POST['title']),
      'body'  => trim($_POST['body'] ?? '') ?: null,
      'active' => true,
      'created_by' => $_SESSION['uid'],
    ]);
    audit('create_announcement', null, ['title' => trim($_POST['title'])]);
    flash('Duyuru yayınlandı');
  } elseif ($act === 'toggle' && !empty($_POST['id'])) {
    sb_patch('/rest/v1/announcements?id=eq.' . urlencode($_POST['id']),
             ['active' => ($_POST['to'] ?? '') === '1']);
    flash('Duyuru güncellendi');
  } elseif ($act === 'delete' && !empty($_POST['id'])) {
    sb_delete('/rest/v1/announcements?id=eq.' . urlencode($_POST['id']));
    flash('Duyuru silindi');
  }
  header('Location: announcements.php');
  exit;
}

$rows = sb_get('/rest/v1/announcements?select=*&order=created_at.desc&limit=100')['data'] ?? [];

layout_top('Duyurular', 'announcements');
?>
<div class="card">
  <h3>Yeni duyuru</h3>
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="create">
    <input type="text" name="title" placeholder="Başlık" required style="width:260px">
    <input type="text" name="body" placeholder="Metin (opsiyonel)" style="flex:1;min-width:220px">
    <button class="btn sm" type="submit">Yayınla</button>
  </form>
</div>

<div class="card" style="margin-top:14px;padding:6px 10px">
<table class="tbl">
  <tr><th>Başlık</th><th>Metin</th><th>Durum</th><th>Zaman</th><th></th></tr>
  <?php foreach ($rows as $a): ?>
  <tr>
    <td><b><?= h($a['title']) ?></b></td>
    <td><small><?= h(mb_substr($a['body'] ?? '—', 0, 70)) ?></small></td>
    <td><?= $a['active'] ? badge('aktif', 'ok') : badge('pasif', 'muted') ?></td>
    <td><small><?= rel_time($a['created_at']) ?></small></td>
    <td><div class="row">
      <form method="post"><input type="hidden" name="act" value="toggle"><input type="hidden" name="id" value="<?= h($a['id']) ?>"><input type="hidden" name="to" value="<?= $a['active'] ? '0' : '1' ?>">
        <button class="btn ghost sm"><?= $a['active'] ? 'Pasifleştir' : 'Aktifleştir' ?></button></form>
      <form method="post" onsubmit="return confirm('Silinsin mi?')"><input type="hidden" name="act" value="delete"><input type="hidden" name="id" value="<?= h($a['id']) ?>">
        <button class="btn danger sm">Sil</button></form>
    </div></td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
