<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';
require_once __DIR__ . '/mail_helpers.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

function ensure_password_reset_table(mysqli $conn): void
{
    $conn->query(
        "CREATE TABLE IF NOT EXISTS password_reset_codes (
            id INT PRIMARY KEY AUTO_INCREMENT,
            email VARCHAR(150) NOT NULL,
            code_hash VARCHAR(255) NOT NULL,
            expires_at DATETIME NOT NULL,
            used_at DATETIME NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_reset_email (email),
            INDEX idx_reset_expires (expires_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
}

function is_valid_email(string $email): bool
{
    return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
}

function find_user_by_email(mysqli $conn, string $email): ?array
{
    $stmt = $conn->prepare(
        "SELECT id, name, email FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1"
    );
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $user ?: null;
}

ensure_password_reset_table($conn);

$method = $_SERVER['REQUEST_METHOD'];
$jsonInput = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, is_array($jsonInput) ? $jsonInput : []);
$action = trim((string) ($input['action'] ?? ''));

if ($method !== 'POST') {
    send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
}

if ($action === 'request') {
    $email = strtolower(trim((string) ($input['email'] ?? $input['correo'] ?? '')));

    if (!is_valid_email($email) || !is_gmail_email($email)) {
        send_json(400, ['status' => 'error', 'message' => 'Debes usar un correo Gmail válido']);
    }

    $user = find_user_by_email($conn, $email);
    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'No existe una cuenta con ese correo']);
    }

    if (!smtp_is_configured()) {
        send_json(503, [
            'status' => 'error',
            'message' => 'Correo no configurado en el servidor. Configura SMTP_USER, SMTP_PASS y SMTP_FROM en Railway.',
            'code' => 'smtp_not_configured',
        ]);
    }

    $conn->query(
        "UPDATE password_reset_codes SET used_at = NOW()
         WHERE email = '" . $conn->real_escape_string($email) . "' AND used_at IS NULL"
    );

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $codeHash = password_hash($code, PASSWORD_BCRYPT);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+20 minutes'));

    $stmt = $conn->prepare(
        'INSERT INTO password_reset_codes (email, code_hash, expires_at) VALUES (?, ?, ?)'
    );
    $stmt->bind_param('sss', $email, $codeHash, $expiresAt);
    $stmt->execute();
    $stmt->close();

    $userName = $user['name'] ?? 'Usuario';
    $mailBody = "Hola {$userName},\n\n"
        . "Tu código para restablecer la contraseña en Q-LESS es: {$code}\n\n"
        . "Válido por 20 minutos. Si no solicitaste este cambio, ignora este mensaje.\n\n"
        . "— Equipo Q-LESS";

    $sent = send_reset_email(
        $email,
        'Código de recuperación Q-LESS',
        $mailBody
    );

    if (!$sent) {
        send_json(503, [
            'status' => 'error',
            'message' => 'No se pudo enviar el correo. Configura SMTP_USER y SMTP_PASS (Gmail) en Railway.',
        ]);
    }

    send_json(200, [
        'status' => 'success',
        'message' => 'Te enviamos un código de verificación a tu correo de Google/Gmail.',
    ]);
}

if ($action === 'reset') {
    $email = strtolower(trim((string) ($input['email'] ?? $input['correo'] ?? '')));
    $code = trim((string) ($input['code'] ?? ''));
    $newPassword = (string) ($input['password'] ?? $input['new_password'] ?? '');

    if (!is_valid_email($email) || !is_gmail_email($email) || $code === '') {
        send_json(400, ['status' => 'error', 'message' => 'Correo Gmail y código son requeridos']);
    }
    if (strlen($newPassword) < 6) {
        send_json(400, ['status' => 'error', 'message' => 'La contraseña debe tener al menos 6 caracteres']);
    }

    $stmt = $conn->prepare(
        "SELECT id, code_hash FROM password_reset_codes
         WHERE email = ? AND used_at IS NULL AND expires_at > NOW()
         ORDER BY id DESC LIMIT 1"
    );
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $resetRow = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$resetRow || !password_verify($code, $resetRow['code_hash'])) {
        send_json(400, ['status' => 'error', 'message' => 'Código inválido o expirado']);
    }

    $user = find_user_by_email($conn, $email);
    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'Usuario no encontrado']);
    }

    $passwordHash = password_hash($newPassword, PASSWORD_BCRYPT);
    $upd = $conn->prepare('UPDATE users SET password = ? WHERE id = ?');
    $userId = (int) $user['id'];
    $upd->bind_param('si', $passwordHash, $userId);
    $upd->execute();
    $upd->close();

    $mark = $conn->prepare('UPDATE password_reset_codes SET used_at = NOW() WHERE id = ?');
    $resetId = (int) $resetRow['id'];
    $mark->bind_param('i', $resetId);
    $mark->execute();
    $mark->close();

    send_json(200, [
        'status' => 'success',
        'message' => 'Contraseña actualizada. Ya puedes iniciar sesión.',
    ]);
}

send_json(400, ['status' => 'error', 'message' => 'Acción no válida']);
