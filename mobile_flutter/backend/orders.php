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
    if (!$path) {
        return '';
    }

    if (preg_match('/^https?:\/\//i', $path) && strpos($path, '/backend/storage/') === false) {
        return $path;
    }

    $host = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'];
    $cleanPath = ltrim(parse_url($path, PHP_URL_PATH) ?: $path, '/');
    if (strpos($cleanPath, 'backend/') !== 0) {
        $cleanPath = 'backend/' . (strpos($cleanPath, 'storage/') === 0 ? $cleanPath : 'storage/' . $cleanPath);
    }

    return $host . '/backend/image.php?path=' . rawurlencode($cleanPath);
}

$method = $_SERVER['REQUEST_METHOD'];
$input = $method === 'GET' ? $_GET : get_input();
$action = isset($input['action']) ? $input['action'] : '';

// Create order
if ($method === 'POST' && $action === 'create') {
    $userId = isset($input['user_id']) ? intval($input['user_id']) : 0;
    $productId = isset($input['product_id']) ? intval($input['product_id']) : 0;
    $productName = isset($input['product_name']) ? trim($input['product_name']) : '';
    $quantity = isset($input['quantity']) ? intval($input['quantity']) : 1;
    $price = isset($input['price']) ? intval($input['price']) : 0;
    $totalPrice = isset($input['total_price']) ? intval($input['total_price']) : 0;
    $productImageUrl = isset($input['product_image_url']) ? trim($input['product_image_url']) : '';
    $reservationId = isset($input['reservation_id']) ? intval($input['reservation_id']) : 0;

    if ($userId <= 0 || $productId <= 0 || $quantity <= 0) {
        send_json(400, [
            'status' => 'error',
            'message' => 'Datos de compra inválidos'
        ]);
    }

    // Check if orders table exists, if not create it
    $checkTable = "SHOW TABLES LIKE 'ordenes'";
    $result = $conn->query($checkTable);
    
    if ($result->num_rows == 0) {
        $createTable = "CREATE TABLE IF NOT EXISTS ordenes (
            id INT PRIMARY KEY AUTO_INCREMENT,
            user_id INT NOT NULL,
            product_id INT NOT NULL,
            product_name VARCHAR(150) NOT NULL,
            quantity INT NOT NULL DEFAULT 1,
            price INT NOT NULL DEFAULT 0,
            total_price INT NOT NULL DEFAULT 0,
            status VARCHAR(50) DEFAULT 'completada',
            product_image_url VARCHAR(255) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_user_id (user_id),
            INDEX idx_product_id (product_id),
            INDEX idx_created_at (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        if (!$conn->query($createTable)) {
            send_json(500, [
                'status' => 'error',
                'message' => 'Error al crear tabla de órdenes: ' . $conn->error
            ]);
        }
    }

    $conn->begin_transaction();

    try {
        $reservedStock = false;
        if ($reservationId > 0) {
            $reservationStmt = $conn->prepare("SELECT user_id, product_id, quantity, status, expires_at FROM reservations WHERE id = ? FOR UPDATE");
            if (!$reservationStmt) {
                throw new Exception('Error al consultar reserva: ' . $conn->error);
            }
            $reservationStmt->bind_param("i", $reservationId);
            $reservationStmt->execute();
            $reservation = $reservationStmt->get_result()->fetch_assoc();
            $reservationStmt->close();

            if (!$reservation) {
                throw new Exception('Reserva no encontrada');
            }
            if (intval($reservation['user_id']) !== $userId || intval($reservation['product_id']) !== $productId || intval($reservation['quantity']) !== $quantity) {
                throw new Exception('La reserva no coincide con la compra');
            }
            if ($reservation['status'] !== 'active') {
                throw new Exception('La reserva ya fue gestionada');
            }
            if (strtotime($reservation['expires_at']) <= time()) {
                $restoreStmt = $conn->prepare("UPDATE productos SET stock = stock + ?, updated_at = NOW() WHERE id = ?");
                if ($restoreStmt) {
                    $restoreStmt->bind_param("ii", $quantity, $productId);
                    $restoreStmt->execute();
                    $restoreStmt->close();
                }
                $expiredStmt = $conn->prepare("UPDATE reservations SET status = 'expired' WHERE id = ?");
                if ($expiredStmt) {
                    $expiredStmt->bind_param("i", $reservationId);
                    $expiredStmt->execute();
                    $expiredStmt->close();
                }
                $conn->rollback();
                send_json(409, [
                    'status' => 'error',
                    'message' => 'La reserva expiro. Vuelve a agregar el producto al carrito.'
                ]);
            }

            $reservedStock = true;
        }

        $productStmt = $conn->prepare("SELECT nombre, precio, stock, image_path FROM productos WHERE id = ? FOR UPDATE");
        if (!$productStmt) {
            throw new Exception('Error al preparar consulta de producto: ' . $conn->error);
        }

        $productStmt->bind_param("i", $productId);
        $productStmt->execute();
        $productResult = $productStmt->get_result();
        $product = $productResult->fetch_assoc();
        $productStmt->close();

        if (!$product) {
            throw new Exception('Producto no encontrado');
        }

        $currentStock = intval($product['stock']);
        if (!$reservedStock && $currentStock < $quantity) {
            $conn->rollback();
            send_json(409, [
                'status' => 'error',
                'message' => 'Stock insuficiente. Quedan ' . $currentStock . ' unidades'
            ]);
        }

        if ($productName === '') {
            $productName = $product['nombre'];
        }
        if ($price <= 0) {
            $price = intval($product['precio']);
        }
        $totalPrice = $price * $quantity;
        if ($productImageUrl === '') {
            $productImageUrl = $product['image_path'];
        }

        if ($reservedStock) {
            $confirmStmt = $conn->prepare("UPDATE reservations SET status = 'confirmed' WHERE id = ? AND status = 'active'");
            if (!$confirmStmt) {
                throw new Exception('Error al confirmar reserva: ' . $conn->error);
            }
            $confirmStmt->bind_param("i", $reservationId);
            $confirmStmt->execute();
            if ($confirmStmt->affected_rows !== 1) {
                throw new Exception('No se pudo confirmar la reserva');
            }
            $confirmStmt->close();
        } else {
            $stockStmt = $conn->prepare("UPDATE productos SET stock = stock - ?, updated_at = NOW() WHERE id = ? AND stock >= ?");
            if (!$stockStmt) {
                throw new Exception('Error al preparar descuento de stock: ' . $conn->error);
            }

            $stockStmt->bind_param("iii", $quantity, $productId, $quantity);
            $stockStmt->execute();
            if ($stockStmt->affected_rows !== 1) {
                throw new Exception('No se pudo descontar el stock');
            }
            $stockStmt->close();
            $currentStock -= $quantity;
        }

        $stmt = $conn->prepare("INSERT INTO ordenes (user_id, product_id, product_name, quantity, price, total_price, product_image_url, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");
        if (!$stmt) {
            throw new Exception('Error al preparar la orden: ' . $conn->error);
        }

        $stmt->bind_param("iisiiis", $userId, $productId, $productName, $quantity, $price, $totalPrice, $productImageUrl);
        if (!$stmt->execute()) {
            throw new Exception('Error al crear la orden: ' . $stmt->error);
        }

        $orderId = $conn->insert_id;
        $stmt->close();
        $conn->commit();

        send_json(200, [
            'status' => 'success',
            'message' => 'Compra realizada correctamente',
            'data' => [
                'id' => $orderId,
                'user_id' => $userId,
                'product_id' => $productId,
                'product_name' => $productName,
                'quantity' => $quantity,
                'price' => $price,
                'total_price' => $totalPrice,
                'stock' => $reservedStock ? $currentStock : $currentStock,
                'status' => 'completada'
            ]
        ]);
    } catch (Exception $e) {
        $conn->rollback();
        send_json(500, [
            'status' => 'error',
            'message' => $e->getMessage()
        ]);
    }
}

// Get user orders
if ($method === 'GET' && $action === 'get_user_orders') {
    $userId = isset($input['user_id']) ? intval($input['user_id']) : 0;

    if ($userId <= 0) {
        send_json(400, [
            'status' => 'error',
            'message' => 'ID de usuario inválido'
        ]);
    }

    // Check if table exists first
    $checkTable = "SHOW TABLES LIKE 'ordenes'";
    $result = $conn->query($checkTable);
    
    if ($result->num_rows == 0) {
        // No orders yet, return empty array
        send_json(200, [
            'status' => 'success',
            'data' => []
        ]);
    }

    $query = "SELECT id, user_id, product_id, product_name, quantity, price, total_price, status, product_image_url, created_at, updated_at FROM ordenes WHERE user_id = ? ORDER BY created_at DESC";
    $stmt = $conn->prepare($query);

    if (!$stmt) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al preparar la consulta: ' . $conn->error
        ]);
    }

    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $row['product_image_url'] = image_url($row['product_image_url']);
        $orders[] = $row;
    }

    send_json(200, [
        'status' => 'success',
        'data' => $orders
    ]);
}

if ($method === 'GET' && $action === 'get_all_orders') {
    if (!is_admin_request($input)) {
        send_json(403, [
            'status' => 'error',
            'message' => 'Solo el rol admin puede ver todas las compras'
        ]);
    }

    $checkTable = "SHOW TABLES LIKE 'ordenes'";
    $result = $conn->query($checkTable);

    if ($result->num_rows == 0) {
        send_json(200, [
            'status' => 'success',
            'data' => []
        ]);
    }

    $query = "SELECT o.id, o.user_id, o.product_id, o.product_name, o.quantity, o.price, o.total_price, o.status, o.product_image_url, o.created_at, o.updated_at, u.name AS user_name, u.email AS user_email FROM ordenes o LEFT JOIN users u ON u.id = o.user_id ORDER BY o.created_at DESC";
    $result = $conn->query($query);

    if (!$result) {
        send_json(500, [
            'status' => 'error',
            'message' => 'Error al consultar compras: ' . $conn->error
        ]);
    }

    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $row['product_image_url'] = image_url($row['product_image_url']);
        $orders[] = $row;
    }

    send_json(200, [
        'status' => 'success',
        'data' => $orders
    ]);
}

// Default response
send_json(400, [
    'status' => 'error',
    'message' => 'Acción no válida'
]);
?>
