<?php
/**
 * Router para PHP built-in server (Railway). Sustituye reglas .htaccess de Apache.
 */
require_once __DIR__ . '/cors.php';

$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$uri = '/' . trim((string) $uri, '/');

if ($uri === '/') {
    require __DIR__ . '/health.php';
    return true;
}

// storage/* inexistente -> image.php (placeholder o búsqueda alternativa)
if (preg_match('#^/storage/.+#', $uri)) {
    $local = __DIR__ . $uri;
    if (!is_file($local)) {
        $_GET['path'] = ltrim($uri, '/');
        require __DIR__ . '/image.php';
        return true;
    }
}

// Compatibilidad: /products/* -> storage/products/*
if (preg_match('#^/products/(.+)$#', $uri, $m)) {
    $candidate = __DIR__ . '/storage/products/' . basename($m[1]);
    if (is_file($candidate)) {
        $mime = mime_content_type($candidate) ?: 'application/octet-stream';
        header('Content-Type: ' . $mime);
        readfile($candidate);
        return true;
    }
}

// Dejar que PHP sirva archivos estáticos y ejecute .php
return false;
