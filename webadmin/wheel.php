<?php
require_once __DIR__ . '/lib.php';
require_admin();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $act = $_POST['act'] ?? '';
  if ($act === 'create' || $act === 'update') {
    $body = [
      'label' => trim($_POST['label'] ?? ''),
      'icon' => trim($_POST['icon'] ?? '🎁') ?: '🎁',
      'prize_type' => in_array($_POST['ptype'] ?? '', ['none', 'coins', 'time_card', 'vip_days'], true) ? $_POST['ptype'] : 'coins',
      'amount' => max(0, (int)($_POST['amount'] ?? 0)),
      'weight' => max(1, (int)($_POST['weight'] ?? 1)),
      'sort' => (int)($_POST['sort'] ?? 0),
      'active' => isset($_POST['active']),
    ];
    if ($act === 'create' && $body['label'] !== '') {
      sb_post('/rest/v1/wheel_prizes', $body);
      audit('wheel_create', null, $body);
      flash('Ödül eklendi');
    } elseif ($act === 'update' && !empty($_POST['id'])) {
      sb_patch('/rest/v1/wheel_prizes?id=eq.' . urlencode($_POST['id']), $body);
      audit('wheel_update', null, ['id' => $_POST['id']] + $body);
      flash('Ödül güncellendi');
    }
  } elseif ($act === 'delete' && !empty($_POST['id'])) {
    sb_delete('/rest/v1/wheel_prizes?id=eq.' . urlencode($_POST['id']));
    audit('wheel_delete', null, ['id' => $_POST['id']]);
    flash('Ödül silindi');
  }
  header('Location: wheel.php');
  exit;
}

$rows = sb_get('/rest/v1/wheel_prizes?select=*&order=sort.asc&limit=50')['data'] ?? [];
$todayIso = gmdate('Y-m-d') . 'T00:00:00Z';
$todaySpins = sb_count('/rest/v1/wheel_spins?select=id&created_at=gte.' . $todayIso);

$totalW = 0;
foreach ($rows as $r) if ($r['active']) $totalW += (int)$r['weight'];

$types = ['none' => 'Boş', 'coins' => 'Elmas', 'time_card' => 'Süre kartı', 'vip_days' => 'VIP (gün)'];

layout_top('Şans Çarkı', 'wheel');
?>
<div class="grid c4">
  <div class="card stat"><h3>Bugünkü çevirme</h3><div class="num"><?= $todaySpins ?></div></div>
  <div class="card stat"><h3>Aktif ödül</h3><div class="num"><?= count(array_filter($rows, fn($r) => $r['active'])) ?></div></div>
  <div class="card stat"><h3>Toplam ağırlık</h3><div class="num"><?= $totalW ?></div></div>
  <div class="card"><h3>Not</h3><small>Oranlar yalnızca burada görünür — kullanıcı çarkında tüm dilimler eşit çizilir, ağırlıklar istemciye asla gitmez.</small></div>
</div>

<div class="card" style="margin-top:14px">
  <h3>Yeni ödül</h3>
  <form method="post" class="formrow">
    <input type="hidden" name="act" value="create">
    <input name="label" placeholder="Etiket (10 Elmas)" required style="width:150px">
    <input name="icon" placeholder="💎" style="width:60px">
    <select name="ptype"><?php foreach ($types as $k => $v) echo "<option value=\"$k\">$v</option>"; ?></select>
    <input name="amount" type="number" placeholder="Miktar" style="width:90px">
    <input name="weight" type="number" placeholder="Ağırlık" style="width:90px" value="10">
    <input name="sort" type="number" placeholder="Sıra" style="width:70px">
    <label><input type="checkbox" name="active" checked> aktif</label>
    <button class="btn sm">Ekle</button>
  </form>
</div>

<div class="card" style="margin-top:14px;padding:6px 10px">
<table class="tbl">
  <tr><th></th><th>Etiket</th><th>Tür</th><th>Miktar</th><th>Ağırlık</th><th>Gerçek oran</th><th>Durum</th><th style="width:280px">Düzenle</th></tr>
  <?php foreach ($rows as $r): ?>
  <tr>
    <td style="font-size:20px"><?= h($r['icon']) ?></td>
    <td><b><?= h($r['label']) ?></b></td>
    <td><small><?= h($types[$r['prize_type']] ?? '?') ?></small></td>
    <td><?= (int)$r['amount'] ?></td>
    <td><?= (int)$r['weight'] ?></td>
    <td><?= $r['active'] && $totalW > 0 ? badge('%' . number_format($r['weight'] * 100 / $totalW, 1), 'accent') : badge('—', 'muted') ?></td>
    <td><?= $r['active'] ? badge('aktif', 'ok') : badge('pasif', 'muted') ?></td>
    <td>
      <form method="post" class="row">
        <input type="hidden" name="act" value="update">
        <input type="hidden" name="id" value="<?= h($r['id']) ?>">
        <input type="hidden" name="label" value="<?= h($r['label']) ?>">
        <input type="hidden" name="icon" value="<?= h($r['icon']) ?>">
        <input type="hidden" name="ptype" value="<?= h($r['prize_type']) ?>">
        <input name="amount" type="number" value="<?= (int)$r['amount'] ?>" style="width:70px" title="Miktar">
        <input name="weight" type="number" value="<?= (int)$r['weight'] ?>" style="width:70px" title="Ağırlık">
        <input name="sort" type="number" value="<?= (int)$r['sort'] ?>" style="width:60px" title="Sıra">
        <label style="font-size:11px"><input type="checkbox" name="active" <?= $r['active'] ? 'checked' : '' ?>> aktif</label>
        <button class="btn ghost sm">Kaydet</button>
      </form>
      <form method="post" style="display:inline" onsubmit="return confirm('Silinsin mi?')">
        <input type="hidden" name="act" value="delete"><input type="hidden" name="id" value="<?= h($r['id']) ?>">
        <button class="btn danger sm">Sil</button>
      </form>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>
<?php layout_bottom(); ?>
