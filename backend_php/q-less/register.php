<?php
/**
 * User Registration Handler
 * Corregido: Errores de sintaxis y comentarios basura eliminados.
 */

header("Content-Type: application/json; charset=UTF-8");

require_once 'config.php';

// Función para formatear la URL del avatar apuntando al backend real
function image_url($path) {
    if (!is_string($path) || trim($path) === '') {
        return 'http://localhost/backend/storage/avatars/default.png';
    }
    $path = trim($path);
    if (preg_match('/^https?:\/\//i', $path)) {
        return $path;
    }
    $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https' : 'http';
    $hostUrl = $scheme . '://' . $_SERVER['HTTP_HOST'];
    $cleanPath = ltrim($path, '/');
    if (strpos($cleanPath, 'backend/') === 0) {
        $cleanPath = substr($cleanPath, 8);
    }
    return $hostUrl . '/backend/' . $cleanPath; 
}

// Check if request method is POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'status' => 'error',
        'message' => 'Método no permitido'
    ]);
    exit();
}

// Get JSON input
$input = json_decode(file_get_contents('php://input'), true);

// Validate input
if (!$input) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'Datos inválidos'
    ]);
    exit();
}

// Extract and trim input
$nombre = isset($input['nombre']) ? trim($input['nombre']) : (isset($input['name']) ? trim($input['name']) : '');
$email = isset($input['correo']) ? trim($input['correo']) : (isset($input['email']) ? trim($input['email']) : '');
$password = isset($input['password']) ? $input['password'] : '';
$role = isset($input['role']) ? strtolower(trim($input['role'])) : 'aprendiz';
$allowedRoles = ['aprendiz', 'instructor'];
if (!in_array($role, $allowedRoles, true)) {
    $role = 'aprendiz';
}

// Validate required fields
if (empty($nombre) || empty($email) || empty($password)) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'Todos los campos son requeridos'
    ]);
    exit();
}

// Validate email format
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'El formato del correo no es válido'
    ]);
    exit();
}

// Validate password length
if (strlen($password) < 6) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'La contraseña debe tener al menos 6 caracteres'
    ]);
    exit();
}

// Check if email already exists
$checkQuery = "SELECT id FROM users WHERE email = ?";
$stmt = $conn->prepare($checkQuery);
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'El correo ya está registrado'
    ]);
    $stmt->close();
    exit();
}
$stmt->close();

// Hash password
$hashedPassword = password_hash($password, PASSWORD_BCRYPT);

// Insert user
$insertQuery = "INSERT INTO users (name, email, password, role, avatar, created_at, updated_at) VALUES (?, ?, ?, ?, '', NOW(), NOW())";
$stmt = $conn->prepare($insertQuery);
$stmt->bind_param("ssss", $nombre, $email, $hashedPassword, $role);

if ($stmt->execute()) {
    $userId = $stmt->insert_id;
    http_response_code(200);
    echo json_encode([
        'status' => 'success',
        'message' => 'Cuenta creada correctamente',
        'data' => [
            'id' => $userId,
            'nombre' => $nombre,
            'correo' => $email,
            'role' => $role,
            'avatar_url' => image_url('')
        ]
    ]);
} else {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Error al crear la cuenta: ' . $stmt->error
    ]);
}

$stmt->close();
$conn->close();
?>