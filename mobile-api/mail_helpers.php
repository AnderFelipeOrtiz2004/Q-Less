<?php

function smtp_is_configured(): bool
{
    $user = trim(load_local_env('SMTP_USER'));
    $pass = str_replace(' ', '', trim(load_local_env('SMTP_PASS')));
    $from = trim(load_local_env('SMTP_FROM')) ?: $user;

    return $user !== '' && $pass !== '' && $from !== '';
}

function smtp_default_host(): string
{
    $provider = strtolower(trim(load_local_env('SMTP_PROVIDER')));
    if ($provider === 'brevo' || $provider === 'sendinblue') {
        return 'smtp-relay.brevo.com';
    }

    return 'smtp.gmail.com';
}

function smtp_crypto_method(): int
{
    if (defined('STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT')) {
        return STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT | STREAM_CRYPTO_METHOD_TLSv1_3_CLIENT;
    }
    if (defined('STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT')) {
        return STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT;
    }

    return STREAM_CRYPTO_METHOD_TLS_CLIENT;
}

function smtp_stream_context()
{
    $provider = strtolower(trim(load_local_env('SMTP_PROVIDER')));
    $strictSsl = !in_array($provider, ['brevo', 'sendinblue'], true);

    return stream_context_create([
        'ssl' => [
            'verify_peer' => $strictSsl,
            'verify_peer_name' => $strictSsl,
            'allow_self_signed' => !$strictSsl,
        ],
    ]);
}

function brevo_api_key(): string
{
    $apiKey = trim(load_local_env('BREVO_API_KEY'));
    if ($apiKey !== '') {
        return $apiKey;
    }

    $smtpPass = str_replace(' ', '', trim(load_local_env('SMTP_PASS')));
    if (preg_match('/^xkeysib-/i', $smtpPass)) {
        return $smtpPass;
    }

    return '';
}

/**
 * Envía correo vía SMTP (Gmail, Brevo u otro).
 * Si $htmlBody no es null, envía multipart/alternative (texto + HTML).
 */
function send_reset_email(string $toEmail, string $subject, string $body, ?string $htmlBody = null): bool
{
    if (!smtp_is_configured()) {
        return false;
    }

    $smtpHost = trim(load_local_env('SMTP_HOST') ?: smtp_default_host());
    $smtpPort = (int) (load_local_env('SMTP_PORT') ?: '587');
    $smtpUser = trim(load_local_env('SMTP_USER'));
    $smtpPass = str_replace(' ', '', trim(load_local_env('SMTP_PASS')));
    $fromEmail = trim(load_local_env('SMTP_FROM')) ?: $smtpUser;
    $fromName = load_local_env('SMTP_FROM_NAME') ?: 'Q-LESS';

    $target = $smtpPort === 465
        ? "ssl://{$smtpHost}:{$smtpPort}"
        : "tcp://{$smtpHost}:{$smtpPort}";

    $socket = @stream_socket_client(
        $target,
        $errno,
        $errstr,
        25,
        STREAM_CLIENT_CONNECT,
        smtp_stream_context()
    );
    if (!$socket) {
        return false;
    }

    stream_set_timeout($socket, 25);

    $read = function () use ($socket): string {
        $data = '';
        while ($line = fgets($socket, 515)) {
            $data .= $line;
            if (isset($line[3]) && $line[3] === ' ') {
                break;
            }
        }
        return $data;
    };

    $write = function (string $cmd) use ($socket): void {
        fwrite($socket, $cmd . "\r\n");
    };

    $expect = function (string $response, array $codes) use ($read): bool {
        $code = (int) substr(trim($response), 0, 3);
        return in_array($code, $codes, true);
    };

    if (!$expect($read(), [220])) {
        fclose($socket);
        return false;
    }

    $write('EHLO q-less.app');
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
    }

    if ($smtpPort === 587) {
        $write('STARTTLS');
        if (!$expect($read(), [220])) {
            fclose($socket);
            return false;
        }

        $cryptoOk = @stream_socket_enable_crypto($socket, true, smtp_crypto_method());
        if (!$cryptoOk) {
            $cryptoOk = @stream_socket_enable_crypto(
                $socket,
                true,
                STREAM_CRYPTO_METHOD_TLSv1_2_CLIENT
            );
        }
        if (!$cryptoOk) {
            fclose($socket);
            return false;
        }

        $write('EHLO q-less.app');
        if (!$expect($read(), [250])) {
            fclose($socket);
            return false;
        }
    }

    $write('AUTH LOGIN');
    if (!$expect($read(), [334])) {
        fclose($socket);
        return false;
    }

    $write(base64_encode($smtpUser));
    if (!$expect($read(), [334])) {
        fclose($socket);
        return false;
    }

    $write(base64_encode($smtpPass));
    if (!$expect($read(), [235])) {
        fclose($socket);
        return false;
    }

    $write('MAIL FROM:<' . $fromEmail . '>');
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
    }

    $write('RCPT TO:<' . $toEmail . '>');
    if (!$expect($read(), [250, 251])) {
        fclose($socket);
        return false;
    }

    $write('DATA');
    if (!$expect($read(), [354])) {
        fclose($socket);
        return false;
    }

    $encodedSubject = '=?UTF-8?B?' . base64_encode($subject) . '?=';
    $boundary = 'qless_' . bin2hex(random_bytes(8));

    $headers = [
        'From: ' . $fromName . ' <' . $fromEmail . '>',
        'To: <' . $toEmail . '>',
        'Subject: ' . $encodedSubject,
        'MIME-Version: 1.0',
    ];

    if ($htmlBody !== null && $htmlBody !== '') {
        $headers[] = 'Content-Type: multipart/alternative; boundary="' . $boundary . '"';
        $message = implode("\r\n", $headers) . "\r\n\r\n"
            . '--' . $boundary . "\r\n"
            . "Content-Type: text/plain; charset=UTF-8\r\n"
            . "Content-Transfer-Encoding: 8bit\r\n\r\n"
            . $body . "\r\n\r\n"
            . '--' . $boundary . "\r\n"
            . "Content-Type: text/html; charset=UTF-8\r\n"
            . "Content-Transfer-Encoding: 8bit\r\n\r\n"
            . $htmlBody . "\r\n\r\n"
            . '--' . $boundary . '--';
    } else {
        $headers[] = 'Content-Type: text/plain; charset=UTF-8';
        $headers[] = 'Content-Transfer-Encoding: 8bit';
        $message = implode("\r\n", $headers) . "\r\n\r\n" . $body;
    }

    fwrite($socket, $message . "\r\n.\r\n");
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
    }

    $write('QUIT');
    fclose($socket);
    return true;
}

function send_app_email(string $toEmail, string $subject, string $body, ?string $htmlBody = null): bool
{
    if (brevo_api_key() !== '' && send_email_via_brevo_api($toEmail, $subject, $body, $htmlBody)) {
        return true;
    }

    if (send_reset_email($toEmail, $subject, $body, $htmlBody)) {
        return true;
    }

    if (brevo_api_key() !== '') {
        return send_email_via_brevo_api($toEmail, $subject, $body, $htmlBody);
    }

    return false;
}

function brevo_api_is_configured(): bool
{
    return brevo_api_key() !== '';
}

function send_email_via_brevo_api(string $toEmail, string $subject, string $body, ?string $htmlBody = null): bool
{
    $apiKey = brevo_api_key();
    if ($apiKey === '') {
        return false;
    }

    $fromEmail = trim(load_local_env('SMTP_FROM')) ?: trim(load_local_env('SMTP_USER'));
    $fromName = load_local_env('SMTP_FROM_NAME') ?: 'Q-LESS';
    if ($fromEmail === '' || !filter_var($fromEmail, FILTER_VALIDATE_EMAIL)) {
        return false;
    }

    $payload = [
        'sender' => ['name' => $fromName, 'email' => $fromEmail],
        'to' => [['email' => $toEmail]],
        'subject' => $subject,
        'textContent' => $body,
    ];
    if ($htmlBody !== null && $htmlBody !== '') {
        $payload['htmlContent'] = $htmlBody;
    }

    if (!function_exists('curl_init')) {
        return false;
    }

    $ch = curl_init('https://api.brevo.com/v3/smtp/email');
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER => [
            'api-key: ' . $apiKey,
            'Content-Type: application/json',
            'Accept: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($payload, JSON_UNESCAPED_UNICODE),
        CURLOPT_TIMEOUT => 30,
    ]);
    curl_exec($ch);
    $httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    return $httpCode >= 200 && $httpCode < 300;
}
