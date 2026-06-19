<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=UTF-8');

require_once __DIR__ . '/config.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit();
}

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
    }

    $json_input = json_decode(file_get_contents('php://input'), true) ?: [];
    $input = array_merge($_REQUEST, is_array($json_input) ? $json_input : []);

    $idToken = trim((string) ($input['id_token'] ?? ''));
    if ($idToken === '') {
        send_json(400, ['status' => 'error', 'message' => 'Token de Google requerido']);
    }

    $verifyUrl = 'https://oauth2.googleapis.com/tokeninfo?id_token=' . urlencode($idToken);
    $verifyResponse = @file_get_contents($verifyUrl);
    if ($verifyResponse === false) {
        send_json(502, ['status' => 'error', 'message' => 'No se pudo validar el token de Google']);
    }

    $googleUser = json_decode($verifyResponse, true);
    if (!is_array($googleUser) || empty($googleUser['email'])) {
        send_json(401, ['status' => 'error', 'message' => 'Token de Google inválido']);
    }

    $email = strtolower(trim((string) $googleUser['email']));
    $name = trim((string) ($googleUser['name'] ?? ''));
    if ($name === '') {
        $name = ucfirst(strtok($email, '@'));
    }

    if (!is_gmail_email($email)) {
        send_json(400, [
            'status' => 'error',
            'message' => 'Solo puedes iniciar sesión con una cuenta Gmail.',
        ]);
    }

    $roleExpr = users_role_sql_expr();
    $stmt = $conn->prepare("SELECT id, name, email, ($roleExpr) AS role,
            COALESCE(email_verified, 1) AS email_verified,
            COALESCE(purchases_enabled, 0) AS purchases_enabled
        FROM users WHERE email = ? LIMIT 1");
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        $acceptedTerms = filter_var(
            $input['accepted_terms'] ?? $input['terms_accepted'] ?? false,
            FILTER_VALIDATE_BOOLEAN
        );
        if (!$acceptedTerms) {
            send_json(400, [
                'status' => 'error',
                'message' => 'Debes aceptar los Términos y la Política de Privacidad.',
                'code' => 'terms_not_accepted',
            ]);
        }

        $role = 'aprendiz';
        $password = password_hash(bin2hex(random_bytes(16)), PASSWORD_BCRYPT);
        $privacyVersion = trim((string) ($input['privacy_version'] ?? '1.0'));
        $ins = $conn->prepare(
            'INSERT INTO users (name, email, password, role, email_verified, purchases_enabled, terms_accepted, terms_accepted_at, privacy_version, created_at, updated_at)
             VALUES (?, ?, ?, ?, 1, 0, 1, NOW(), ?, NOW(), NOW())'
        );
        $ins->bind_param('sssss', $name, $email, $password, $role, $privacyVersion);
        if (!$ins->execute()) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo crear la cuenta con Google']);
        }
        $userId = (int) $ins->insert_id;
        $ins->close();

        $user = [
            'id' => $userId,
            'name' => $name,
            'email' => $email,
            'role' => $role,
            'email_verified' => 1,
            'purchases_enabled' => 0,
        ];
    } else {
        $upd = $conn->prepare('UPDATE users SET email_verified = 1, name = IF(name IS NULL OR TRIM(name) = \'\', ?, name) WHERE id = ?');
        $uid = (int) $user['id'];
        $upd->bind_param('si', $name, $uid);
        $upd->execute();
        $upd->close();
    }

    send_json(200, [
        'status' => 'success',
        'message' => 'Sesión iniciada con Google',
        'user' => [
            'id' => (int) $user['id'],
            'nombre' => $user['name'] ?? $name,
            'correo' => $user['email'] ?? $email,
            'role' => $user['role'] ?? 'aprendiz',
            'purchases_enabled' => intval($user['purchases_enabled'] ?? 0) === 1,
            'base_api_url' => $baseUrl,
        ],
    ]);
} catch (Throwable $e) {
    send_json(500, [
        'status' => 'error',
        'message' => 'Error interno en login con Google',
        'detail' => $e->getMessage(),
    ]);
}
