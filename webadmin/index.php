<?php
require_once __DIR__ . '/lib.php';
require_admin();

/* canlı sayılar */
$totalUsers  = sb_count('/rest/v1/profiles?select=id');
$todayIso    = gmdate('Y-m-d') . 'T00:00:00Z';
$todayUsers  = sb_count('/rest/v1/profiles?select=id&created_at=gte.' . $todayIso);
$pendingRep  = sb_count('/rest/v1/reports?select=id&status=eq.pending');
$activeBans  = sb_count('/rest/v1/profiles?select=id&is_banned=eq.true');
$activeVip   = sb_count('/rest/v1/vip_subscriptions?select=id&active=eq.true');
$todaySpins  = sb_count('/rest/v1/wheel_spins?select=id&created_at=gte.' . $todayIso);

$live = sb_get('/rest/v1/live_stats?id=eq.1&select=online_users,queue,updated_at');
$online = $live['data'][0]['online_users'] ?? 0;
$queue  = $live['data'][0]['queue'] ?? 0;

/* sinyal sunucusu health */
$sig = @json_decode(@file_get_contents(SIGNALING_HEALTH_URL) ?: 'null', true);

/* son 14 gün: kayıt + coin hareketleri (istemcide grupla) */
$since = gmdate('Y-m-d\T00:00:00\Z', strtotime('-13 days'));
$signups = sb_get('/rest/v1/profiles?select=created_at&created_at=gte.' . $since . '&limit=5000');
$coins   = sb_get('/rest/v1/coin_transactions?select=created_at,delta,reason&created_at=gte.' . $since . '&limit=10000');

$days = [];
for ($i = 13; $i >= 0; $i--) $days[gmdate('Y-m-d', strtotime("-$i days"))] = ['signup' => 0, 'spent' => 0, 'earned' => 0];
foreach (($signups['data'] ?? []) as $r) {
  $d = substr($r['created_at'], 0, 10);
  if (isset($days[$d])) $days[$d]['signup']++;
}
foreach (($coins['data'] ?? []) as $r) {
  $d = substr($r['created_at'], 0, 10);
  if (!isset($days[$d])) continue;
  if (($r['delta'] ?? 0) < 0) $days[$d]['spent'] += -$r['delta'];
  else $days[$d]['earned'] += $r['delta'];
}
$labels  = array_map(fn($d) => date('d.m', strtotime($d)), array_keys($days));
$sData   = array_column($days, 'signup');
$spData  = array_column($days, 'spent');
$eaData  = array_column($days, 'earned');

/* bekleyen şikayetler (kısa liste) */
$reports = sb_get('/rest/v1/reports?status=eq.pending&order=created_at.desc&limit=6&select=id,reason,note,created_at,reported_id');

layout_top('Pano', 'dashboard');
?>
<div class="grid c4">
  <div class="card stat hot"><h3>Çevrimiçi</h3><div class="num"><?= (int)$online ?></div>
    <div class="sub">kuyruk: <?= (int)$queue ?> · sunucu odaları: <?= (int)($sig['rooms'] ?? 0) ?></div></div>
  <div class="card stat"><h3>Toplam kullanıcı</h3><div class="num"><?= number_format($totalUsers, 0, ',', '.') ?></div>
    <div class="sub">bugün +<?= (int)$todayUsers ?> yeni kayıt</div></div>
  <div class="card stat"><h3>Bekleyen şikayet</h3><div class="num"><?= (int)$pendingRep ?></div>
    <div class="sub">aktif ban: <?= (int)$activeBans ?></div></div>
  <div class="card stat"><h3>VIP üye</h3><div class="num"><?= (int)$activeVip ?></div>
    <div class="sub">bugün çark: <?= (int)$todaySpins ?> çevirme</div></div>
</div>

<div class="grid c2" style="margin-top:14px">
  <div class="card"><h3>Son 14 gün — yeni kayıtlar</h3><canvas id="chSign"></canvas></div>
  <div class="card"><h3>Son 14 gün — elmas hareketi</h3><canvas id="chCoin"></canvas></div>
</div>

<div class="section-title">Bekleyen şikayetler</div>
<div class="card">
<?php if (empty($reports['data'])): ?>
  <small>Bekleyen şikayet yok 🎉</small>
<?php else: ?>
  <table class="tbl">
    <tr><th>Sebep</th><th>Not</th><th>Hedef</th><th>Zaman</th><th></th></tr>
    <?php foreach ($reports['data'] as $r): ?>
    <tr>
      <td><?= badge($r['reason'], $r['reason'] === 'nsfw' || $r['reason'] === 'minor' ? 'danger' : 'warn') ?></td>
      <td><?= h(mb_substr($r['note'] ?? '—', 0, 60)) ?></td>
      <td class="mono"><?= h(substr($r['reported_id'] ?? '—', 0, 8)) ?></td>
      <td><small><?= rel_time($r['created_at']) ?></small></td>
      <td><a class="btn ghost sm" href="reports.php">İncele</a></td>
    </tr>
    <?php endforeach; ?>
  </table>
<?php endif; ?>
</div>

<script>
const gridColor = 'rgba(255,255,255,.06)', tickColor = '#8f8fa0';
const baseOpts = {
  responsive: true, plugins: { legend: { labels: { color: '#f2f2f6', boxWidth: 12, font: { size: 11 } } } },
  scales: { x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } },
            y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } }, beginAtZero: true } }
};
new Chart(document.getElementById('chSign'), {
  type: 'bar',
  data: { labels: <?= json_encode($labels) ?>, datasets: [{
    label: 'Yeni kayıt', data: <?= json_encode($sData) ?>,
    backgroundColor: 'rgba(255,59,129,.7)', borderRadius: 6 }] },
  options: baseOpts,
});
new Chart(document.getElementById('chCoin'), {
  type: 'line',
  data: { labels: <?= json_encode($labels) ?>, datasets: [
    { label: 'Harcanan', data: <?= json_encode($spData) ?>, borderColor: '#ff3b81', backgroundColor: 'rgba(255,59,129,.15)', fill: true, tension: .35 },
    { label: 'Kazanılan', data: <?= json_encode($eaData) ?>, borderColor: '#2be0a6', backgroundColor: 'rgba(43,224,166,.12)', fill: true, tension: .35 },
  ] },
  options: baseOpts,
});
</script>
<?php layout_bottom(); ?>
