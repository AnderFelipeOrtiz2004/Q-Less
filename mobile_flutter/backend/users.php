<?php
/**
 * User Profile Handler
 *
 * Provides user profile read and update operations.
 */

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

function get_input() {
    $input = json_decode(file_get_contents('php://input'), true);
    return is_array($input) ? $input : [];
}

function ensure_users_table($conn) {
    $create = "CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL,
        role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz',
        avatar_path VARCHAR(255) NULL,
        description TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_role (role)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

    if ($conn->query($create) === false) {
        send_json(500, ['status' => 'error', 'message' => 'No se pudo preparar la tabla users: ' . $conn->error]);
    }
}

ensure_users_table($conn);

// Ensure optional profile columns exist
$roleColumn = $conn->query("SHOW COLUMNS FROM users LIKE 'role'");
if ($roleColumn && $roleColumn->num_rows === 0) {
    $conn->query("ALTER TABLE users ADD COLUMN role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz' AFTER password");
}
$avatarColumn = $conn->query("SHOW COLUMNS FROM users LIKE 'avatar_path'");
if ($avatarColumn && $avatarColumn->num_rows === 0) {
    $conn->query("ALTER TABLE users ADD COLUMN avatar_path VARCHAR(255) NULL AFTER email");
}
$descriptionColumn = $conn->query("SHOW COLUMNS FROM users LIKE 'description'");
if ($descriptionColumn && $descriptionColumn->num_rows === 0) {
    $conn->query("ALTER TABLE users ADD COLUMN description TEXT NULL AFTER avatar_path");
}

$method = $_SERVER['REQUEST_METHOD'];
$input = get_input();

if ($method === 'GET') {
    $userId = isset($_GET['id']) ? intval($_GET['id']) : 0;
    if ($userId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'User id required']);
    }

    $stmt = $conn->prepare("SELECT id, name, email, role, avatar_path, description, created_at FROM users WHERE id = ?");
    if (!$stmt) {
        send_json(500, ['status' => 'error', 'message' => 'Error al preparar la consulta']);
    }
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'Usuario no encontrado. Inicia sesion de nuevo.']);
    }

    send_json(200, [
        'status' => 'success',
        'data' => [
            'id' => $user['id'],
            'nombre' => $user['name'],
            'correo' => $user['email'],
            'role' => $user['role'] ?? 'aprendiz',
            'avatar_path' => $user['avatar_path'] ?? '',
            'description' => $user['description'] ?? '',
            'created_at' => $user['created_at'] ?? null,
        ],
    ]);
}

if ($method === 'PUT') {
    $userId = isset($input['id']) ? intval($input['id']) : 0;
    if ($userId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'User id required']);
    }

    $name = isset($input['nombre']) ? trim($input['nombre']) : null;
    $description = isset($input['description']) ? trim($input['description']) : null;
    $password = isset($input['password']) && trim($input['password']) !== '' ? $input['password'] : null;
    $avatarBase64 = isset($input['avatar_base64']) ? $input['avatar_base64'] : null;
    $avatarFileName = isset($input['avatar_file_name']) ? trim($input['avatar_file_name']) : null;

    $fields = [];
    $types = '';
    $values = [];

    if ($name !== null && $name !== '') {
        $fields[] = 'name = ?';
        $types .= 's';
        $values[] = $name;
    }
    if ($description !== null) {
        $fields[] = 'description = ?';
        $types .= 's';
        $values[] = $description;
    }
    if ($password !== null) {
        if (strlen($password) < 6) {
            send_json(400, ['status' => 'error', 'message' => 'La contraseña debe tener al menos 6 caracteres']);
        }
        $hashedPassword = password_hash($password, PASSWORD_BCRYPT);
        $fields[] = 'password = ?';
        $types .= 's';
        $values[] = $hashedPassword;
    }

    if ($avatarBase64 !== null && $avatarBase64 !== '') {
        $decoded = base64_decode(preg_replace('#^data:image/[^;]+;base64,#', '', $avatarBase64));
        if ($decoded === false) {
            send_json(400, ['status' => 'error', 'message' => 'Imagen inválida']);
        }

        $avatarDir = __DIR__ . '/storage/avatars';
        if (!is_dir($avatarDir) && !mkdir($avatarDir, 0777, true) && !is_dir($avatarDir)) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo crear la carpeta de imagenes']);
        }

        $extension = pathinfo($avatarFileName ?? 'avatar.png', PATHINFO_EXTENSION);
        if ($extension === '') {
            $extension = 'png';
        }
        $safeName = preg_replace('/[^a-zA-Z0-9._-]/', '_', pathinfo($avatarFileName ?? 'avatar.png', PATHINFO_FILENAME));
        $fileName = sprintf('%s_%s.%s', $userId, time(), $extension);
        $filePath = $avatarDir . '/' . $fileName;

        if (file_put_contents($filePath, $decoded) === false) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo guardar la imagen']);
        }

        $avatarPath = 'backend/storage/avatars/' . $fileName;
        $fields[] = 'avatar_path = ?';
        $types .= 's';
        $values[] = $avatarPath;
    }

    if (empty($fields)) {
        send_json(400, ['status' => 'error', 'message' => 'No hay datos para actualizar']);
    }

    $sql = 'UPDATE users SET ' . implode(', ', $fields) . ', updated_at = NOW() WHERE id = ?';
    $types .= 'i';
    $values[] = $userId;

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        send_json(500, ['status' => 'error', 'message' => 'Error al preparar la actualización']);
    }

    $stmt->bind_param($types, ...$values);
    if (!$stmt->execute()) {
        send_json(500, ['status' => 'error', 'message' => 'No se pudo actualizar el usuario: ' . $stmt->error]);
    }

    $stmt->close();

    // Return updated profile
    $stmt = $conn->prepare("SELECT id, name, email, role, avatar_path, description, created_at FROM users WHERE id = ?");
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $user = $result->fetch_assoc();
    $stmt->close();

    send_json(200, [
        'status' => 'success',
        'message' => 'Perfil actualizado',
        'data' => [
            'id' => $user['id'],
            'nombre' => $user['name'],
            'correo' => $user['email'],
            'role' => $user['role'] ?? 'aprendiz',
            'avatar_path' => $user['avatar_path'] ?? '',
            'description' => $user['description'] ?? '',
            'created_at' => $user['created_at'] ?? null,
        ],
    ]);
}

send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
