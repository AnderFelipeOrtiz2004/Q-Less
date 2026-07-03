<?php
define('QLESS_LIGHTWEIGHT', true);

require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');
http_response_code(200);

$started = microtime(true);
$checks = ['server' => 'php', 'mysql' => false, 'latency_ms' => 0];

try {
    require_once __DIR__ . '/config.php';
    $checks['mysql'] = $conn instanceof mysqli && $conn->ping();
} catch (Throwable $e) {
    $checks['mysql'] = false;
    $checks['error'] = $e->getMessage();
}

$checks['latency_ms'] = (int) round((microtime(true) - $started) * 1000);
$smtpUser = trim(qless_env('SMTP_USER'));
$smtpPass = str_replace(' ', '', trim(qless_env('SMTP_PASS')));
$smtpFrom = trim(qless_env('SMTP_FROM')) ?: $smtpUser;
$checks['smtp_configured'] = $smtpUser !== '' && $smtpPass !== '' && $smtpFrom !== '';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/mail_helpers.php';
$checks['brevo_api_configured'] = brevo_api_key() !== '';
$checks['smtp_provider'] = strtolower(trim(qless_env('SMTP_PROVIDER')));
$checks['google_configured'] = trim(qless_env('GOOGLE_CLIENT_ID')) !== '';

echo json_encode([
    'status' => $checks['mysql'] ? 'success' : 'error',
    'message' => $checks['mysql']
        ? 'Backend listo'
        : 'MySQL no responde. Revisa credenciales en Railway Variables.',
    'checks' => $checks,
]);
