<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

ensure_ordenes_table($conn);

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit();
}

// Función auxiliar para validar admin
function is_admin_request($input) {
    return isset($input['role']) && strtolower(trim($input['role'])) === 'admin';
}

$method = $_SERVER['REQUEST_METHOD'];
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);
$action = isset($input['action']) ? $input['action'] : '';

// 1. Crear Orden
if ($method === 'POST' && $action === 'create') {
    $userId = intval($input['user_id'] ?? 0);
    $productId = intval($input['product_id'] ?? 0);
    $quantity = intval($input['quantity'] ?? 1);
    $reservationId = intval($input['reservation_id'] ?? 0);

    if ($userId <= 0 || $productId <= 0 || $quantity <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Datos de compra inválidos']);
    }

    $conn->begin_transaction();
    try {
        // Validar Reserva si existe
        if ($reservationId > 0) {
            $stmt = $conn->prepare("SELECT user_id, product_id, quantity, status, expires_at FROM reservations WHERE id = ? FOR UPDATE");
            $stmt->bind_param("i", $reservationId);
            $stmt->execute();
            $res = $stmt->get_result()->fetch_assoc();
            if (!$res || $res['status'] !== 'active' || strtotime($res['expires_at']) <= time()) {
                throw new Exception('Reserva inválida o expirada');
            }
        }

        // Obtener datos del producto
        $stmt = $conn->prepare("SELECT nombre, precio, stock, image_path FROM productos WHERE id = ? FOR UPDATE");
        $stmt->bind_param("i", $productId);
        $stmt->execute();
        $prod = $stmt->get_result()->fetch_assoc();
        
        if (!$prod) {
            throw new Exception('Producto no encontrado');
        }

        $excludeReservation = $reservationId > 0 ? $reservationId : null;
        $availability = get_product_availability($conn, $productId, $excludeReservation);
        if ($availability['available'] < $quantity && $reservationId <= 0) {
            throw new Exception('Stock insuficiente. Disponibles: ' . $availability['available']);
        }
        if (intval($prod['stock']) < $quantity) {
            throw new Exception('Stock insuficiente');
        }

        $deduct = $conn->prepare('UPDATE productos SET stock = stock - ?, updated_at = NOW() WHERE id = ? AND stock >= ?');
        $deduct->bind_param('iii', $quantity, $productId, $quantity);
        $deduct->execute();
        if ($deduct->affected_rows !== 1) {
            throw new Exception('No se pudo descontar el stock');
        }
        $deduct->close();
        
        // Confirmar reserva si existe
        if ($reservationId > 0) {
            $conn->query("UPDATE reservations SET status = 'confirmed' WHERE id = $reservationId");
        }

        // Insertar Orden
        $total = intval($prod['precio']) * $quantity;
        $ins = $conn->prepare("INSERT INTO ordenes (user_id, product_id, product_name, quantity, price, total_price, product_image_url) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $ins->bind_param("iisiiis", $userId, $productId, $prod['nombre'], $quantity, $prod['precio'], $total, $prod['image_path']);
        $ins->execute();

        $conn->commit();
        send_json(200, ['status' => 'success', 'message' => 'Compra realizada']);
    } catch (Exception $e) {
        $conn->rollback();
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// 2. Obtener órdenes de usuario
if ($method === 'GET' && $action === 'get_user_orders') {
    $userId = intval($input['user_id'] ?? 0);
    $stmt = $conn->prepare("SELECT * FROM ordenes WHERE user_id = ? ORDER BY created_at DESC");
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $res = $stmt->get_result();
    
    $orders = [];
    while ($row = $res->fetch_assoc()) {
        $row['product_image_url'] = resolve_image_url($row['product_image_url']);
        $orders[] = $row;
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

// 3. Obtener todas las órdenes (Admin)
if ($method === 'GET' && $action === 'get_all_orders') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    try {
        $res = $conn->query(
            "SELECT o.*, u.name AS user_name FROM ordenes o LEFT JOIN users u ON u.id = o.user_id ORDER BY o.created_at DESC"
        );
        if (!$res) {
            send_json(500, ['status' => 'error', 'message' => 'Error al consultar órdenes']);
        }

        $orders = [];
        while ($row = $res->fetch_assoc()) {
            $row['product_image_url'] = resolve_image_url($row['product_image_url']);
            $orders[] = $row;
        }
        send_json(200, ['status' => 'success', 'data' => $orders]);
    } catch (Throwable $e) {
        send_json(500, ['status' => 'error', 'message' => 'Error al cargar compras: ' . $e->getMessage()]);
    }
}

send_json(400, ['status' => 'error', 'message' => 'Acción no válida']);
?>