<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit();
}

function is_admin_request($input) {
    return isset($input['role']) && strtolower(trim($input['role'])) === 'admin';
}

$method = $_SERVER['REQUEST_METHOD'];
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);
$action = isset($input['action']) ? trim((string) $input['action']) : '';

// Crear solicitud de compra (pendiente de aprobación admin)
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
        if ($reservationId > 0) {
            $dup = $conn->prepare(
                "SELECT id FROM ordenes WHERE reservation_id = ? AND status = 'pendiente' LIMIT 1"
            );
            $dup->bind_param('i', $reservationId);
            $dup->execute();
            $existingOrder = $dup->get_result()->fetch_assoc();
            $dup->close();
            if ($existingOrder) {
                throw new Exception('Esta reserva ya tiene una solicitud pendiente');
            }

            $stmt = $conn->prepare(
                "SELECT user_id, product_id, quantity, status, expires_at
                 FROM reservations WHERE id = ? FOR UPDATE"
            );
            $stmt->bind_param('i', $reservationId);
            $stmt->execute();
            $res = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$res || $res['status'] !== 'active' || strtotime($res['expires_at']) <= time()) {
                throw new Exception('Reserva inválida o expirada');
            }
            if (intval($res['user_id']) !== $userId || intval($res['product_id']) !== $productId) {
                throw new Exception('La reserva no coincide con el producto');
            }
            if (intval($res['quantity']) !== $quantity) {
                throw new Exception('La cantidad no coincide con la reserva del carrito');
            }
        }

        $stmt = $conn->prepare('SELECT nombre, precio, stock, image_path FROM productos WHERE id = ?');
        $stmt->bind_param('i', $productId);
        $stmt->execute();
        $prod = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$prod) {
            throw new Exception('Producto no encontrado');
        }

        if ($reservationId <= 0) {
            $availability = get_product_availability($conn, $productId);
            if ($availability['available'] < $quantity) {
                throw new Exception('Stock insuficiente. Disponibles: ' . $availability['available']);
            }
            if (!deduct_product_stock($conn, $productId, $quantity)) {
                throw new Exception('No se pudo reservar stock para la compra');
            }
        }

        $total = intval($prod['precio']) * $quantity;
        $status = 'pendiente';
        $resId = $reservationId > 0 ? $reservationId : 0;

        $ins = $conn->prepare(
            'INSERT INTO ordenes (user_id, product_id, reservation_id, product_name, quantity, price, total_price, status, product_image_url)
             VALUES (?, ?, NULLIF(?, 0), ?, ?, ?, ?, ?, ?)'
        );
        $ins->bind_param(
            'iiisiiiss',
            $userId,
            $productId,
            $resId,
            $prod['nombre'],
            $quantity,
            $prod['precio'],
            $total,
            $status,
            $prod['image_path']
        );
        if (!$ins->execute()) {
            throw new Exception('No se pudo registrar la solicitud de compra');
        }
        $orderId = $ins->insert_id;
        $ins->close();

        if ($reservationId > 0) {
            $lockRes = $conn->prepare(
                "UPDATE reservations SET status = 'pending_approval' WHERE id = ? AND status = 'active'"
            );
            $lockRes->bind_param('i', $reservationId);
            $lockRes->execute();
            if ($lockRes->affected_rows !== 1) {
                throw new Exception('No se pudo bloquear la reserva del carrito');
            }
            $lockRes->close();
        }

        $conn->commit();
        send_json(200, [
            'status' => 'success',
            'message' => 'Solicitud enviada. Un administrador revisará tu compra.',
            'data' => ['order_id' => $orderId, 'order_status' => $status],
        ]);
    } catch (Throwable $e) {
        $conn->rollback();
        send_json(409, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// Aprobar compra (admin)
if ($method === 'POST' && $action === 'approve') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $orderId = intval($input['order_id'] ?? 0);
    if ($orderId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'ID de orden inválido']);
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare('SELECT * FROM ordenes WHERE id = ? FOR UPDATE');
        $stmt->bind_param('i', $orderId);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$order) {
            throw new Exception('Orden no encontrada');
        }
        if ($order['status'] !== 'pendiente') {
            throw new Exception('Esta orden ya fue procesada');
        }

        $productId = intval($order['product_id']);
        $quantity = intval($order['quantity']);
        $reservationId = intval($order['reservation_id'] ?? 0);

        // El stock ya se descontó al reservar en carrito o al crear la orden sin reserva.
        if ($reservationId > 0) {
            $resStmt = $conn->prepare(
                "UPDATE reservations SET status = 'confirmed' WHERE id = ? AND status IN ('active', 'pending_approval')"
            );
            $resStmt->bind_param('i', $reservationId);
            $resStmt->execute();
            $resStmt->close();
        }

        $upd = $conn->prepare("UPDATE ordenes SET status = 'aprobada', updated_at = NOW() WHERE id = ?");
        $upd->bind_param('i', $orderId);
        $upd->execute();
        $upd->close();

        $conn->commit();
        send_json(200, ['status' => 'success', 'message' => 'Compra aprobada correctamente']);
    } catch (Throwable $e) {
        $conn->rollback();
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

// Rechazar compra (admin)
if ($method === 'POST' && $action === 'reject') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $orderId = intval($input['order_id'] ?? 0);
    if ($orderId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'ID de orden inválido']);
    }

    try {
        $stmt = $conn->prepare('SELECT * FROM ordenes WHERE id = ?');
        $stmt->bind_param('i', $orderId);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$order) {
            send_json(404, ['status' => 'error', 'message' => 'Orden no encontrada']);
        }
        if ($order['status'] !== 'pendiente') {
            send_json(400, ['status' => 'error', 'message' => 'Esta orden ya fue procesada']);
        }

        $productId = intval($order['product_id']);
        $quantity = intval($order['quantity']);
        $reservationId = intval($order['reservation_id'] ?? 0);

        restore_product_stock($conn, $productId, $quantity);

        if ($reservationId > 0) {
            $resStmt = $conn->prepare(
                "UPDATE reservations SET status = 'cancelled' WHERE id = ? AND status IN ('active', 'pending_approval')"
            );
            $resStmt->bind_param('i', $reservationId);
            $resStmt->execute();
            $resStmt->close();
        }

        $upd = $conn->prepare("UPDATE ordenes SET status = 'rechazada', updated_at = NOW() WHERE id = ?");
        $upd->bind_param('i', $orderId);
        $upd->execute();
        $upd->close();

        send_json(200, ['status' => 'success', 'message' => 'Compra rechazada']);
    } catch (Throwable $e) {
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

if ($method === 'GET' && $action === 'get_user_orders') {
    $userId = intval($input['user_id'] ?? 0);
    $stmt = $conn->prepare('SELECT * FROM ordenes WHERE user_id = ? ORDER BY created_at DESC');
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $res = $stmt->get_result();

    $orders = [];
    while ($row = $res->fetch_assoc()) {
        $row['product_image_url'] = resolve_image_url($row['product_image_url']);
        $orders[] = $row;
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

if ($method === 'GET' && $action === 'get_pending_orders') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $res = $conn->query(
        "SELECT o.*, u.name AS user_name, u.email AS user_email
         FROM ordenes o
         LEFT JOIN users u ON u.id = o.user_id
         WHERE o.status = 'pendiente'
         ORDER BY o.created_at ASC"
    );
    if (!$res) {
        send_json(500, ['status' => 'error', 'message' => 'Error al consultar pendientes']);
    }

    $orders = [];
    while ($row = $res->fetch_assoc()) {
        $row['product_image_url'] = resolve_image_url($row['product_image_url']);
        $orders[] = $row;
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

if ($method === 'GET' && $action === 'get_all_orders') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $res = $conn->query(
        "SELECT o.*, u.name AS user_name, u.email AS user_email
         FROM ordenes o
         LEFT JOIN users u ON u.id = o.user_id
         ORDER BY o.created_at DESC"
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
}

send_json(400, ['status' => 'error', 'message' => 'Acción no válida']);
