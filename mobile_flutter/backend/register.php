<?php
// 1. Configuración de CORS - Obligatorio al inicio
header('Content-Type: application/json');

// 2. Respuesta a Preflight (CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 3. Incluir base de datos
require_once 'config.php';

// Validar método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Método no permitido']);
    exit();
}

// Leer entrada JSON
$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'JSON inválido']);
    exit();
}

$nombre = trim($input['nombre'] ?? $input['name'] ?? '');
$email = trim($input['correo'] ?? $input['email'] ?? '');
$password = $input['password'] ?? '';
$role = strtolower(trim($input['role'] ?? 'aprendiz'));

// Validaciones
if (empty($nombre) || empty($email) || empty($password)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Todos los campos son obligatorios']);
    exit();
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Correo inválido']);
    exit();
}

// Verificar existencia
$stmt = $conn->prepare("SELECT id FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
if ($stmt->get_result()->num_rows > 0) {
    http_response_code(409); // 409 Conflict es más adecuado para duplicados
    echo json_encode(['status' => 'error', 'message' => 'El correo ya está registrado']);
    $stmt->close();
    exit();
}
$stmt->close();

// Insertar usuario
$hashedPassword = password_hash($password, PASSWORD_BCRYPT);
$stmt = $conn->prepare("INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)");
$stmt->bind_param("ssss", $nombre, $email, $hashedPassword, $role);

if ($stmt->execute()) {
    echo json_encode([
        'status' => 'success', 
        'message' => 'Cuenta creada correctamente',
        'data' => ['nombre' => $nombre, 'correo' => $email]
    ]);
} else {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Error al registrar: ' . $conn->error]);
}

$stmt->close();
$conn->close();
exit();