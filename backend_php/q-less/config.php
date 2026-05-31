<?php
date_default_timezone_set('America/Bogota');
define('DB_HOST', 'localhost');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_NAME', 'q_less_db');
define('DB_PORT', 3306);

$conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT);

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Error DB']);
    die();
}
$conn->set_charset("utf8mb4");
header('Content-Type: application/json');
?>