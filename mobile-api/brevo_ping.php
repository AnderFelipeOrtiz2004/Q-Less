<?php
/**
 * Diagnóstico Brevo — abrir una vez tras configurar variables.
 * https://TU-API/brevo_ping.php
 */
header('Content-Type: application/json; charset=utf-8');

define('QLESS_LIGHTWEIGHT', true);
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/mail_helpers.php';

$apiKey = brevo_api_key();
$fromEmail = strtolower(trim(load_local_env('SMTP_FROM')) ?: trim(load_local_env('SMTP_USER')));

$result = [
    'brevo_api_key_present' => $apiKey !== '',
    'brevo_key_prefix' => $apiKey !== '' ? substr($apiKey, 0, 12) . '...' : null,
    'smtp_from' => $fromEmail,
    'curl_available' => function_exists('curl_init'),
    'account' => null,
    'send_test' => null,
];

if ($apiKey === '' || !function_exists('curl_init')) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Falta BREVO_API_KEY o curl en PHP',
        'checks' => $result,
    ], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
    exit;
}

$ch = curl_init('https://api.brevo.com/v3/account');
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => [
        'api-key: ' . $apiKey,
        'Accept: application/json',
    ],
    CURLOPT_TIMEOUT => 20,
]);
$accountBody = curl_exec($ch);
$accountCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$result['account'] = [
    'http_code' => $accountCode,
    'ok' => $accountCode >= 200 && $accountCode < 300,
    'body' => json_decode((string) $accountBody, true) ?: (string) $accountBody,
];

$to = strtolower(trim((string) ($_GET['to'] ?? $fromEmail)));
if ($to !== '' && filter_var($to, FILTER_VALIDATE_EMAIL)) {
    $result['send_test'] = send_email_via_brevo_api_detailed(
        $to,
        'Prueba Brevo Q-LESS',
        "Hola,\n\nPrueba desde brevo_ping.php\n",
        '<p>Prueba desde <strong>brevo_ping.php</strong></p>'
    );
}

$ok = ($result['account']['ok'] ?? false) && (($result['send_test']['ok'] ?? false) || !isset($result['send_test']));

echo json_encode([
    'status' => $ok ? 'success' : 'error',
    'message' => $ok
        ? 'Brevo API responde correctamente.'
        : 'Brevo rechazó la petición. Lee account y send_test.',
    'checks' => $result,
    'tips' => [
        '401' => 'Regenera BREVO_API_KEY (xkeysib) con permiso de envío transaccional.',
        '403' => 'Desactiva bloqueo de IP en Brevo → Seguridad.',
        '400' => 'SMTP_FROM debe ser ortizgarciafelipe37@gmail.com verificado en Remitentes.',
    ],
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
