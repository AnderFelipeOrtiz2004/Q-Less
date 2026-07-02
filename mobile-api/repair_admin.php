<?php
/**
 * Sincroniza el admin con ADMIN_EMAIL y ADMIN_PASSWORD de Railway.
 * Visitar una vez tras deploy: /repair_admin.php
 */
define('QLESS_LIGHTWEIGHT', true);

require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

function repair_send_json(int $code, array $payload): void
{
    http_response_code($code);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

try {
    require_once __DIR__ . '/config.php';
    require_once __DIR__ . '/helpers.php';

    ensure_users_table($conn);
    ensure_default_admin($conn);
    upsert_admin_user(
        $conn,
        'ortizgarciafelipe37@gmail.com',
        admin_env_password(),
        load_local_env('ADMIN_NAME') ?: 'Felipe Ortiz'
    );

    $adminEmail = admin_env_email();
    $roleExpr = users_role_sql_expr();
    $stmt = $conn->prepare(
        "SELECT id, email, ($roleExpr) AS role,
                COALESCE(email_verified, 0) AS email_verified,
                COALESCE(purchases_enabled, 0) AS purchases_enabled
         FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1"
    );
    if (!$stmt) {
        repair_send_json(500, [
            'status' => 'error',
            'message' => 'Error consultando admin',
            'detail' => $conn->error,
        ]);
    }

    $stmt->bind_param('s', $adminEmail);
    $stmt->execute();
    $admin = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    repair_send_json(200, [
        'status' => $admin ? 'success' : 'error',
        'message' => $admin
            ? 'Admin sincronizado. Usa ADMIN_EMAIL y ADMIN_PASSWORD de Railway para iniciar sesión.'
            : 'No se encontró el admin. Verifica ADMIN_EMAIL en Railway.',
        'admin_email' => $adminEmail,
        'smtp_configured' => trim(qless_env('SMTP_USER')) !== ''
            && str_replace(' ', '', trim(qless_env('SMTP_PASS'))) !== '',
        'google_configured' => trim(qless_env('GOOGLE_CLIENT_ID')) !== '',
        'admin' => $admin ? [
            'id' => (int) $admin['id'],
            'email' => $admin['email'],
            'role' => $admin['role'],
            'email_verified' => intval($admin['email_verified']) === 1,
            'purchases_enabled' => intval($admin['purchases_enabled']) === 1,
        ] : null,
    ]);
} catch (Throwable $e) {
    repair_send_json(500, [
        'status' => 'error',
        'message' => 'Error reparando admin',
        'detail' => $e->getMessage(),
    ]);
}
