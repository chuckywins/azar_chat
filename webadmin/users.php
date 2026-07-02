<?php
require_once __DIR__ . '/lib.php';
require_admin();

/* ── aksiyonlar ─────────────────────────────────────────────────────────── */
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $uid = $_POST['uid'] ?? '';
  $act = $_POST['act'] ?? '';
  if ($uid) {
    switch ($act) {
      case 'ban':
        $days = max(0, (int)($_POST['days'] ?? 0));
        $reason = trim($_POST['reason'] ?? '') ?: 'webadmin ban';
        sb_patch('/rest/v1/profiles?id=eq.' . urlencode($uid), [
          'is_banned' => true,
          'banned_until' => $days > 0 ? gmdate('c', time() + $days * 86400) : null,
          'ban_reason' => $reason,
        ]);
        audit('ban_user', $uid, ['days' => $days, 'reason' => $reason]);
        flash('Kullanıcı banlandı' . ($days > 0 ? " ($days gün)" : ' (süresiz)'));
        break;
      case 'unban':
        sb_patch('/rest/v1/profiles?id=eq.' . urlencode($uid), [
          'is_banned' => false, 'banned_until' => null, 'ban_reason' => null,
        ]);
        audit('unban_user', $uid);
        flash('Ban kaldırıldı');
        break;
      case 'coins':
        $delta = (int)($_POST['delta'] ?? 0);
        if ($delta !== 0) {
          sb_post('/rest/v1/coin_transactions', [
            'user_id' => $uid, 'delta' => $delta, 'reason' => 'admin_grant',
            'note' => 'webadmin', 'created_by' => $_SESSION['uid'],
          ]);
          audit('grant_coins', $uid, ['delta' => $delta]);
          flash(($delta > 0 ? '+' : '') . $delta . ' elmas işlendi');
        }
        break;
      case 'vip':
        $days = max(1, (int)($_POST['days'] ?? 30));
        sb_patch('/rest/v1/vip_subscriptions?user_id=eq.' . urlencode($uid) . '&active=eq.true', ['active' => false]);
        sb_post('/rest/v1/vip_subscriptions', [
          'user_id' => $uid, 'tier' => 'vip', 'source' => 'admin',
          'expires_at' => gmdate('c', time() + $days * 86400), 'created_by' => $_SESSION['uid'],
        ]);
        audit('grant_vip', $uid, ['days' => $days]);
        flash("VIP verildi ($days gün)");
        break;
      case 'role':
        if (!is_full_admin()) { flash('Rol değişikliği sadece admin yetkisidir'); break; }
        $role = in_array($_POST['role'] ?? '', ['user', 'moderator', 'admin'], true) ? $_POST['role'] : 'user';
        sb_patch('/rest/v1/profiles?id=eq.' . urlencode($uid), ['role' => $role]);
        audit('update_role', $uid, ['role' => $role]);
        flash("Rol güncellendi: $role");
        break;
    }
  }
  header('Location: users.php?q=' . urlencode($_POST['q'] ?? ''));
  exit;
}

/* ── liste ──────────────────────────────────────────────────────────────── */
$q = trim($_GET['q'] ?? '');
$path = '/rest/v1/profiles?select=id,nickname,role,coins,time_cards,is_banned,banned_until,country,avatar_url,created_at,adult_confirmed_at'
      . '&order=created_at.desc&limit=50';
if ($q !== '') $path .= '&nickname=ilike.*' . rawurlencode($q) . '*';
$users = sb_get($path)['data'] ?? [];

/* aktif vip id seti */
$vipRows = sb_get('/rest/v1/vip_subscriptions?active=eq.true&select=user_id')['data'] ?? [];
$vipSet = array_flip(array_column($vipRows, 'user_id'));

layout_top('Kullanıcılar', 'users');
?>
<form class="formrow" method="get">
  <input type="text" name="q" value="<?= h($q) ?>" placeholder="Kullanıcı adına göre ara…" style="width:280px">
  <button class="btn sm" type="submit">Ara</button>
  <?php if ($q !== ''): ?><a class="btn ghost sm" href="users.php">Temizle</a><?php endif; ?>
  <span class="spacer"></span>
  <small><?= count($users) ?> sonuç (en yeni 50)</small>
</form>

<div class="card" style="padding:6px 10px">
<table class="tbl">
  <tr><th>Kullanıcı</th><th>Rol</th><th>Elmas</th><th>Kart</th><th>Durum</th><th>Kayıt</th><th style="width:320px">Aksiyonlar</th></tr>
  <?php foreach ($users as $u): $uid = $u['id']; $isVip = isset($vipSet[$uid]); ?>
  <tr>
    <td>
      <span class="avatar"><?php if (!empty($u['avatar_url'])): ?><img src="<?= h($u['avatar_url']) ?>" alt=""><?php else: echo h(mb_strtoupper(mb_substr($u['nickname'] ?? '?', 0, 1))); endif; ?></span>
      &nbsp;<b><?= h($u['nickname'] ?? '—') ?></b>
      <?php if ($isVip) echo ' ' . badge('VIP', 'vip'); ?>
      <div class="mono"><?= h(substr($uid, 0, 13)) ?>… · <?= h($u['country'] ?? '?') ?><?= empty($u['adult_confirmed_at']) ? ' · 18? yok' : '' ?></div>
    </td>
    <td><?= badge($u['role'], $u['role'] === 'admin' ? 'accent' : ($u['role'] === 'moderator' ? 'warn' : 'muted')) ?></td>
    <td><b><?= (int)($u['coins'] ?? 0) ?></b></td>
    <td><?= (int)($u['time_cards'] ?? 0) ?></td>
    <td><?php
      if ($u['is_banned']) {
        echo badge($u['banned_until'] ? ('banlı → ' . date('d.m H:i', strtotime($u['banned_until']))) : 'süresiz ban', 'danger');
      } else echo badge('aktif', 'ok');
    ?></td>
    <td><small><?= rel_time($u['created_at']) ?></small></td>
    <td>
      <div class="row">
        <?php if ($u['is_banned']): ?>
          <form method="post" style="display:inline"><input type="hidden" name="uid" value="<?= h($uid) ?>"><input type="hidden" name="q" value="<?= h($q) ?>">
            <button class="btn ok sm" name="act" value="unban">Banı kaldır</button></form>
        <?php else: ?>
          <button class="btn danger sm" onclick="banU('<?= h($uid) ?>')">Ban</button>
        <?php endif; ?>
        <button class="btn ghost sm" onclick="coinU('<?= h($uid) ?>')">± Elmas</button>
        <button class="btn ghost sm" onclick="vipU('<?= h($uid) ?>')">VIP ver</button>
        <?php if (is_full_admin()): ?>
        <button class="btn ghost sm" onclick="roleU('<?= h($uid) ?>')">Rol</button>
        <?php endif; ?>
      </div>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
</div>

<form id="actForm" method="post" style="display:none">
  <input type="hidden" name="uid" id="f_uid">
  <input type="hidden" name="act" id="f_act">
  <input type="hidden" name="days" id="f_days">
  <input type="hidden" name="delta" id="f_delta">
  <input type="hidden" name="reason" id="f_reason">
  <input type="hidden" name="role" id="f_role">
  <input type="hidden" name="q" value="<?= h($q) ?>">
</form>
<script>
const F = document.getElementById('actForm');
function go(uid, act, extra) {
  document.getElementById('f_uid').value = uid;
  document.getElementById('f_act').value = act;
  for (const k in (extra || {})) document.getElementById('f_' + k).value = extra[k];
  F.submit();
}
function banU(uid) {
  const days = prompt('Kaç gün ban? (0 = süresiz)', '1');
  if (days === null) return;
  const reason = prompt('Sebep:', 'Kural ihlali') || 'Kural ihlali';
  go(uid, 'ban', { days, reason });
}
function coinU(uid) {
  const delta = prompt('Elmas miktarı (negatif = düş):', '50');
  if (delta === null || parseInt(delta) === 0 || isNaN(parseInt(delta))) return;
  go(uid, 'coins', { delta });
}
function vipU(uid) {
  const days = prompt('Kaç gün VIP?', '30');
  if (days === null) return;
  go(uid, 'vip', { days });
}
function roleU(uid) {
  const role = prompt('Yeni rol (user / moderator / admin):', 'user');
  if (!role) return;
  go(uid, 'role', { role });
}
</script>
<?php layout_bottom(); ?>
