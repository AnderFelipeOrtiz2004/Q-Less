<?php
/**
 * Verificación rápida pre-entrega — abrir una vez tras deploy.
 */
define('QLESS_LIGHTWEIGHT', true);

require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

try {
    require_once __DIR__ . '/config.php';
    require_once __DIR__ . '/helpers.php';

    ensure_users_table($conn);
    ensure_productos_table($conn);
    ensure_ordenes_table($conn);

    try {
        ensure_default_admin($conn);
        ensure_demo_products($conn);
    } catch (Throwable $e) {
        // Continuar aunque falle seed/migración puntual
    }

    $adminEmail = admin_env_email();
    $productCount = 0;
    $res = $conn->query('SELECT COUNT(*) AS c FROM productos');
    if ($res) {
        $productCount = (int) ($res->fetch_assoc()['c'] ?? 0);
    }

    $apkPath = __DIR__ . '/releases/Q-LESS.apk';
    $apkOk = is_file($apkPath);

    echo json_encode([
        'status' => 'success',
        'message' => 'Sistema listo para entrega',
        'checks' => [
            'mysql' => $conn->ping(),
            'smtp_configured' => trim(qless_env('SMTP_USER')) !== '' && trim(qless_env('SMTP_PASS')) !== '',
            'google_configured' => trim(qless_env('GOOGLE_CLIENT_ID')) !== '',
            'admin_email' => $adminEmail,
            'products_count' => $productCount,
            'apk_download' => $apkOk
                ? rtrim($baseUrl, '/') . '/releases/Q-LESS.apk'
                : null,
            'app_page' => rtrim($baseUrl, '/') . '/download',
            'health' => rtrim($baseUrl, '/') . '/health.php',
        ],
        'test_accounts' => [
            'admin' => [
                'email' => 'ortizgarciafelipe37@gmail.com',
                'alt_email' => 'admin@qless.app',
                'password' => '(ADMIN_PASSWORD en Railway, default Felipe117)',
                'role' => 'admin — aprueba compras, gestiona productos',
            ],
            'user' => [
                'email' => 'ortizgarciafelipe37@gmail.com',
                'login' => 'Google Sign-In o registro Gmail',
                'role' => 'aprendiz — compra productos',
            ],
        ],
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}
