<?php

function send_reset_email(string $toEmail, string $subject, string $body): bool
{
    $smtpHost = load_local_env('SMTP_HOST') ?: 'smtp.gmail.com';
    $smtpPort = (int) (load_local_env('SMTP_PORT') ?: '587');
    $smtpUser = load_local_env('SMTP_USER');
    $smtpPass = load_local_env('SMTP_PASS');
    $fromEmail = load_local_env('SMTP_FROM') ?: $smtpUser;
    $fromName = load_local_env('SMTP_FROM_NAME') ?: 'Q-LESS';

    if ($smtpUser === '' || $smtpPass === '' || $fromEmail === '') {
        return false;
    }

    $socket = @stream_socket_client(
        "tcp://{$smtpHost}:{$smtpPort}",
        $errno,
        $errstr,
        15,
        STREAM_CLIENT_CONNECT
    );
    if (!$socket) {
        return false;
    }

    stream_set_timeout($socket, 15);

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

    $write('EHLO q-less.local');
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
    }

    $write('STARTTLS');
    if (!$expect($read(), [220])) {
        fclose($socket);
        return false;
    }

    if (!stream_socket_enable_crypto($socket, true, STREAM_CRYPTO_METHOD_TLS_CLIENT)) {
        fclose($socket);
        return false;
    }

    $write('EHLO q-less.local');
    if (!$expect($read(), [250])) {
        fclose($socket);
        return false;
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

    $headers = [
        'From: ' . $fromName . ' <' . $fromEmail . '>',
        'To: <' . $toEmail . '>',
        'Subject: ' . $subject,
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
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
