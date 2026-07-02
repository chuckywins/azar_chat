<?php
require_once __DIR__ . '/lib.php';

if (!empty($_SESSION['authed'])) { header('Location: index.php'); exit; }

$err = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $id = trim($_POST['email'] ?? '');
  $pw = $_POST['password'] ?? '';
  // 1) yerel panel hesabı (config.local.php: ADMIN_PANEL_USER/PASS)
  if (admin_login_local($id, $pw)) { header('Location: index.php'); exit; }
  // 2) Supabase admin/moderatör hesabı (e-posta ile)
  if (strpos($id, '@') !== false) {
    $err = admin_login($id, $pw);
    if ($err === null) { header('Location: index.php'); exit; }
  } else {
    $err = 'Kullanıcı adı veya şifre hatalı.';
  }
}
?>
<!doctype html><html lang="tr"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>kerochat admin — giriş</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/style.css">
</head><body>
<div class="login-wrap">
  <form class="login-card" method="post" autocomplete="off">
    <div class="logo">K</div>
    <h1>kerochat yönetim</h1>
    <p>Panel hesabı veya admin rollü Supabase hesabı</p>
    <?php if ($err) echo '<div class="err">' . h($err) . '</div>'; ?>
    <input type="text" name="email" placeholder="Kullanıcı adı veya e-posta" required autofocus>
    <input type="password" name="password" placeholder="Şifre" required>
    <button class="btn" type="submit">Giriş yap</button>
  </form>
</div>
</body></html>
