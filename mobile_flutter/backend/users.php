<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit();
}

// Asegurar esquema de usuario
function setup_user_schema($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL,
        role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz',
        avatar_path VARCHAR(255) NULL,
        description TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
}
setup_user_schema($conn);

function format_user_response(array $user): array
{
    return [
        'id' => (int) $user['id'],
        'nombre' => $user['name'] ?? '',
        'correo' => $user['email'] ?? '',
        'role' => $user['role'] ?? 'aprendiz',
        'avatar_path' => $user['avatar_path'] ?? null,
        'avatar_url' => resolve_image_url($user['avatar_path'] ?? null),
        'description' => $user['description'] ?? '',
        'created_at' => $user['created_at'] ?? null,
    ];
}

$method = $_SERVER['REQUEST_METHOD'];
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);

// --- GET: OBTENER PERFIL ---
if ($method === 'GET') {
    $userId = intval($_GET['id'] ?? 0);
    if ($userId <= 0) send_json(400, ['status' => 'error', 'message' => 'ID de usuario requerido']);

    $stmt = $conn->prepare("SELECT id, name, email, role, avatar_path, description, created_at FROM users WHERE id = ?");
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'Usuario no encontrado']);
    }

    send_json(200, ['status' => 'success', 'data' => format_user_response($user)]);
}

// --- PUT: ACTUALIZAR PERFIL ---
if ($method === 'PUT') {
    $userId = intval($input['id'] ?? 0);
    if ($userId <= 0) send_json(400, ['status' => 'error', 'message' => 'ID de usuario requerido']);

    $fields = [];
    $types = '';
    $values = [];

    if (!empty($input['nombre'])) {
        $fields[] = 'name = ?'; $types .= 's'; $values[] = trim($input['nombre']);
    }
    if (isset($input['description'])) {
        $fields[] = 'description = ?'; $types .= 's'; $values[] = trim($input['description']);
    }
    if (!empty($input['password'])) {
        if (strlen($input['password']) < 6) send_json(400, ['status' => 'error', 'message' => 'Contraseña muy corta']);
        $fields[] = 'password = ?'; $types .= 's'; $values[] = password_hash($input['password'], PASSWORD_BCRYPT);
    }

    if (!empty($input['avatar_base64'])) {
        $avatarDir = __DIR__ . '/storage/avatars';
        if (!is_dir($avatarDir)) mkdir($avatarDir, 0775, true);
        $decoded = base64_decode(preg_replace('#^data:image/[^;]+;base64,#', '', $input['avatar_base64']));
        $fileName = 'avatar_' . $userId . '_' . time() . '.png';
        $filePath = $avatarDir . '/' . $fileName;
        
        if (file_put_contents($filePath, $decoded)) {
            $fields[] = 'avatar_path = ?'; $types .= 's'; $values[] = 'storage/avatars/' . $fileName;
        }
    }

    if (empty($fields)) send_json(400, ['status' => 'error', 'message' => 'No hay datos para actualizar']);

    $sql = 'UPDATE users SET ' . implode(', ', $fields) . ', updated_at = NOW() WHERE id = ?';
    $types .= 'i'; $values[] = $userId;

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$values);
    
    if ($stmt->execute()) {
        $stmt->close();
        $fetch = $conn->prepare('SELECT id, name, email, role, avatar_path, description, created_at FROM users WHERE id = ?');
        $fetch->bind_param('i', $userId);
        $fetch->execute();
        $updated = $fetch->get_result()->fetch_assoc();
        $fetch->close();

        send_json(200, [
            'status' => 'success',
            'message' => 'Perfil actualizado correctamente',
            'data' => $updated ? format_user_response($updated) : null,
        ]);
    } else {
        $stmt->close();
        send_json(500, ['status' => 'error', 'message' => 'Error al actualizar en base de datos']);
    }
}

send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
?>