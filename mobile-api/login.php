<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=UTF-8');

require_once __DIR__ . '/config.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json(int $statusCode, array $payload): void
{
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

try {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
    }

    $json_input = json_decode(file_get_contents('php://input'), true) ?: [];
    $input = array_merge($_REQUEST, is_array($json_input) ? $json_input : []);

    $email = strtolower(trim((string) ($input['email'] ?? $input['correo'] ?? '')));
    $password = (string) ($input['password'] ?? '');

    if ($email === '' || $password === '') {
        send_json(400, ['status' => 'error', 'message' => 'El correo y la contraseña son requeridos']);
    }

    $adminEmail = strtolower(trim(load_local_env('ADMIN_EMAIL') ?: 'admin@qless.app'));
    $isAdminLogin = $email === $adminEmail || $email === 'admin@qless.app';

    if (!is_gmail_email($email) && !$isAdminLogin) {
        send_json(400, ['status' => 'error', 'message' => 'Solo puedes iniciar sesión con un correo Gmail.']);
    }

    $roleExpr = users_role_sql_expr();
    $stmt = $conn->prepare(
        "SELECT id, name, email, password, ($roleExpr) AS role,
                COALESCE(email_verified, 0) AS email_verified,
                COALESCE(purchases_enabled, 0) AS purchases_enabled
         FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1"
    );
    if (!$stmt) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error en la base de datos. Ejecuta setup_database.php o revisa MySQL.',
            'detail' => $conn->error,
        ]);
    }

    $stmt->bind_param('s', $email);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $hash = (string) ($user['password'] ?? '');
    $valid = $hash !== '' && password_verify($password, $hash);

    // Contraseñas antiguas guardadas en texto plano
    if (!$valid && $hash !== '' && hash_equals($hash, $password)) {
        $valid = true;
        $newHash = password_hash($password, PASSWORD_BCRYPT);
        $upd = $conn->prepare('UPDATE users SET password = ? WHERE id = ?');
        if ($upd) {
            $uid = (int) $user['id'];
            $upd->bind_param('si', $newHash, $uid);
            $upd->execute();
            $upd->close();
        }
    }

    if (!$user || !$valid) {
        if (admin_credentials_match($email, $password)) {
            ensure_default_admin($conn);

            $retry = $conn->prepare(
                "SELECT id, name, email, password, ($roleExpr) AS role,
                        COALESCE(email_verified, 0) AS email_verified,
                        COALESCE(purchases_enabled, 0) AS purchases_enabled
                 FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1"
            );
            $retry->bind_param('s', $email);
            $retry->execute();
            $user = $retry->get_result()->fetch_assoc();
            $retry->close();

            $hash = (string) ($user['password'] ?? '');
            $valid = $user && $hash !== '' && password_verify($password, $hash);
        }
    }

    if (!$user || !$valid) {
        if (!$user) {
            send_json(401, [
                'status' => 'error',
                'message' => 'No existe una cuenta con ese correo. Regístrate primero.',
                'code' => 'user_not_found',
            ]);
        }

        send_json(401, ['status' => 'error', 'message' => 'Contraseña incorrecta']);
    }

    $adminEmail = strtolower(trim(load_local_env('ADMIN_EMAIL') ?: ''));
    $isDesignatedAdmin = $adminEmail !== '' && strtolower((string) $user['email']) === $adminEmail;

    if (intval($user['email_verified']) !== 1) {
        if ($isDesignatedAdmin || strtolower((string) ($user['role'] ?? '')) === 'admin') {
            $fix = $conn->prepare(
                'UPDATE users SET email_verified = 1, purchases_enabled = 1 WHERE id = ?'
            );
            if ($fix) {
                $uid = (int) $user['id'];
                $fix->bind_param('i', $uid);
                $fix->execute();
                $fix->close();
            }
            $user['email_verified'] = 1;
            $user['purchases_enabled'] = 1;
        } else {
            send_json(403, [
                'status' => 'error',
                'message' => 'Debes verificar tu correo Gmail antes de iniciar sesión.',
                'code' => 'email_not_verified',
            ]);
        }
    }

    send_json(200, [
        'status' => 'success',
        'message' => 'Sesión iniciada correctamente',
        'user' => [
            'id' => (int) $user['id'],
            'nombre' => $user['name'],
            'correo' => $user['email'],
            'role' => $user['role'] ?? 'aprendiz',
            'email_verified' => intval($user['email_verified']) === 1,
            'purchases_enabled' => intval($user['purchases_enabled']) === 1,
            'base_api_url' => $baseUrl,
        ],
    ]);
} catch (Throwable $e) {
    send_json(500, [
        'status' => 'error',
        'message' => 'Error interno en login',
        'detail' => $e->getMessage(),
    ]);
}