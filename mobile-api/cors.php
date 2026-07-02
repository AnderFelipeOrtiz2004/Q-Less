<?php
/**
 * CORS para la API Q-Less.
 * En XAMPP/Apache, .htaccess (mod_headers) ya puede enviar CORS; no duplicar (*, *).
 */
function qless_cors_headers_sent(): bool
{
    foreach (headers_list() as $header) {
        if (stripos($header, 'Access-Control-Allow-Origin:') === 0) {
            return true;
        }
    }
    return false;
}

if (!qless_cors_headers_sent()) {
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Origin, Accept');
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit();
}
