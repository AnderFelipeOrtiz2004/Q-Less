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

function qless_web_app_url(): string
{
    $url = trim(load_local_env('FRONTEND_WEB_URL'));
    if ($url !== '') {
        return rtrim($url, '/');
    }

    return 'https://frontend-production-1a74.up.railway.app';
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
    $webUrl = qless_web_app_url();

    return '<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">'
        . '<meta name="viewport" content="width=device-width,initial-scale=1">'
        . '<title>' . htmlspecialchars($title, ENT_QUOTES, 'UTF-8') . '</title></head>'
        . '<body style="margin:0;padding:0;background:#F4F6F4;font-family:Segoe UI,Arial,sans-serif;color:#1A1A1A;">'
        . '<table width="100%" cellpadding="0" cellspacing="0" style="background:#F4F6F4;padding:24px 12px;">'
        . '<tr><td align="center">'
        . '<table width="100%" style="max-width:520px;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 16px rgba(0,0,0,.08);">'
        . '<tr><td style="background:linear-gradient(135deg,#3EC13B,#2FA832);padding:24px;text-align:center;">'
        . '<div style="width:56px;height:56px;border-radius:28px;background:rgba(255,255,255,.18);margin:0 auto 10px;line-height:56px;color:#fff;font-weight:800;">QL</div>'
        . '<h1 style="margin:0;color:#fff;font-size:24px;letter-spacing:1px;">Q-LESS</h1>'
        . '<p style="margin:8px 0 0;color:rgba(255,255,255,.92);font-size:13px;">Tienda escolar · App y web conectadas</p></td></tr>'
        . '<tr><td style="padding:28px 24px;font-size:15px;line-height:1.55;">' . $innerHtml . '</td></tr>'
        . '<tr><td style="padding:0 24px 24px;font-size:12px;color:#888;text-align:center;">'
        . 'También puedes entrar desde la web: <a href="' . htmlspecialchars($webUrl, ENT_QUOTES, 'UTF-8') . '" style="color:#2FA832;">'
        . htmlspecialchars($webUrl, ENT_QUOTES, 'UTF-8') . '</a><br>Equipo Q-LESS</td></tr>'
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
    $webUrl = qless_web_app_url() . '/register';

    $plain = "Hola {$userName},\n\n"
        . "Tu código para restablecer la contraseña en Q-LESS es: {$code}\n\n"
        . "También puedes usar este enlace para cambiar tu contraseña:\n{$link}\n\n"
        . "Versión web: {$webUrl}\n\n"
        . "Válido por 20 minutos. Si no solicitaste este cambio, ignora este mensaje.\n\n— Equipo Q-LESS";

    $html = qless_email_html_wrap(
        'Recuperar contraseña Q-LESS',
        '<p>Hola <strong>' . htmlspecialchars($userName, ENT_QUOTES, 'UTF-8') . '</strong>,</p>'
        . '<p>Recibimos una solicitud para restablecer tu contraseña en Q-LESS.</p>'
        . '<p style="text-align:center;font-size:28px;font-weight:800;letter-spacing:4px;color:#2FA832;margin:20px 0;">'
        . htmlspecialchars($code, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p>O pulsa el botón para abrir el formulario de cambio de contraseña:</p>'
        . qless_email_button('Cambiar contraseña', $link)
        . qless_email_button('Abrir versión web', $webUrl)
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

function qless_purchase_code_email(
    string $userName,
    string $code,
    string $productName,
    int $quantity,
    int $unitPrice,
    int $totalPrice
): array {
    $qtyLabel = $quantity > 1 ? "{$quantity} unidades" : '1 unidad';
    $plain = "Hola {$userName},\n\n"
        . "Tu compra fue ACEPTADA por el administrador.\n\n"
        . "FACTURA Q-LESS\n"
        . "----------------\n"
        . "Producto: {$productName}\n"
        . "Cantidad: {$qtyLabel}\n"
        . "Precio unitario: \${$unitPrice}\n"
        . "PRECIO POR PAGAR: \${$totalPrice}\n\n"
        . "Código de entrega: {$code}\n\n"
        . "Presenta este código para recoger y pagar tu pedido.\n"
        . "También lo verás en Mis compras de la app.\n\n— Equipo Q-LESS";

    $html = qless_email_html_wrap(
        'Compra aceptada — Q-LESS',
        '<p>Hola <strong>' . htmlspecialchars($userName, ENT_QUOTES, 'UTF-8') . '</strong>,</p>'
        . '<p>Tu compra fue <strong style="color:#2FA832;">ACEPTADA</strong> por el administrador.</p>'
        . '<div style="background:#f8faf8;border:1px solid #d8ead8;border-radius:10px;padding:16px;margin:16px 0;">'
        . '<p style="margin:0 0 8px;font-size:13px;color:#666;">Factura</p>'
        . '<p style="margin:0 0 4px;"><strong>' . htmlspecialchars($productName, ENT_QUOTES, 'UTF-8') . '</strong></p>'
        . '<p style="margin:0 0 4px;font-size:14px;">Cantidad: ' . htmlspecialchars($qtyLabel, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p style="margin:0 0 4px;font-size:14px;">Precio unitario: $' . number_format($unitPrice, 0, ',', '.') . '</p>'
        . '<p style="margin:12px 0 0;font-size:18px;font-weight:800;color:#2FA832;">Precio por pagar: $'
        . number_format($totalPrice, 0, ',', '.') . '</p>'
        . '</div>'
        . '<p style="text-align:center;font-size:13px;color:#666;margin-bottom:8px;">Código de compra</p>'
        . '<p style="text-align:center;font-size:32px;font-weight:800;letter-spacing:6px;color:#2FA832;margin:8px 0 20px;">'
        . htmlspecialchars($code, ENT_QUOTES, 'UTF-8') . '</p>'
        . '<p>Presenta este código para recoger y pagar tu pedido.</p>'
    );

    return ['plain' => $plain, 'html' => $html];
}
