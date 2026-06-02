<?php
// 1. Configuración de CORS - Debe ser lo primero que se ejecute
header('Content-Type: application/json');

// 2. Respuesta a Preflight (CORS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// 3. Incluir configuración de base de datos
// ASEGÚRATE de que config.php no tenga ningún 'echo' o 'print'
require_once 'config.php';

// 4. Leer y validar entrada
$input = json_decode(file_get_contents('php://input'), true);

if (!$input) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'No se recibió información o el formato JSON es incorrecto']);
    exit();
}

$email = $input['correo'] ?? $input['email'] ?? '';
$password = $input['password'] ?? '';

if (empty($email) || empty($password)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'El correo y la contraseña son requeridos']);
    exit();
}

// 5. Consulta a la base de datos
$stmt = $conn->prepare("SELECT id, name, email, password, role FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();
$user = $result->fetch_assoc();

// 6. Validación
if (!$user || !password_verify($password, $user['password'])) {
    http_response_code(401);
    echo json_encode(['status' => 'error', 'message' => 'Credenciales inválidas']);
    exit();
}

// 7. Respuesta exitosa
echo json_encode([
    'status' => 'success',
    'message' => 'Sesión iniciada correctamente',
    'user' => [
        'id' => (int)$user['id'],
        'nombre' => $user['name'],
        'correo' => $user['email'],
        'role' => $user['role']
    ]
]);
exit();