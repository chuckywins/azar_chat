<?php
require_once __DIR__ . '/lib.php';
require_admin();

$rows = sb_get('/rest/v1/audit_logs?select=*&order=created_at.desc&limit=200')['data'] ?? [];

$ids = [];
foreach ($rows as $r) { if ($r['actor_id']) $ids[$r['actor_id']] = 1; if ($r['target_id']) $ids[$r['target_id']] = 1; }
$names = [];
if ($ids) {
  $ps = sb_get('/rest/v1/profiles?id=in.(' . rawurlencode(implode(',', array_keys($ids))) . ')&select=id,nickname')['data'] ?? [];
  foreach ($ps as $p) $names[$p['id']] = $p['nickname'];
}

layout_top('Audit Log', 'audit');
?>
<div class="card" style="padding:6px 10px">
<table class="tbl">
  <tr><th>Aksiyon</th><th>Yapan</th><th>Hedef</th><th>Detay</th><th>IP</th><th>Zaman</th></tr>
  <?php foreach ($rows as $a): ?>
  <tr>
    <td><?= badge($a['action'], str_contains($a['action'], 'ban') ? 'danger' : 'muted') ?></td>
    <td><?= h($names[$a['actor_id']] ?? '—') ?></td>
    <td><?= h($names[$a['target_id']] ?? ($a['target_id'] ? substr($a['target_id'], 0, 8) : '—')) ?></td>
    <td><small class="mono"><?= h(mb_substr(json_encode($a['details'], JSON_UNESCAPED_UNICODE) ?? '', 0, 80)) ?></small></td>
    <td><small class="mono"><?= h($a['ip'] ?? '—') ?></small></td>
    <td><small><?= rel_time($a['created_at']) ?></small></td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
