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

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit();
}

$material = isset($_GET['material']) ? trim($_GET['material']) : '';
if ($material === '') {
    send_json(400, [
        'success' => false,
        'error' => 'Material requerido'
    ]);
}

$search = '%' . $material . '%';
$stmt = $conn->prepare("SELECT nombre, stock FROM productos WHERE nombre LIKE ? OR descripcion LIKE ? ORDER BY stock DESC LIMIT 1");
if (!$stmt) {
    send_json(500, [
        'success' => false,
        'error' => 'Error al preparar la consulta'
    ]);
}

$stmt->bind_param('ss', $search, $search);
$stmt->execute();
$result = $stmt->get_result();
$product = $result->fetch_assoc();
$stmt->close();

if (!$product || intval($product['stock']) <= 0) {
    send_json(200, [
        'success' => false,
        'material' => $material,
        'cantidad' => 0
    ]);
}

send_json(200, [
    'success' => true,
    'material' => $product['nombre'],
    'cantidad' => intval($product['stock'])
]);
?>
