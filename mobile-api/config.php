<?php
date_default_timezone_set('America/Bogota');
ini_set('display_errors', '0');
error_reporting(E_ALL);
ini_set('default_socket_timeout', '10');

function qless_env(string $key, string $default = ''): string
{
    static $cache = null;
    if ($cache === null) {
        $cache = [];
        $envFile = __DIR__ . '/.env';
        if (is_file($envFile)) {
            $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];
            foreach ($lines as $line) {
                $line = trim($line);
                if ($line === '' || $line[0] === '#') {
                    continue;
                }
                $parts = explode('=', $line, 2);
                if (count($parts) === 2) {
                    $cache[trim($parts[0])] = trim($parts[1], " \t\"'");
                }
            }
        }
    }

    $aliases = [
        'DB_HOST' => ['MYSQLHOST', 'MYSQL_HOST'],
        'DB_USER' => ['MYSQLUSER', 'MYSQL_USER'],
        'DB_PASS' => ['MYSQLPASSWORD', 'MYSQL_PASSWORD'],
        'DB_NAME' => ['MYSQLDATABASE', 'MYSQL_DATABASE'],
        'DB_PORT' => ['MYSQLPORT', 'MYSQL_PORT'],
    ];

    $value = $cache[$key] ?? getenv($key);
    if (($value === false || $value === null || $value === '') && isset($aliases[$key])) {
        foreach ($aliases[$key] as $alias) {
            $aliasValue = $cache[$alias] ?? getenv($alias);
            if ($aliasValue !== false && $aliasValue !== null && $aliasValue !== '') {
                $value = $aliasValue;
                break;
            }
        }
    }

    if ($value === false || $value === null || $value === '') {
        return $default;
    }

    return (string) $value;
}

$dbHost = qless_env('DB_HOST', qless_env('MYSQLHOST', '127.0.0.1'));
$dbUser = qless_env('DB_USER', qless_env('MYSQLUSER', 'root'));
$dbPass = qless_env('DB_PASS', qless_env('MYSQLPASSWORD', ''));
$dbName = qless_env('DB_NAME', qless_env('MYSQLDATABASE', 'railway'));
$dbPort = (int) qless_env('DB_PORT', qless_env('MYSQLPORT', '3306'));
$dbSsl = strtolower(qless_env('DB_SSL', 'false')) === 'true';

$conn = mysqli_init();
if ($conn === false) {
    if (defined('QLESS_LIGHTWEIGHT') && QLESS_LIGHTWEIGHT) {
        throw new RuntimeException('No se pudo inicializar MySQL');
    }
    json_connection_error('No se pudo inicializar MySQL');
}

$conn->options(MYSQLI_OPT_CONNECT_TIMEOUT, 10);
$conn->options(MYSQLI_OPT_READ_TIMEOUT, 20);

$connectFlags = 0;
if ($dbSsl && defined('MYSQLI_CLIENT_SSL')) {
    $conn->ssl_set(null, null, null, null, null);
    $connectFlags = MYSQLI_CLIENT_SSL;
}

$connected = $conn->real_connect($dbHost, $dbUser, $dbPass, $dbName, $dbPort, null, $connectFlags);
if (!$connected && $dbHost !== 'localhost') {
    $connectFlags = 0;
    $connected = $conn->real_connect($dbHost, $dbUser, $dbPass, $dbName, $dbPort);
}

if (!$connected) {
    $dbError = 'Error de conexión a la base de datos. Revisa las variables MYSQL* en Railway.';
    if (defined('QLESS_LIGHTWEIGHT') && QLESS_LIGHTWEIGHT) {
        throw new RuntimeException($dbError);
    }
    json_connection_error($dbError);
}

$conn->set_charset('utf8mb4');

$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$httpHost = $_SERVER['HTTP_HOST'] ?? '127.0.0.1';
if (strcasecmp($httpHost, 'localhost') === 0) {
    $httpHost = '127.0.0.1';
}

$envBaseUrl = qless_env('APP_BASE_URL', '');
$railwayDomain = qless_env('RAILWAY_PUBLIC_DOMAIN', getenv('RAILWAY_PUBLIC_DOMAIN') ?: '');

if ($envBaseUrl !== '') {
    $baseUrl = rtrim($envBaseUrl, '/') . '/';
} elseif ($railwayDomain !== '') {
    $baseUrl = 'https://' . $railwayDomain . '/';
} else {
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
}

if (!defined('QLESS_LIGHTWEIGHT') || !QLESS_LIGHTWEIGHT) {
    require_once __DIR__ . '/helpers.php';

    ensure_users_table($conn);
    ensure_ordenes_table($conn);
    ensure_default_admin($conn);
    ensure_demo_products($conn);

    foreach (['storage', 'storage/products', 'storage/avatars'] as $dir) {
        $fullDir = __DIR__ . '/' . $dir;
        if (!is_dir($fullDir)) {
            @mkdir($fullDir, 0775, true);
        }
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
