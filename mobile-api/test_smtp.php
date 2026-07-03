<?php
/**
 * Prueba de correo en producción.
 * https://TU-API/test_smtp.php?to=tu@gmail.com
 */
header('Content-Type: application/json; charset=utf-8');

define('QLESS_LIGHTWEIGHT', true);
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/mail_helpers.php';

$to = strtolower(trim((string) ($_GET['to'] ?? qless_env('SMTP_FROM') ?? '')));
if ($to === '' || !filter_var($to, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'Pasa ?to=tu@gmail.com o configura SMTP_FROM en Railway',
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

$subject = 'Prueba Q-LESS + Brevo';
$body = "Hola,\n\nCorreo de prueba desde Q-LESS en Railway.\n\n— Q-LESS";
$html = '<p>Hola,</p><p>Correo de <strong>prueba</strong> desde Q-LESS en Railway.</p>';

$apiKey = brevo_api_key();
$fromEmail = strtolower(trim(load_local_env('SMTP_FROM')) ?: trim(load_local_env('SMTP_USER')));
$brevoResult = send_email_via_brevo_api_detailed($to, $subject, $body, $html);
$sent = $brevoResult['ok'] === true;

if (!$sent) {
    $sent = send_reset_email($to, $subject, $body, $html);
}

echo json_encode([
    'status' => $sent ? 'success' : 'error',
    'message' => $sent
        ? "Correo enviado a {$to}. Revisa bandeja y Brevo → Transaccional → Tiempo real."
        : 'No se pudo enviar. Lee brevo_detail abajo.',
    'smtp_configured' => smtp_is_configured(),
    'brevo_api_configured' => $apiKey !== '',
    'smtp_from' => $fromEmail,
    'smtp_provider' => trim(load_local_env('SMTP_PROVIDER')),
    'curl_available' => function_exists('curl_init'),
    'brevo_detail' => $brevoResult,
    'transport' => $sent
        ? ($brevoResult['ok'] ? 'brevo_api' : 'smtp')
        : 'failed',
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
