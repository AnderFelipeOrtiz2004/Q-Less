<?php

function smtp_is_configured(): bool
{
    $user = trim(load_local_env('SMTP_USER'));
    $pass = str_replace(' ', '', trim(load_local_env('SMTP_PASS')));
    $from = trim(load_local_env('SMTP_FROM')) ?: $user;

    return $user !== '' && $pass !== '' && $from !== '';
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
    return stream_context_create([
        'ssl' => [
            'verify_peer' => true,
            'verify_peer_name' => true,
            'allow_self_signed' => false,
        ],
    ]);
}

/**
 * Envía correo vía Gmail SMTP (STARTTLS puerto 587 por defecto).
 */
function send_reset_email(string $toEmail, string $subject, string $body): bool
{
    if (!smtp_is_configured()) {
        return false;
    }

    $smtpHost = trim(load_local_env('SMTP_HOST') ?: 'smtp.gmail.com');
    $smtpPort = (int) (load_local_env('SMTP_PORT') ?: '587');
    $smtpUser = trim(load_local_env('SMTP_USER'));
    $smtpPass = str_replace(' ', '', trim(load_local_env('SMTP_PASS')));
    $fromEmail = trim(load_local_env('SMTP_FROM')) ?: $smtpUser;
    $fromName = load_local_env('SMTP_FROM_NAME') ?: 'Q-LESS';

    $socket = @stream_socket_client(
        "tcp://{$smtpHost}:{$smtpPort}",
        $errno,
        $errstr,
        20,
        STREAM_CLIENT_CONNECT,
        smtp_stream_context()
    );
    if (!$socket) {
        return false;
    }

    stream_set_timeout($socket, 20);

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

        if (!@stream_socket_enable_crypto($socket, true, smtp_crypto_method())) {
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
    $headers = [
        'From: ' . $fromName . ' <' . $fromEmail . '>',
        'To: <' . $toEmail . '>',
        'Subject: ' . $encodedSubject,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 8bit',
    ];

    fwrite($socket, implode("\r\n", $headers) . "\r\n\r\n" . $body . "\r\n.\r\n");
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
    }

    $write('QUIT');
    fclose($socket);
    return true;
}

function send_app_email(string $toEmail, string $subject, string $body): bool
{
    return send_reset_email($toEmail, $subject, $body);
}
