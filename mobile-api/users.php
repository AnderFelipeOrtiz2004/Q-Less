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

ensure_users_table($conn);

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

    $stmt = $conn->prepare(
        "SELECT id, name, email,
                COALESCE(NULLIF(role, ''), NULLIF(rol, ''), 'aprendiz') AS role,
                avatar_path, description, created_at
         FROM users WHERE id = ?"
    );
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        send_json(404, ['status' => 'error', 'message' => 'Usuario no encontrado']);
    }

    send_json(200, ['status' => 'success', 'data' => format_user_response($user)]);
}

function update_user_profile(mysqli $conn, array $input): void
{
    $userId = intval($input['id'] ?? 0);
    if ($userId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'ID de usuario requerido']);
    }

    $check = $conn->prepare('SELECT id FROM users WHERE id = ? LIMIT 1');
    $check->bind_param('i', $userId);
    $check->execute();
    $exists = $check->get_result()->fetch_assoc();
    $check->close();
    if (!$exists) {
        send_json(404, ['status' => 'error', 'message' => 'Usuario no encontrado']);
    }

    $fields = [];
    $types = '';
    $values = [];

    if (!empty($input['nombre'])) {
        $fields[] = 'name = ?';
        $types .= 's';
        $values[] = trim($input['nombre']);
    }
    if (isset($input['description'])) {
        $fields[] = 'description = ?';
        $types .= 's';
        $values[] = trim($input['description']);
    }
    if (!empty($input['password'])) {
        if (strlen($input['password']) < 6) {
            send_json(400, ['status' => 'error', 'message' => 'Contraseña muy corta']);
        }
        $fields[] = 'password = ?';
        $types .= 's';
        $values[] = password_hash($input['password'], PASSWORD_BCRYPT);
    }

    if (!empty($input['avatar_base64'])) {
        $avatarDir = __DIR__ . '/storage/avatars';
        if (!is_dir($avatarDir) && !mkdir($avatarDir, 0775, true)) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo crear la carpeta de avatares']);
        }

        $rawBase64 = preg_replace('#^data:image/[^;]+;base64,#', '', (string) $input['avatar_base64']);
        $decoded = base64_decode($rawBase64, true);
        if ($decoded === false || strlen($decoded) < 32) {
            send_json(400, ['status' => 'error', 'message' => 'Imagen de avatar inválida']);
        }

        $ext = 'jpg';
        $fileNameInput = strtolower((string) ($input['avatar_file_name'] ?? ''));
        if (str_ends_with($fileNameInput, '.png')) {
            $ext = 'png';
        } elseif (str_ends_with($fileNameInput, '.webp')) {
            $ext = 'webp';
        }

        $fileName = 'avatar_' . $userId . '_' . time() . '.' . $ext;
        $filePath = $avatarDir . '/' . $fileName;

        if (!file_put_contents($filePath, $decoded)) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo guardar la imagen en el servidor']);
        }

        $fields[] = 'avatar_path = ?';
        $types .= 's';
        $values[] = 'storage/avatars/' . $fileName;
    }

    if (empty($fields)) {
        send_json(400, ['status' => 'error', 'message' => 'No hay datos para actualizar']);
    }

    $sql = 'UPDATE users SET ' . implode(', ', $fields) . ', updated_at = NOW() WHERE id = ?';
    $types .= 'i';
    $values[] = $userId;

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        send_json(500, ['status' => 'error', 'message' => 'Error al preparar actualización']);
    }
    $stmt->bind_param($types, ...$values);

    if ($stmt->execute()) {
        $stmt->close();
        $fetch = $conn->prepare(
            "SELECT id, name, email,
                    COALESCE(NULLIF(role, ''), NULLIF(rol, ''), 'aprendiz') AS role,
                    avatar_path, description, created_at
             FROM users WHERE id = ?"
        );
        $fetch->bind_param('i', $userId);
        $fetch->execute();
        $updated = $fetch->get_result()->fetch_assoc();
        $fetch->close();

        send_json(200, [
            'status' => 'success',
            'message' => 'Perfil actualizado correctamente',
            'data' => $updated ? format_user_response($updated) : null,
        ]);
    }

    $stmt->close();
    send_json(500, ['status' => 'error', 'message' => 'Error al actualizar en base de datos']);
}

// --- PUT / POST: ACTUALIZAR PERFIL ---
if ($method === 'PUT' || ($method === 'POST' && ($input['action'] ?? '') === 'update_profile')) {
    update_user_profile($conn, $input);
}

send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
?>