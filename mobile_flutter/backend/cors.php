<?php
/**
 * Preflight OPTIONS para la API Q-Less.
 * Las cabeceras CORS las define .htaccess (una sola fuente).
 */
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(200);
    exit();
}
