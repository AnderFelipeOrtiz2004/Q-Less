<?php
/**
 * Sincroniza el admin con ADMIN_EMAIL y ADMIN_PASSWORD de Railway.
 * Visitar una vez tras deploy: /repair_admin.php
 */
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/mail_helpers.php';

$adminEmail = strtolower(trim(load_local_env('ADMIN_EMAIL') ?: 'felipeortiz37@gmail.com'));
ensure_default_admin($conn);

$roleExpr = users_role_sql_expr();
$stmt = $conn->prepare(
    "SELECT id, email, ($roleExpr) AS role, email_verified, purchases_enabled
     FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1"
);
$stmt->bind_param('s', $adminEmail);
$stmt->execute();
$admin = $stmt->get_result()->fetch_assoc();
$stmt->close();

echo json_encode([
    'status' => $admin ? 'success' : 'error',
    'message' => $admin
        ? 'Admin sincronizado. Usa ADMIN_EMAIL y ADMIN_PASSWORD de Railway para iniciar sesión.'
        : 'No se encontró el admin. Verifica ADMIN_EMAIL en Railway.',
    'admin_email' => $adminEmail,
    'smtp_configured' => smtp_is_configured(),
    'admin' => $admin ? [
        'id' => (int) $admin['id'],
        'email' => $admin['email'],
        'role' => $admin['role'],
        'email_verified' => intval($admin['email_verified']) === 1,
        'purchases_enabled' => intval($admin['purchases_enabled']) === 1,
    ] : null,
], JSON_UNESCAPED_UNICODE);
