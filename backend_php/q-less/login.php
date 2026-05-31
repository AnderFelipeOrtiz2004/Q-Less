<?php
// Limpieza de buffer para asegurar JSON puro
ob_start();
clearstatcache();

// Configuración para evitar errores que rompan el JSON
error_reporting(0);
ini_set('display_errors', 0);

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

// Validar conexión
if (isset($conn_error_msg) || !$conn) {
    ob_clean();
    echo json_encode(['status' => 'error', 'message' => 'Error de BD']);
    exit();
}

// Validar método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ob_clean();
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Método no permitido']);
    exit();
}

$input = json_decode(file_get_contents('php://input'), true);
$email = isset($input['correo']) ? trim($input['correo']) : (isset($input['email']) ? trim($input['email']) : '');
$password = isset($input['password']) ? $input['password'] : '';

if (empty($email) || empty($password)) {
    ob_clean();
    echo json_encode(['status' => 'error', 'message' => 'Campos vacíos']);
    exit();
}

// CORRECCIÓN: Quitamos ', avatar' para evitar el Error 500 si la columna no existe en la BD
$stmt = $conn->prepare("SELECT id, name, email, password, role FROM users WHERE email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows === 0) {
    ob_clean();
    echo json_encode(['status' => 'error', 'message' => 'Usuario no encontrado']);
    exit();
}

$user = $result->fetch_assoc();
$stmt->close();

// Verificar contraseña
if (!password_verify($password, $user['password'])) {
    ob_clean();
    echo json_encode(['status' => 'error', 'message' => 'Contraseña incorrecta']);
    exit();
}

// Éxito
ob_clean();
echo json_encode([
    'status' => 'success',
    'message' => 'Bienvenido',
    'user' => [
        'id' => (int)$user['id'],
        'nombre' => $user['name'],
        'correo' => $user['email'],
        'role' => $user['role'],
        'avatar_url' => image_url('') // Envía la imagen predeterminada de forma segura
    ]
]);
exit();
?>