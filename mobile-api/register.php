<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=UTF-8');

require_once 'config.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/mail_helpers.php';
require_once __DIR__ . '/email_templates.php';
require_once __DIR__ . '/auth_actions.php';

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

function ensure_email_verification_table(mysqli $conn): void
{
    $conn->query(
        "CREATE TABLE IF NOT EXISTS email_verification_codes (
            id INT PRIMARY KEY AUTO_INCREMENT,
            email VARCHAR(150) NOT NULL,
            code_hash VARCHAR(255) NOT NULL,
            payload_json TEXT NULL,
            expires_at DATETIME NOT NULL,
            used_at DATETIME NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_email_verification_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
}

ensure_users_table($conn);
ensure_email_verification_table($conn);

$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);
$action = trim((string) ($input['action'] ?? 'register'));

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
}

if ($action === 'verify_email') {
    $email = strtolower(trim((string) ($input['correo'] ?? $input['email'] ?? '')));
    $code = trim((string) ($input['code'] ?? ''));
    $result = perform_email_verification($conn, $email, $code);
    send_json(
        $result['ok'] ? 200 : 400,
        ['status' => $result['ok'] ? 'success' : 'error', 'message' => $result['message']]
    );
}

if ($action === 'resend_code') {
    $email = strtolower(trim((string) ($input['correo'] ?? $input['email'] ?? '')));
    if (!is_gmail_email($email)) {
        send_json(400, ['status' => 'error', 'message' => 'Correo Gmail requerido']);
    }

    $stmt = $conn->prepare('SELECT id, name, email_verified FROM users WHERE email = ? LIMIT 1');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'No hay cuenta con ese correo. Regístrate primero.']);
    }
    if (intval($user['email_verified'] ?? 0) === 1) {
        send_json(400, ['status' => 'error', 'message' => 'Este correo ya está verificado. Inicia sesión.']);
    }

    if (!smtp_is_configured()) {
        send_json(500, [
            'status' => 'error',
            'message' => 'SMTP no configurado. Agrega SMTP_USER y SMTP_PASS en Railway.',
            'code' => 'smtp_not_configured',
        ]);
    }

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $codeHash = password_hash($code, PASSWORD_BCRYPT);
    $expiresAt = date('Y-m-d H:i:s', strtotime('+30 minutes'));

    $ins = $conn->prepare(
        'INSERT INTO email_verification_codes (email, code_hash, expires_at) VALUES (?, ?, ?)'
    );
    $ins->bind_param('sss', $email, $codeHash, $expiresAt);
    $ins->execute();
    $ins->close();

    $nombre = trim((string) ($user['name'] ?? 'Usuario'));
    $mail = qless_verify_email_content($nombre, $code, $email);
    $sent = send_app_email($email, 'Código de verificación Q-LESS', $mail['plain'], $mail['html']);

    send_json(200, [
        'status' => 'success',
        'message' => $sent
            ? 'Código reenviado. Revisa tu bandeja de Gmail.'
            : 'No se pudo enviar el correo. Verifica SMTP_USER y SMTP_PASS en Railway.',
        'data' => ['email_sent' => $sent],
    ]);
}

$nombre = trim($input['nombre'] ?? $input['name'] ?? '');
$email = strtolower(trim($input['correo'] ?? $input['email'] ?? ''));
$password = $input['password'] ?? '';
$role = strtolower(trim($input['role'] ?? 'aprendiz'));
$acceptedTerms = filter_var(
    $input['accepted_terms'] ?? $input['terms_accepted'] ?? false,
    FILTER_VALIDATE_BOOLEAN
);
$privacyVersion = trim((string) ($input['privacy_version'] ?? '1.0'));

if ($nombre === '' || $email === '' || $password === '') {
    send_json(400, ['status' => 'error', 'message' => 'Todos los campos son obligatorios']);
}

if (!$acceptedTerms) {
    send_json(400, [
        'status' => 'error',
        'message' => 'Debes aceptar los Términos y la Política de Privacidad para crear tu cuenta.',
        'code' => 'terms_not_accepted',
    ]);
}

if (!is_gmail_email($email)) {
    send_json(400, [
        'status' => 'error',
        'message' => 'Debes registrarte con un correo Gmail real (@gmail.com).',
    ]);
}

if (strlen($password) < 6) {
    send_json(400, ['status' => 'error', 'message' => 'La contraseña debe tener al menos 6 caracteres']);
}

$stmt = $conn->prepare('SELECT id FROM users WHERE email = ?');
$stmt->bind_param('s', $email);
$stmt->execute();
if ($stmt->get_result()->num_rows > 0) {
    $stmt->close();
    send_json(409, ['status' => 'error', 'message' => 'El correo ya está registrado']);
}
$stmt->close();

$hashedPassword = password_hash($password, PASSWORD_BCRYPT);
$stmt = $conn->prepare(
    'INSERT INTO users (name, email, password, role, email_verified, purchases_enabled, terms_accepted, terms_accepted_at, privacy_version, created_at, updated_at)
     VALUES (?, ?, ?, ?, 0, 0, 1, NOW(), ?, NOW(), NOW())'
);
$stmt->bind_param('sssss', $nombre, $email, $hashedPassword, $role, $privacyVersion);

if (!$stmt->execute()) {
    send_json(500, ['status' => 'error', 'message' => 'Error al registrar: ' . $conn->error]);
}
$newId = (int) $conn->insert_id;
$stmt->close();

$code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
$codeHash = password_hash($code, PASSWORD_BCRYPT);
$expiresAt = date('Y-m-d H:i:s', strtotime('+30 minutes'));

$ins = $conn->prepare(
    'INSERT INTO email_verification_codes (email, code_hash, expires_at) VALUES (?, ?, ?)'
);
$ins->bind_param('sss', $email, $codeHash, $expiresAt);
$ins->execute();
$ins->close();

$mail = qless_verify_email_content($nombre, $code, $email);

if (!smtp_is_configured()) {
    send_json(200, [
        'status' => 'success',
        'message' => 'Cuenta creada. SMTP no configurado en Railway; configura SMTP_USER y SMTP_PASS.',
        'data' => [
            'id' => $newId,
            'nombre' => $nombre,
            'correo' => $email,
            'role' => $role,
            'needs_verification' => true,
            'email_sent' => false,
            'terms_accepted' => true,
            'privacy_version' => $privacyVersion,
            'base_api_url' => $baseUrl,
        ],
    ]);
}

$sent = send_app_email($email, 'Verifica tu correo Gmail - Q-LESS', $mail['plain'], $mail['html']);

if (!$sent) {
    send_json(200, [
        'status' => 'success',
        'message' => 'Cuenta creada. No se pudo enviar el correo ahora; usa «Reenviar código» o revisa SMTP en Railway.',
        'data' => [
            'id' => $newId,
            'nombre' => $nombre,
            'correo' => $email,
            'role' => $role,
            'needs_verification' => true,
            'email_sent' => false,
            'terms_accepted' => true,
            'privacy_version' => $privacyVersion,
            'base_api_url' => $baseUrl,
        ],
    ]);
}

send_json(200, [
    'status' => 'success',
    'message' => 'Cuenta creada. Revisa tu Gmail e ingresa el código de verificación.',
    'data' => [
        'id' => $newId,
        'nombre' => $nombre,
        'correo' => $email,
        'role' => $role,
        'needs_verification' => true,
        'email_sent' => true,
        'terms_accepted' => true,
        'privacy_version' => $privacyVersion,
        'base_api_url' => $baseUrl,
    ],
]);
