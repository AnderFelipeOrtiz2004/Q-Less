<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=UTF-8');

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
        send_json(500, ['status' => 'error', 'message' => 'No se pudo crear la tabla reservations: ' . $conn->error]);
    }
}

ensure_reservations_table($conn);
repair_legacy_reserved_stock($conn);
expire_active_reservations($conn);

$method = $_SERVER['REQUEST_METHOD'];
// Unión flexible de entradas (Evita fallos si la acción viene por URL o por JSON)
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);
$action = isset($input['action']) ? $input['action'] : '';

if ($method === 'GET') {
    $userId = intval($input['user_id'] ?? $_GET['user_id'] ?? 0);
    if ($userId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'user_id requerido']);
    }

    $stmt = $conn->prepare(
        "SELECT r.id AS reservation_id, r.product_id, r.quantity, r.expires_at, r.reserved_at,
                p.nombre, p.descripcion, p.categoria, p.precio, p.stock, p.image_path
         FROM reservations r
         INNER JOIN productos p ON p.id = r.product_id
         WHERE r.user_id = ? AND r.status = 'active' AND r.expires_at > NOW()
         ORDER BY r.reserved_at DESC"
    );
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    while ($row = $result->fetch_assoc()) {
        $imagePath = $row['image_path'] ?? '';
        $items[] = [
            'reservation_id' => (int) $row['reservation_id'],
            'product_id' => (int) $row['product_id'],
            'quantity' => (int) $row['quantity'],
            'expires_at' => $row['expires_at'],
            'reserved_at' => $row['reserved_at'],
            'nombre' => $row['nombre'],
            'descripcion' => $row['descripcion'],
            'categoria' => $row['categoria'],
            'precio' => (int) $row['precio'],
            'stock' => (int) $row['stock'],
            'image_path' => $imagePath,
            'image_url' => resolve_image_url($imagePath),
        ];
    }
    $stmt->close();

    send_json(200, ['status' => 'success', 'data' => $items]);
}

if ($method === 'POST' && $action === 'create') {
    $userId = isset($input['user_id']) ? intval($input['user_id']) : 0;
    $productId = isset($input['product_id']) ? intval($input['product_id']) : 0;
    $quantity = isset($input['quantity']) ? intval($input['quantity']) : 1;

    if ($userId <= 0 || $productId <= 0 || $quantity <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Datos invalidos']);
    }

    $conn->begin_transaction();
    try {
        $availability = get_product_availability($conn, $productId);
        if ($availability['stock'] <= 0 && $availability['available'] <= 0) {
            $conn->rollback();
            send_json(404, ['status' => 'error', 'message' => 'Producto no encontrado']);
        }

        if ($availability['available'] < $quantity) {
            $conn->rollback();
            send_json(409, [
                'status' => 'error',
                'message' => 'Stock insuficiente. Disponibles: ' . $availability['available'],
            ]);
        }

        $expiresSql = date('Y-m-d H:i:s', strtotime('+24 hours'));
        $ins = $conn->prepare(
            "INSERT INTO reservations (user_id, product_id, quantity, status, reserved_at, expires_at)
             VALUES (?, ?, ?, 'active', NOW(), ?)"
        );
        if (!$ins) {
            throw new Exception('Error al preparar reserva: ' . $conn->error);
        }
        $ins->bind_param('iiis', $userId, $productId, $quantity, $expiresSql);
        if (!$ins->execute()) {
            throw new Exception('No se pudo crear la reserva');
        }

        $reservationId = $conn->insert_id;
        $ins->close();

        $after = get_product_availability($conn, $productId);
        $conn->commit();

        send_json(200, [
            'status' => 'success',
            'data' => [
                'id' => $reservationId,
                'expires_at' => $expiresSql,
                'available_stock' => $after['available'],
                'stock' => $after['stock'],
                'reserved' => $after['reserved'],
            ],
        ]);
    } catch (Exception $e) {
        $conn->rollback();
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

if ($method === 'POST' && $action === 'release') {
    $reservationId = isset($input['reservation_id']) ? intval($input['reservation_id']) : 0;
    if ($reservationId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Reservation id required']);
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare("SELECT product_id, quantity FROM reservations WHERE id = ? AND status = 'active' FOR UPDATE");
        if (!$stmt) {
            throw new Exception('Error al consultar reserva: ' . $conn->error);
        }
        $stmt->bind_param("i", $reservationId);
        $stmt->execute();
        $reservation = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$reservation) {
            $conn->rollback();
            send_json(404, ['status' => 'error', 'message' => 'Reserva no encontrada o ya gestionada']);
        }

        $updateReservation = $conn->prepare("UPDATE reservations SET status = 'cancelled' WHERE id = ?");
        $updateReservation->bind_param("i", $reservationId);
        $updateReservation->execute();
        $updateReservation->close();

        $conn->commit();
        send_json(200, ['status' => 'success', 'message' => 'Reserva cancelada']);
    } catch (Exception $e) {
        $conn->rollback();
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

if ($method === 'POST' && $action === 'update') {
    $reservationId = intval($input['reservation_id'] ?? 0);
    $newQuantity = intval($input['quantity'] ?? 0);
    $userId = intval($input['user_id'] ?? 0);

    if ($reservationId <= 0 || $newQuantity <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Datos invalidos']);
    }

    $conn->begin_transaction();
    try {
        $stmt = $conn->prepare(
            "SELECT id, user_id, product_id, quantity FROM reservations
             WHERE id = ? AND status = 'active' FOR UPDATE"
        );
        $stmt->bind_param('i', $reservationId);
        $stmt->execute();
        $reservation = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$reservation) {
            throw new Exception('Reserva no encontrada');
        }
        if ($userId > 0 && intval($reservation['user_id']) !== $userId) {
            throw new Exception('No autorizado');
        }

        $productId = intval($reservation['product_id']);
        $oldQuantity = intval($reservation['quantity']);
        $delta = $newQuantity - $oldQuantity;

        if ($delta > 0) {
            $availability = get_product_availability($conn, $productId, $reservationId);
            if ($availability['available'] < $delta) {
                throw new Exception('Stock insuficiente. Disponibles: ' . $availability['available']);
            }
        }

        $expiresSql = date('Y-m-d H:i:s', strtotime('+24 hours'));
        $upd = $conn->prepare(
            'UPDATE reservations SET quantity = ?, expires_at = ? WHERE id = ? AND status = ?'
        );
        $status = 'active';
        $upd->bind_param('isis', $newQuantity, $expiresSql, $reservationId, $status);
        $upd->execute();
        $upd->close();

        $after = get_product_availability($conn, $productId);
        $conn->commit();

        send_json(200, [
            'status' => 'success',
            'data' => [
                'reservation_id' => $reservationId,
                'quantity' => $newQuantity,
                'expires_at' => $expiresSql,
                'available_stock' => $after['available'],
            ],
        ]);
    } catch (Exception $e) {
        $conn->rollback();
        send_json(409, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

if ($method === 'POST' && $action === 'confirm') {
    $reservationId = isset($input['reservation_id']) ? intval($input['reservation_id']) : 0;
    if ($reservationId <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Reservation id required']);
    }

    $stmt = $conn->prepare("UPDATE reservations SET status = 'confirmed' WHERE id = ? AND status = 'active'");
    if (!$stmt) {
        send_json(500, ['status' => 'error', 'message' => 'Error al confirmar reserva']);
    }
    $stmt->bind_param("i", $reservationId);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();

    if ($affected > 0) {
        send_json(200, ['status' => 'success', 'message' => 'Reserva confirmada']);
    }

    send_json(404, ['status' => 'error', 'message' => 'Reserva no encontrada o ya gestionada']);
}

send_json(400, ['status' => 'error', 'message' => 'Accion no valida']);
?>