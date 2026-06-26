<?php
require_once __DIR__ . '/cors.php';

function send_placeholder_image(): void
{
    header('Content-Type: image/svg+xml; charset=UTF-8');
    header('Cache-Control: public, max-age=3600');
    echo '<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300">
  <rect width="400" height="300" fill="#e8e8e8"/>
  <text x="200" y="150" text-anchor="middle" font-family="Arial,sans-serif" font-size="16" fill="#888">Sin imagen</text>
</svg>';
    exit();
}

$root = realpath(__DIR__);
$requestedPath = isset($_GET['path']) ? (string) $_GET['path'] : '';
$requestedPath = str_replace('\\', '/', $requestedPath);
$requestedPath = preg_replace('/^\/+/', '', $requestedPath);

if ($requestedPath === 'placeholder' || $requestedPath === '') {
    send_placeholder_image();
}

if (strpos($requestedPath, 'q-less/') === 0) {
    $requestedPath = substr($requestedPath, strlen('q-less/'));
}

$basename = basename($requestedPath);
$candidates = array_unique([
    $requestedPath,
    'storage/products/' . $basename,
    'storage/productos/' . $basename,
    'products/' . $basename,
    'productos/' . $basename,
    'storage/' . $basename,
]);

$fullPath = false;
foreach ($candidates as $candidate) {
    $resolved = realpath(__DIR__ . '/' . $candidate);
    if ($resolved && strpos($resolved, $root) === 0 && is_file($resolved)) {
        $fullPath = $resolved;
        break;
    }
}

if (!$fullPath) {
    $hash = pathinfo($requestedPath, PATHINFO_FILENAME);
    if (preg_match('/[a-f0-9]{6,}$/i', $hash, $m)) {
        foreach (['storage/products', 'storage/productos'] as $dir) {
            $glob = glob(__DIR__ . '/' . $dir . '/*' . $m[0] . '.*');
            if ($glob && is_file($glob[0])) {
                $fullPath = realpath($glob[0]);
                break;
            }
        }
    }
}

if (!$fullPath) {
    send_placeholder_image();
}

$mimeType = function_exists('mime_content_type')
    ? mime_content_type($fullPath)
    : 'application/octet-stream';

header('Content-Type: ' . $mimeType);
header('Content-Length: ' . (string) filesize($fullPath));
header('Cache-Control: public, max-age=86400');
readfile($fullPath);
