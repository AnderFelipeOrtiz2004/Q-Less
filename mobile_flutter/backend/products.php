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

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit();
}

function get_input() {
    $input = json_decode(file_get_contents('php://input'), true);
    return is_array($input) ? $input : [];
}

function is_admin_request($input) {
    return isset($input['role']) && strtolower(trim($input['role'])) === 'admin';
}

function image_url($path) {
    // Ensure $path is a non-empty string
    if (!is_string($path) || trim($path) === '') {
        return 'https://via.placeholder.com/600x400?text=No-Image';
    }

    $path = trim($path);

    // If already a full URL, return it (but normalize)
    if (preg_match('/^https?:\/\//i', $path)) {
        return $path;
    }

    // Build a safe host (fallback to localhost if HTTP_HOST missing)
    $scheme = (isset($_SERVER['HTTPS']) && strtolower($_SERVER['HTTPS']) === 'on') ? 'https' : 'http';
    $hostName = isset($_SERVER['HTTP_HOST']) && trim($_SERVER['HTTP_HOST']) !== '' ? $_SERVER['HTTP_HOST'] : 'localhost';
    $hostUrl = $scheme . '://' . $hostName;

    $cleanPath = ltrim($path, '/');
    if (strpos($cleanPath, 'backend/') !== 0) {
        $cleanPath = 'backend/' . (strpos($cleanPath, 'storage/') === 0 ? $cleanPath : 'storage/' . $cleanPath);
    }

    // If for some reason rawurlencode fails, fallback to placeholder
    $encoded = rawurlencode($cleanPath);
    if ($encoded === false || $encoded === '') {
        return 'https://via.placeholder.com/600x400?text=No-Image';
    }

    return $hostUrl . '/backend/image.php?path=' . $encoded;
}

function ensure_product_columns($conn) {
    $result = $conn->query("SHOW COLUMNS FROM productos LIKE 'categoria'");
    if ($result && $result->num_rows === 0) {
        $conn->query("ALTER TABLE productos ADD COLUMN categoria VARCHAR(80) NOT NULL DEFAULT 'Cuadernos' AFTER descripcion");
    }
}

function ensure_reservations_table($conn) {
    $create = "CREATE TABLE IF NOT EXISTS reservations (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NOT NULL,
        product_id INT NOT NULL,
        quantity INT NOT NULL DEFAULT 1,
        status VARCHAR(20) NOT NULL DEFAULT 'active',
        reserved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        expires_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_product_id (product_id),
        INDEX idx_status_expires (status, expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

    if ($conn->query($create) === false) {
        send_json(500, ['status' => 'error', 'message' => 'No se pudo preparar reservas: ' . $conn->error]);
    }
}

function save_product_image($input) {
    if (empty($input['image_base64'])) {
        return '';
    }

    $base64 = $input['image_base64'];
    if (strpos($base64, ',') !== false) {
        $parts = explode(',', $base64, 2);
        $base64 = $parts[1];
    }

    $bytes = base64_decode($base64, true);
    if ($bytes === false) {
        send_json(400, [
            'status' => 'error',
            'message' => 'Imagen invalida'
        ]);
    }

    $originalName = isset($input['image_file_name']) ? basename($input['image_file_name']) : 'producto.jpg';
    $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    if (!in_array($extension, $allowed, true)) {
        $extension = 'jpg';
    }

    $directory = __DIR__ . '/storage/products';
    if (!is_dir($directory) && !mkdir($directory, 0775, true)) {
        send_json(500, [
            'status' => 'error',
            'message' => 'No se pudo crear la carpeta de imagenes'
        ]);
    }

    $fileName = 'product_' . date('YmdHis') . '_' . bin2hex(random_bytes(4)) . '.' . $extension;
    $filePath = $directory . '/' . $fileName;

    if (file_put_contents($filePath, $bytes) === false) {
        send_json(500, [
            'status' => 'error',
            'message' => 'No se pudo guardar la imagen'
        ]);
    }

    return 'backend/storage/products/' . $fileName;
}

$method = $_SERVER['REQUEST_METHOD'];
ensure_product_columns($conn);
ensure_reservations_table($conn);

if ($method === 'GET') {
    $conn->query("UPDATE productos p INNER JOIN (SELECT product_id, SUM(quantity) AS qty FROM reservations WHERE status = 'active' AND expires_at <= NOW() GROUP BY product_id) r ON r.product_id = p.id SET p.stock = p.stock + r.qty, p.updated_at = NOW()");
    $conn->query("UPDATE reservations SET status = 'expired' WHERE status = 'active' AND expires_at <= NOW()");

    // Include active reservations per product so we can compute available stock
    $query = "SELECT p.id, p.nombre, p.descripcion, p.categoria, p.precio, p.stock, p.image_path, p.user_id, p.created_at, p.updated_at, COALESCE(SUM(r.quantity),0) AS reserved " .
             "FROM productos p LEFT JOIN reservations r ON r.product_id = p.id AND r.status = 'active' " .
             "GROUP BY p.id ORDER BY p.updated_at DESC, p.id DESC";

    $result = $conn->query($query);

    if (!$result) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al consultar productos: ' . $conn->error
        ]);
    }

    $products = [];
    while ($row = $result->fetch_assoc()) {
        // Normalize values to avoid nulls reaching the client (helps Flutter null-safety)
        $id = isset($row['id']) ? intval($row['id']) : 0;
        $nombre = isset($row['nombre']) ? (string)$row['nombre'] : '';
        $descripcion = isset($row['descripcion']) ? (string)$row['descripcion'] : '';
        $categoria = isset($row['categoria']) ? (string)$row['categoria'] : 'General';
        $precio = isset($row['precio']) ? intval($row['precio']) : 0;
        $stock = isset($row['stock']) ? intval($row['stock']) : 0;
        $image_path = isset($row['image_path']) && $row['image_path'] !== null ? (string)$row['image_path'] : '';
        $user_id = isset($row['user_id']) && $row['user_id'] !== null ? intval($row['user_id']) : null;
        $reserved = isset($row['reserved']) ? intval($row['reserved']) : 0;

        $available = max(0, $stock - $reserved);
        $image_url = image_url($image_path);

        $products[] = [
            'id' => $id,
            'nombre' => $nombre,
            'descripcion' => $descripcion,
            'categoria' => $categoria,
            'precio' => $precio,
            'stock' => $stock,
            'available_stock' => $available,
            'reserved' => $reserved,
            'image_path' => $image_path,
            'image_url' => $image_url,
            'user_id' => $user_id,
            'created_at' => isset($row['created_at']) ? $row['created_at'] : null,
            'updated_at' => isset($row['updated_at']) ? $row['updated_at'] : null,
        ];
    }

    send_json(200, [
        'status' => 'success',
        'data' => $products
    ]);
}

$input = get_input();

if (!is_admin_request($input)) {
    send_json(403, [
        'status' => 'error',
        'message' => 'Solo el rol admin puede modificar productos'
    ]);
}

if ($method === 'POST' || $method === 'PUT') {
    $id = isset($input['id']) ? intval($input['id']) : 0;
    $nombre = isset($input['nombre']) ? trim($input['nombre']) : '';
    $descripcion = isset($input['descripcion']) ? trim($input['descripcion']) : '';
    $categoria = isset($input['categoria']) ? trim($input['categoria']) : 'Cuadernos';
    $precio = isset($input['precio']) ? intval($input['precio']) : 0;
    $stock = isset($input['stock']) ? intval($input['stock']) : 0;
    $imagePath = isset($input['image_path']) ? trim($input['image_path']) : '';
    $userId = isset($input['user_id']) ? intval($input['user_id']) : 1;
    $savedImagePath = save_product_image($input);
    if ($savedImagePath !== '') {
        $imagePath = $savedImagePath;
    }

    if ($savedImagePath === '' && (preg_match('/^blob:/i', $imagePath) || stripos($imagePath, 'data:image/') !== false)) {
        send_json(400, [
            'status' => 'error',
            'message' => 'Selecciona de nuevo la imagen para guardarla correctamente'
        ]);
    }

    if ($nombre === '' || $descripcion === '' || $categoria === '' || $precio < 0 || $stock < 0 || $imagePath === '') {
        send_json(400, [
            'status' => 'error',
            'message' => 'Nombre, descripcion, categoria, precio, stock e imagen son requeridos'
        ]);
    }

    if ($method === 'POST') {
        $stmt = $conn->prepare("INSERT INTO productos (nombre, descripcion, categoria, precio, stock, image_path, user_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");
        if (!$stmt) {
            send_json(500, ['status' => 'error', 'message' => 'Error al preparar insercion']);
        }

        $stmt->bind_param("sssiisi", $nombre, $descripcion, $categoria, $precio, $stock, $imagePath, $userId);
        $message = 'Producto creado correctamente';
    } else {
        if ($id <= 0) {
            send_json(400, ['status' => 'error', 'message' => 'ID de producto requerido']);
        }

        $stmt = $conn->prepare("UPDATE productos SET nombre = ?, descripcion = ?, categoria = ?, precio = ?, stock = ?, image_path = ?, user_id = ?, updated_at = NOW() WHERE id = ?");
        if (!$stmt) {
            send_json(500, ['status' => 'error', 'message' => 'Error al preparar actualizacion']);
        }

        $stmt->bind_param("sssiisii", $nombre, $descripcion, $categoria, $precio, $stock, $imagePath, $userId, $id);
        $message = 'Producto actualizado correctamente';
    }

    if (!$stmt->execute()) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al guardar producto: ' . $stmt->error
        ]);
    }

    $savedId = $method === 'POST' ? $stmt->insert_id : $id;
    $stmt->close();

    send_json(200, [
        'status' => 'success',
        'message' => $message,
        'data' => ['id' => $savedId]
    ]);
}

if ($method === 'DELETE') {
    $id = isset($input['id']) ? intval($input['id']) : 0;

    if ($id <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'ID de producto requerido']);
    }

    $stmt = $conn->prepare("DELETE FROM productos WHERE id = ?");
    if (!$stmt) {
        send_json(500, ['status' => 'error', 'message' => 'Error al preparar eliminacion']);
    }

    $stmt->bind_param("i", $id);
    if (!$stmt->execute()) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al borrar producto: ' . $stmt->error
        ]);
    }

    $stmt->close();

    send_json(200, [
        'status' => 'success',
        'message' => 'Producto borrado correctamente'
    ]);
}

send_json(405, [
    'status' => 'error',
    'message' => 'Metodo no permitido'
]);
?>
