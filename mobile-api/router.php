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

if ($uri === '/download' || $uri === '/download.html' || $uri === '/app' || $uri === '/apk') {
    $page = __DIR__ . '/download.html';
    if (is_file($page)) {
        header('Content-Type: text/html; charset=utf-8');
        readfile($page);
        return true;
    }
}

// APK público para instalación
if (preg_match('#^/releases/(.+\.apk)$#i', $uri, $m)) {
    $apk = __DIR__ . '/releases/' . basename($m[1]);
    if (is_file($apk)) {
        header('Content-Type: application/vnd.android.package-archive');
        header('Content-Disposition: attachment; filename="' . basename($apk) . '"');
        header('Content-Length: ' . (string) filesize($apk));
        readfile($apk);
        return true;
    }
    http_response_code(404);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['status' => 'error', 'message' => 'APK no encontrado. Sube releases/Q-LESS.apk al servidor.']);
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

// Compatibilidad: /products/* y /productos/* -> storage/productos|products/*
if (preg_match('#^/(?:products|productos)/(.+)$#', $uri, $m)) {
    $file = basename($m[1]);
    foreach (['storage/productos', 'storage/products'] as $dir) {
        $candidate = __DIR__ . '/' . $dir . '/' . $file;
        if (is_file($candidate)) {
            $mime = mime_content_type($candidate) ?: 'application/octet-stream';
            header('Content-Type: ' . $mime);
            readfile($candidate);
            return true;
        }
    }
}

// Ejecutar endpoints .php directamente (repair_admin, login, etc.)
if (preg_match('#^/([A-Za-z0-9_-]+\.php)$#', $uri, $m)) {
    $script = __DIR__ . '/' . $m[1];
    if (is_file($script)) {
        require $script;
        return true;
    }
}

// Dejar que PHP sirva archivos estáticos y ejecute .php
return false;
