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

echo json_encode([
    'status' => $checks['mysql'] ? 'success' : 'error',
    'message' => $checks['mysql']
        ? 'Backend listo'
        : 'MySQL no responde. Revisa credenciales en Railway Variables.',
    'checks' => $checks,
]);
