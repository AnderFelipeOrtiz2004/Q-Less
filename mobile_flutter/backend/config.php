<?php
date_default_timezone_set('America/Bogota');
ini_set('display_errors', '0');
error_reporting(E_ALL);
ini_set('default_socket_timeout', '5');

$dbHost = '127.0.0.1';
$dbUser = 'root';
$dbPass = '';
$dbName = 'q_less_db';
$dbPort = 3306;

$conn = mysqli_init();
if ($conn === false) {
    json_connection_error('No se pudo inicializar MySQL');
}

$conn->options(MYSQLI_OPT_CONNECT_TIMEOUT, 5);
$conn->options(MYSQLI_OPT_READ_TIMEOUT, 15);

if (!$conn->real_connect($dbHost, $dbUser, $dbPass, $dbName, $dbPort)) {
    json_connection_error('Error de conexión a la base de datos. Verifica que MySQL esté activo en XAMPP.');
}

$conn->set_charset('utf8mb4');

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$httpHost = $_SERVER['HTTP_HOST'] ?? '127.0.0.1';
if (strcasecmp($httpHost, 'localhost') === 0) {
    $httpHost = '127.0.0.1';
}
$docRoot = realpath($_SERVER['DOCUMENT_ROOT'] ?? '');
$appRoot = realpath(__DIR__);
$root_dir = '/q-less/';

if ($docRoot && $appRoot) {
    $docRootNorm = str_replace('\\', '/', $docRoot);
    $appRootNorm = str_replace('\\', '/', $appRoot);
    if (str_starts_with($appRootNorm, $docRootNorm)) {
        $relative = substr($appRootNorm, strlen($docRootNorm));
        $root_dir = '/' . trim($relative, '/') . '/';
    }
}

$baseUrl = $scheme . '://' . $httpHost . $root_dir;

require_once __DIR__ . '/helpers.php';

foreach (['storage', 'storage/products', 'storage/avatars'] as $dir) {
    $fullDir = __DIR__ . '/' . $dir;
    if (!is_dir($fullDir)) {
        @mkdir($fullDir, 0775, true);
    }
}

function json_connection_error(string $message): void
{
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=UTF-8');
    }
    http_response_code(503);
    echo json_encode([
        'status' => 'error',
        'message' => $message,
    ]);
    exit();
}
