<?php
// CORS headers for Flutter Web
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config.php';

$root = realpath(__DIR__);
$requestedPath = isset($_GET['path']) ? $_GET['path'] : '';
$requestedPath = str_replace('\\', '/', $requestedPath);
$requestedPath = preg_replace('/^\/+/', '', $requestedPath);

if (strpos($requestedPath, 'backend/') === 0) {
    $requestedPath = substr($requestedPath, strlen('backend/'));
}

$fullPath = realpath(__DIR__ . '/' . $requestedPath);

if (!$fullPath || strpos($fullPath, $root) !== 0 || !is_file($fullPath)) {
    http_response_code(404);
    exit();
}

$mimeType = function_exists('mime_content_type')
    ? mime_content_type($fullPath)
    : 'application/octet-stream';

header('Content-Type: ' . $mimeType);
header('Content-Length: ' . filesize($fullPath));
header('Cache-Control: public, max-age=86400');
readfile($fullPath);
?>
