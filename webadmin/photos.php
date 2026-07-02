<?php
require_once __DIR__ . '/lib.php';
require_admin();

const PHOTO_BUCKET = 'chat-photos';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  $id  = $_POST['id'] ?? '';
  $sp  = $_POST['sp'] ?? '';
  if ($act === 'block' && $id) {
    sb_patch('/rest/v1/chat_photos?id=eq.' . urlencode($id), ['blocked' => true]);
    audit('photo_block', null, ['photo' => $id]);
    flash('Fotoğraf engellendi');
  } elseif ($act === 'unblock' && $id) {
    sb_patch('/rest/v1/chat_photos?id=eq.' . urlencode($id), ['blocked' => false]);
    audit('photo_unblock', null, ['photo' => $id]);
    flash('Engel kaldırıldı');
  } elseif ($act === 'delete' && $id) {
    if ($sp) storage_delete(PHOTO_BUCKET, $sp);
    sb_delete('/rest/v1/chat_photos?id=eq.' . urlencode($id));
    audit('photo_delete', null, ['photo' => $id, 'path' => $sp]);
    flash('Fotoğraf silindi (depolama dahil)');
  }
  header('Location: photos.php' . (($_POST['tab'] ?? '') ? '?tab=' . urlencode($_POST['tab']) : ''));
  exit;
}

$tab = $_GET['tab'] ?? 'all';
$path = '/rest/v1/chat_photos?select=*&order=created_at.desc&limit=60';
if ($tab === 'blocked') $path .= '&blocked=eq.true';
if ($tab === 'nsfw')    $path .= '&nsfw_score=gte.0.5';
$rows = sb_get($path)['data'] ?? [];

/* isimler */
$ids = [];
foreach ($rows as $r) { $ids[$r['sender_id']] = 1; $ids[$r['receiver_id']] = 1; }
$names = [];
if ($ids) {
  $ps = sb_get('/rest/v1/profiles?id=in.(' . rawurlencode(implode(',', array_keys($ids))) . ')&select=id,nickname')['data'] ?? [];
  foreach ($ps as $p) $names[$p['id']] = $p['nickname'];
}

layout_top('Fotoğraflar', 'photos');
?>
<div class="formrow">
  <a class="btn <?= $tab === 'all' ? '' : 'ghost' ?> sm" href="photos.php">Tümü</a>
  <a class="btn <?= $tab === 'nsfw' ? '' : 'ghost' ?> sm" href="photos.php?tab=nsfw">Yüksek NSFW skoru</a>
  <a class="btn <?= $tab === 'blocked' ? '' : 'ghost' ?> sm" href="photos.php?tab=blocked">Engellenenler</a>
  <span class="spacer"></span>
  <small><?= count($rows) ?> kayıt (son 60) · görüntüler 10 dk geçerli imzalı bağlantıyla yüklenir</small>
</div>

<div class="grid c4" style="grid-template-columns:repeat(3,1fr)">
<?php if (!$rows): ?>
  <div class="card"><small>Fotoğraf yok</small></div>
<?php endif; ?>
<?php foreach ($rows as $p):
  $url = storage_signed_url(PHOTO_BUCKET, $p['storage_path']);
?>
  <div class="card" style="padding:12px">
    <div style="border-radius:12px;overflow:hidden;background:#0b0b10;height:200px;display:grid;place-items:center;margin-bottom:10px">
      <?php if ($url): ?>
        <a href="<?= h($url) ?>" target="_blank" rel="noopener">
          <img src="<?= h($url) ?>" alt="" style="max-width:100%;max-height:200px;object-fit:contain">
        </a>
      <?php else: ?>
        <small>görüntü yüklenemedi<br>(silinmiş / otomatik imha)</small>
      <?php endif; ?>
    </div>
    <div style="font-size:12.5px;line-height:1.6">
      <b><?= h($names[$p['sender_id']] ?? '?') ?></b> → <b><?= h($names[$p['receiver_id']] ?? '?') ?></b><br>
      <small><?= rel_time($p['created_at']) ?>
        · <?= $p['viewed_at'] ? 'görüntülendi' : 'görülmedi' ?>
        · NSFW: <?= number_format((float)($p['nsfw_score'] ?? 0), 2) ?></small><br>
      <?php if ($p['blocked']) echo badge('ENGELLİ', 'danger'); ?>
    </div>
    <div class="row" style="margin-top:10px">
      <?php if ($p['blocked']): ?>
      <form method="post"><input type="hidden" name="act" value="unblock"><input type="hidden" name="id" value="<?= h($p['id']) ?>"><input type="hidden" name="tab" value="<?= h($tab) ?>">
        <button class="btn ok sm">Engeli kaldır</button></form>
      <?php else: ?>
      <form method="post"><input type="hidden" name="act" value="block"><input type="hidden" name="id" value="<?= h($p['id']) ?>"><input type="hidden" name="tab" value="<?= h($tab) ?>">
        <button class="btn ghost sm">Engelle</button></form>
      <?php endif; ?>
      <form method="post" onsubmit="return confirm('Fotoğraf kalıcı silinsin mi?')">
        <input type="hidden" name="act" value="delete"><input type="hidden" name="id" value="<?= h($p['id']) ?>">
        <input type="hidden" name="sp" value="<?= h($p['storage_path']) ?>"><input type="hidden" name="tab" value="<?= h($tab) ?>">
        <button class="btn danger sm">Sil</button></form>
    </div>
  </div>
<?php endforeach; ?>
</div>
<?php layout_bottom(); ?>
