<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=UTF-8');

require_once 'config.php';

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit();
}

// Unión flexible de entradas
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);

// Validar que sea POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
}

$nombre = trim($input['nombre'] ?? $input['name'] ?? '');
$email = trim($input['correo'] ?? $input['email'] ?? '');
$password = $input['password'] ?? '';
$role = strtolower(trim($input['role'] ?? 'aprendiz'));

// Validaciones
if (empty($nombre) || empty($email) || empty($password)) {
    send_json(400, ['status' => 'error', 'message' => 'Todos los campos son obligatorios']);
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    send_json(400, ['status' => 'error', 'message' => 'Correo inválido']);
}

// Verificar existencia
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
if ($stmt->get_result()->num_rows > 0) {
    $stmt->close();
    send_json(409, ['status' => 'error', 'message' => 'El correo ya está registrado']);
}
$stmt->close();

// Insertar usuario
$hashedPassword = password_hash($password, PASSWORD_BCRYPT);
$stmt = $conn->prepare("INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)");
$stmt->bind_param("ssss", $nombre, $email, $hashedPassword, $role);

if ($stmt->execute()) {
    send_json(200, [
        'status' => 'success', 
        'message' => 'Cuenta creada correctamente',
        'data' => [
            'nombre' => $nombre, 
            'correo' => $email,
            'base_api_url' => $baseUrl // Útil para que la App sepa la ruta base
        ]
    ]);
} else {
    send_json(500, ['status' => 'error', 'message' => 'Error al registrar: ' . $conn->error]);
}

$stmt->close();
?>