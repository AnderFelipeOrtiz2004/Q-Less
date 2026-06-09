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

function get_input() {
    $input = json_decode(file_get_contents('php://input'), true);
    return is_array($input) ? $input : [];
}

function is_admin_request($input) {
    return isset($input['role']) && strtolower(trim($input['role'])) === 'admin';
}

function ensure_product_columns($conn) {
    $stmt = $conn->prepare("SHOW COLUMNS FROM productos LIKE 'categoria'");
    if ($stmt) {
        $stmt->execute();
        $res = $stmt->get_result();
        if ($res && $res->num_rows === 0) {
            $alter = $conn->prepare("ALTER TABLE productos ADD COLUMN categoria VARCHAR(80) NOT NULL DEFAULT 'Cuadernos' AFTER descripcion");
            if ($alter) {
                $alter->execute();
                $alter->close();
            }
        }
        $stmt->close();
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
    $stmt = $conn->prepare($create);
    if ($stmt) {
        $ok = $stmt->execute();
        $stmt->close();
        if (!$ok) {
            send_json(500, ['status' => 'error', 'message' => 'No se pudo preparar reservas: ' . $conn->error]);
        }
    } else {
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

    return 'storage/products/' . $fileName;
}

$method = $_SERVER['REQUEST_METHOD'];
ensure_product_columns($conn);
ensure_reservations_table($conn);

if ($method === 'GET') {
    repair_legacy_reserved_stock($conn);
    expire_active_reservations($conn);

    $webReservedExpr = cart_reservations_table_exists($conn)
        ? "(SELECT COALESCE(SUM(cr.cantidad), 0) FROM cart_reservations cr
            WHERE cr.producto_id = p.id AND cr.status = 'active' AND cr.expires_at > NOW()
            AND NOT EXISTS (
                SELECT 1 FROM reservations r2
                WHERE r2.user_id = cr.user_id AND r2.product_id = cr.producto_id
                AND r2.status = 'active' AND r2.expires_at > NOW()
            ))"
        : '0';

    $query = "SELECT p.id, p.nombre, p.descripcion, p.categoria, p.precio, p.stock, p.image_path, p.user_id, p.created_at, p.updated_at,
              (
                (SELECT COALESCE(SUM(r.quantity), 0) FROM reservations r
                 WHERE r.product_id = p.id AND r.status = 'active' AND r.expires_at > NOW())
                + $webReservedExpr
              ) AS reserved
              FROM productos p
              ORDER BY p.updated_at DESC, p.id DESC";

    $stmt = $conn->prepare($query);
    if (!$stmt) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al preparar consulta: ' . $conn->error
        ]);
    }
    $stmt->execute();
    $result = $stmt->get_result();

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

        // El stock en BD ya refleja las reservas activas del carrito.
        $available = max(0, $stock);
        $image_url = resolve_image_url($image_path);

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