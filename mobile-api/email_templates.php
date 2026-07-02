<?php

/**
 * Plantillas y enlaces para correos transaccionales Q-LESS.
 */

function qless_public_base_url(): string
{
    global $baseUrl;
    if (!empty($baseUrl)) {
        return rtrim((string) $baseUrl, '/') . '/';
    }

    $envBase = trim(load_local_env('APP_BASE_URL'));
    if ($envBase !== '') {
        return rtrim($envBase, '/') . '/';
    }

    $railway = trim(load_local_env('RAILWAY_PUBLIC_DOMAIN'));
    if ($railway !== '') {
        return 'https://' . $railway . '/';
    }

    return 'http://127.0.0.1/q-less/';
}

function qless_flutter_app_url(): string
{
    $url = trim(load_local_env('FLUTTER_APP_URL'));
    return $url !== '' ? rtrim($url, '/') : '';
}

function qless_reset_password_link(string $email, string $code): string
{
    return qless_public_base_url() . 'reset_password_page.php?'
        . http_build_query(['email' => $email, 'code' => $code]);
}

function qless_verify_email_link(string $email, string $code): string
{
    return qless_public_base_url() . 'verify_email_page.php?'
        . http_build_query(['email' => $email, 'code' => $code]);
}

function qless_email_html_wrap(string $title, string $innerHtml): string
{
    return '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<title>' . htmlspecialchars($title, ENT_QUOTES, 'UTF-8') . '</title></head>'
        . '<body style="margin:0;padding:0;background:#F4F6F4;font-family:Segoe UI,Arial,sans-serif;color:#1A1A1A;">'
        . '<table width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F4;padding:24px 12px;">'
        . '<tr><td align="center">'
        . '<table width="100%" style="max-width:520px;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,.08);">'
        . '<tr><td style="background:linear-gradient(135deg,#3EC13B,#2FA832);padding:24px;text-align:center;">'
        . '<h1 style="margin:0;color:#fff;font-size:24px;letter-spacing:1px;">Q-LESS</h1></td></tr>'
        . '<tr><td style="padding:28px 24px;font-size:15px;line-height:1.55;">' . $innerHtml . '</td></tr>'
        . '<tr><td style="padding:0 24px 24px;font-size:12px;color:#888;text-align:center;">Equipo Q-LESS</td></tr>'
        . '</table></td></tr></table></body></html>';
}

function qless_email_button(string $label, string $url): string
{
    $safeLabel = htmlspecialchars($label, ENT_QUOTES, 'UTF-8');
    $safeUrl = htmlspecialchars($url, ENT_QUOTES, 'UTF-8');

    return '<p style="text-align:center;margin:24px 0;">'
        . '<a href="' . $safeUrl . '" style="display:inline-block;background:#3EC13B;color:#fff;text-decoration:none;'
        . 'padding:14px 28px;border-radius:18px;font-weight:700;font-size:16px;">' . $safeLabel . '</a></p>';
}

function qless_password_reset_email(string $userName, string $code, string $email): array
{
    $link = qless_reset_password_link($email, $code);
    $appUrl = qless_flutter_app_url();

    $plain = "Hola {$userName},\n\n"
        . "Tu código para restablecer la contraseña en Q-LESS es: {$code}\n\n"
        . "También puedes usar este enlace para cambiar tu contraseña:\n{$link}\n\n"
        . "Válido por 20 minutos. Si no solicitaste este cambio, ignora este mensaje.\n\n— Equipo Q-LESS";

    $html = qless_email_html_wrap(
        'Recuperar contraseña Q-LESS',
        '<p>Hola <strong>' . htmlspecialchars($userName, ENT_QUOTES, 'UTF-8') . '</strong>,</p>'
        . '<p>Recibimos una solicitud para restablecer tu contraseña en Q-LESS.</p>'
        . '<p style="text-align:center;font-size:28px;font-weight:800;letter-spacing:4px;color:#2FA832;margin:20px 0;">'
        . htmlspecialchars($code, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p>O pulsa el botón para abrir el formulario de cambio de contraseña:</p>'
        . qless_email_button('Cambiar contraseña', $link)
        . ($appUrl !== '' ? qless_email_button('Abrir aplicación Q-LESS', $appUrl) : '')
        . '<p style="font-size:13px;color:#666;">El código y el enlace vencen en 20 minutos.</p>'
    );

    return ['plain' => $plain, 'html' => $html];
}

function qless_verify_email_content(string $userName, string $code, string $email): array
{
    $link = qless_verify_email_link($email, $code);
    $appUrl = qless_flutter_app_url();

    $plain = "Hola {$userName},\n\n"
        . "Tu código de verificación Gmail para Q-LESS es: {$code}\n\n"
        . "Verifica con este enlace:\n{$link}\n\n"
        . "Válido por 30 minutos.\n\n— Equipo Q-LESS";

    $html = qless_email_html_wrap(
        'Verifica tu correo Q-LESS',
        '<p>Hola <strong>' . htmlspecialchars($userName, ENT_QUOTES, 'UTF-8') . '</strong>,</p>'
        . '<p>Gracias por registrarte en Q-LESS. Verifica tu correo Gmail con este código:</p>'
        . '<p style="text-align:center;font-size:28px;font-weight:800;letter-spacing:4px;color:#2FA832;margin:20px 0;">'
        . htmlspecialchars($code, ENT_QUOTES, 'UTF-8') . '</p>'
        . qless_email_button('Verificar correo', $link)
        . ($appUrl !== '' ? qless_email_button('Abrir aplicación Q-LESS', $appUrl) : '')
        . '<p style="font-size:13px;color:#666;">El código vence en 30 minutos.</p>'
    );

    return ['plain' => $plain, 'html' => $html];
}

function qless_purchase_code_email(string $userName, string $code, string $productSummary): array
{
    $plain = "Hola {$userName},\n\n"
        . "Tu compra fue aprobada.\n\nProducto: {$productSummary}\n"
        . "Código de entrega: {$code}\n\nPresenta este código para recoger tu pedido.\n\n— Equipo Q-LESS";

    $html = qless_email_html_wrap(
        'Compra aprobada Q-LESS',
        '<p>Hola <strong>' . htmlspecialchars($userName, ENT_QUOTES, 'UTF-8') . '</strong>,</p>'
        . '<p>Tu compra fue <strong>aprobada</strong>.</p>'
        . '<p>' . htmlspecialchars($productSummary, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p style="text-align:center;font-size:32px;font-weight:800;letter-spacing:6px;color:#2FA832;margin:20px 0;">'
        . htmlspecialchars($code, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p>Presenta este código para recoger tu pedido. También lo verás en <strong>Mis compras</strong> de la app.</p>'
    );

    return ['plain' => $plain, 'html' => $html];
}
