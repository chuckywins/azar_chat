<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $id = $_POST['id'] ?? '';
  $status = in_array($_POST['status'] ?? '', ['reviewed', 'dismissed', 'actioned'], true) ? $_POST['status'] : 'reviewed';
  if ($id) {
    sb_patch('/rest/v1/reports?id=eq.' . urlencode($id), [
      'status' => $status,
      'reviewed_at' => gmdate('c'),
      'reviewed_by' => $_SESSION['uid'],
    ]);
    audit('report_' . $status, $_POST['reported_id'] ?? null, ['report_id' => $id]);
    flash('Şikayet: ' . $status);
  }
  header('Location: reports.php' . (($_POST['tab'] ?? '') === 'all' ? '?tab=all' : ''));
  exit;
}

$tab = ($_GET['tab'] ?? '') === 'all' ? 'all' : 'pending';
$path = '/rest/v1/reports?select=*&order=created_at.desc&limit=100';
if ($tab === 'pending') $path .= '&status=eq.pending';
$rows = sb_get($path)['data'] ?? [];

/* isimleri topla */
$ids = [];
foreach ($rows as $r) { if ($r['reported_id']) $ids[$r['reported_id']] = 1; if ($r['reporter_id']) $ids[$r['reporter_id']] = 1; }
$names = [];
if ($ids) {
  $in = implode(',', array_map(fn($i) => '"' . $i . '"', array_keys($ids)));
  $ps = sb_get('/rest/v1/profiles?id=in.(' . rawurlencode(implode(',', array_keys($ids))) . ')&select=id,nickname')['data'] ?? [];
  foreach ($ps as $p) $names[$p['id']] = $p['nickname'];
}

layout_top('Şikayetler', 'reports');
?>
<div class="formrow">
  <a class="btn <?= $tab === 'pending' ? '' : 'ghost' ?> sm" href="reports.php">Bekleyenler</a>
  <a class="btn <?= $tab === 'all' ? '' : 'ghost' ?> sm" href="reports.php?tab=all">Tümü</a>
</div>

<div class="card" style="padding:6px 10px">
<table class="tbl">
  <tr><th>Sebep</th><th>Şikayet edilen</th><th>Eden</th><th>Not</th><th>Durum</th><th>Zaman</th><th></th></tr>
  <?php if (!$rows): ?><tr><td colspan="7"><small>Kayıt yok 🎉</small></td></tr><?php endif; ?>
  <?php foreach ($rows as $r): ?>
  <tr>
    <td><?= badge($r['reason'], in_array($r['reason'], ['nsfw', 'minor']) ? 'danger' : 'warn') ?></td>
    <td><b><?= h($names[$r['reported_id']] ?? '—') ?></b><div class="mono"><?= h(substr($r['reported_id'] ?? '', 0, 8)) ?></div></td>
    <td><?= h($names[$r['reporter_id']] ?? '—') ?></td>
    <td><small><?= h(mb_substr($r['note'] ?? '—', 0, 80)) ?></small></td>
    <td><?= badge($r['status'], $r['status'] === 'pending' ? 'warn' : ($r['status'] === 'actioned' ? 'danger' : 'muted')) ?></td>
    <td><small><?= rel_time($r['created_at']) ?></small></td>
    <td>
      <?php if ($r['status'] === 'pending'): ?>
      <div class="row">
        <form method="post"><input type="hidden" name="id" value="<?= h($r['id']) ?>"><input type="hidden" name="reported_id" value="<?= h($r['reported_id'] ?? '') ?>"><input type="hidden" name="tab" value="<?= h($tab) ?>">
          <button class="btn ghost sm" name="status" value="dismissed">Yoksay</button>
          <button class="btn ok sm" name="status" value="reviewed">İncelendi</button>
          <button class="btn danger sm" name="status" value="actioned">İşlem yapıldı</button>
        </form>
        <?php if ($r['reported_id']): ?>
        <a class="btn ghost sm" href="users.php?q=<?= h($names[$r['reported_id']] ?? '') ?>">Kullanıcı</a>
        <?php endif; ?>
      </div>
      <?php endif; ?>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
