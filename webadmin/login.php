<?php
require_once __DIR__ . '/lib.php';

if (!empty($_SESSION['uid'])) { header('Location: index.php'); exit; }

$err = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
  $err = admin_login(trim($_POST['email'] ?? ''), $_POST['password'] ?? '');
  if ($err === null) { header('Location: index.php'); exit; }
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
    <p>Sadece admin / moderatör hesapları girebilir</p>
    <?php if ($err) echo '<div class="err">' . h($err) . '</div>'; ?>
    <input type="email" name="email" placeholder="E-posta" required autofocus>
    <input type="password" name="password" placeholder="Şifre" required>
    <button class="btn" type="submit">Giriş yap</button>
  </form>
</div>
</body></html>
