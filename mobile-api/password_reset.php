<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';
require_once __DIR__ . '/mail_helpers.php';
require_once __DIR__ . '/auth_actions.php';

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

function send_password_reset_code(mysqli $conn, string $email): array
{
    $email = strtolower(trim($email));

    if (!is_valid_email($email) || !is_gmail_email($email)) {
        return ['ok' => false, 'status' => 400, 'message' => 'Debes usar un correo Gmail válido'];
    }

    $user = find_user_by_email($conn, $email);
    if (!$user) {
        return [
            'ok' => false,
            'status' => 200,
            'message' => 'Si el correo está registrado, recibirás un código en unos minutos.',
            'generic' => true,
        ];
    }

    if (!smtp_is_configured()) {
        return [
            'ok' => false,
            'status' => 503,
            'message' => 'Correo no configurado en el servidor. Configura SMTP en Railway (Brevo o Gmail).',
            'code' => 'smtp_not_configured',
        ];
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
    $mail = qless_password_reset_email($userName, $code, $email);
    $sent = send_app_email(
        $email,
        'Código de recuperación Q-LESS',
        $mail['plain'],
        $mail['html']
    );

    if (!$sent) {
        return [
            'ok' => false,
            'status' => 503,
            'message' => 'No se pudo enviar el correo. Revisa SMTP_USER y SMTP_PASS en Railway.',
        ];
    }

    return [
        'ok' => true,
        'status' => 200,
        'message' => 'Te enviamos un código y un enlace para restablecer tu contraseña.',
        'reset_url' => qless_reset_password_link($email, $code),
    ];
}

ensure_password_reset_table($conn);

$method = $_SERVER['REQUEST_METHOD'];
$jsonInput = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, is_array($jsonInput) ? $jsonInput : []);
$action = trim((string) ($input['action'] ?? ''));

if ($method !== 'POST') {
    send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
}

if ($action === 'request' || $action === 'resend') {
    $email = strtolower(trim((string) ($input['email'] ?? $input['correo'] ?? '')));
    $result = send_password_reset_code($conn, $email);
    send_json(
        $result['status'] ?? ($result['ok'] ? 200 : 400),
        [
            'status' => $result['ok'] ? 'success' : 'error',
            'message' => $result['message'],
            'code' => $result['code'] ?? null,
            'reset_url' => $result['reset_url'] ?? null,
        ]
    );
}

if ($action === 'reset') {
    $email = strtolower(trim((string) ($input['email'] ?? $input['correo'] ?? '')));
    $code = trim((string) ($input['code'] ?? ''));
    $newPassword = (string) ($input['password'] ?? $input['new_password'] ?? '');

    $result = perform_password_reset($conn, $email, $code, $newPassword);
    send_json(
        $result['ok'] ? 200 : 400,
        ['status' => $result['ok'] ? 'success' : 'error', 'message' => $result['message']]
    );
}

send_json(400, ['status' => 'error', 'message' => 'Acción no válida']);
