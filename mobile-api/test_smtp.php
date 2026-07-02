<?php
/**
 * Prueba de correo en producción — usar una vez y luego borrar o restringir.
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

$sent = send_app_email($to, $subject, $body, $html);
$viaApi = brevo_api_is_configured();

echo json_encode([
    'status' => $sent ? 'success' : 'error',
    'message' => $sent
        ? "Correo enviado a {$to}. Revisa bandeja y Brevo → Transaccional → Tiempo real."
        : 'No se pudo enviar. Revisa variables SMTP/BREVO_API_KEY y remitente verificado en Brevo.',
    'smtp_configured' => smtp_is_configured(),
    'brevo_api_configured' => $viaApi,
    'transport' => $viaApi ? 'brevo_api_or_smtp' : 'smtp',
], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
