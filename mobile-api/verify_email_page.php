<?php
/**
 * Verificación de correo desde enlace del email.
 * GET con email+code: verifica automáticamente. POST: verifica desde formulario.
 */
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/auth_actions.php';

$email = strtolower(trim((string) ($_REQUEST['email'] ?? $_REQUEST['correo'] ?? '')));
$code = trim((string) ($_REQUEST['code'] ?? ''));
$autoVerify = $_SERVER['REQUEST_METHOD'] === 'GET' && $email !== '' && $code !== '';
$success = false;
$message = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST' || $autoVerify) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $email = strtolower(trim((string) ($_POST['email'] ?? '')));
        $code = trim((string) ($_POST['code'] ?? ''));
    }
    $result = perform_email_verification($conn, $email, $code);
    if ($result['ok']) {
        $success = true;
        $message = $result['message'];
    } else {
        $error = $result['message'];
    }
}

$appUrl = qless_flutter_app_url();
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Q-LESS — Verificar correo</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #F4F6F4; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { width: 100%; max-width: 400px; background: #fff; border-radius: 20px; overflow: hidden; box-shadow: 0 8px 32px rgba(0,0,0,.1); }
    .header { background: linear-gradient(135deg, #3EC13B, #2FA832); color: #fff; text-align: center; padding: 28px 20px; }
    .header h1 { font-size: 26px; letter-spacing: 1px; }
    .content { padding: 24px 22px 28px; }
    label { display: block; font-size: 13px; color: #555; margin-bottom: 6px; }
    input { width: 100%; padding: 14px 16px; border: 1px solid #E4E8E4; border-radius: 16px; font-size: 15px; margin-bottom: 14px; }
    .btn { width: 100%; padding: 16px; border: none; border-radius: 18px; background: #3EC13B; color: #fff; font-size: 16px; font-weight: 700; cursor: pointer; }
    .btn-outline { display: block; text-align: center; margin-top: 12px; padding: 14px; border-radius: 16px; border: 1px solid #E4E8E4; color: #333; text-decoration: none; font-weight: 600; }
    .ok { background: #E8F5E9; color: #1B5E20; padding: 12px; border-radius: 12px; margin-bottom: 16px; font-size: 14px; }
    .err { background: #FFEBEE; color: #B71C1C; padding: 12px; border-radius: 12px; margin-bottom: 16px; font-size: 14px; }
    .hint { font-size: 13px; color: #666; margin-bottom: 16px; line-height: 1.45; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header"><h1>Q-LESS</h1><p style="margin-top:8px;opacity:.9;">Verificar correo Gmail</p></div>
    <div class="content">
      <?php if ($success): ?>
        <div class="ok"><?= htmlspecialchars($message, ENT_QUOTES, 'UTF-8') ?></div>
        <p class="hint">Tu cuenta está verificada. Abre la aplicación e inicia sesión con tu correo y contraseña.</p>
        <?php if ($appUrl !== ''): ?>
          <a class="btn-outline" href="<?= htmlspecialchars($appUrl, ENT_QUOTES, 'UTF-8') ?>">Abrir aplicación Q-LESS</a>
        <?php endif; ?>
      <?php else: ?>
        <?php if ($error !== ''): ?><div class="err"><?= htmlspecialchars($error, ENT_QUOTES, 'UTF-8') ?></div><?php endif; ?>
        <p class="hint">Ingresa tu correo Gmail y el código de 6 dígitos del mensaje de verificación.</p>
        <form method="post" action="">
          <label for="email">Correo Gmail</label>
          <input type="email" id="email" name="email" value="<?= htmlspecialchars($email, ENT_QUOTES, 'UTF-8') ?>" required>
          <label for="code">Código</label>
          <input type="text" id="code" name="code" value="<?= htmlspecialchars($code, ENT_QUOTES, 'UTF-8') ?>" required maxlength="6" inputmode="numeric">
          <button type="submit" class="btn">Verificar correo</button>
        </form>
      <?php endif; ?>
    </div>
  </div>
</body>
</html>
