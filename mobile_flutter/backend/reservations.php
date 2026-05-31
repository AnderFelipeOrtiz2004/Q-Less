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

function release_expired_reservations($conn) {
    $conn->begin_transaction();
    try {
        $result = $conn->query("SELECT id, product_id, quantity FROM reservations WHERE status = 'active' AND expires_at <= NOW() FOR UPDATE");
        if (!$result) {
            throw new Exception('No se pudieron consultar reservas expiradas: ' . $conn->error);
        }

        while ($row = $result->fetch_assoc()) {
            $productId = intval($row['product_id']);
            $quantity = intval($row['quantity']);
            $updateStock = $conn->prepare("UPDATE productos SET stock = stock + ?, updated_at = NOW() WHERE id = ?");
            if (!$updateStock) {
                throw new Exception('No se pudo preparar devolucion de stock: ' . $conn->error);
            }
            $updateStock->bind_param("ii", $quantity, $productId);
            $updateStock->execute();
            $updateStock->close();
        }

        $conn->query("UPDATE reservations SET status = 'expired' WHERE status = 'active' AND expires_at <= NOW()");
        $conn->commit();
    } catch (Exception $e) {
        $conn->rollback();
        send_json(500, ['status' => 'error', 'message' => $e->getMessage()]);
    }
}

ensure_reservations_table($conn);
release_expired_reservations($conn);

$method = $_SERVER['REQUEST_METHOD'];
$input = get_input();
$action = isset($input['action']) ? $input['action'] : '';

if ($method === 'GET') {
    send_json(200, ['status' => 'success', 'message' => 'reservations endpoint OK']);
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
        $productStmt = $conn->prepare("SELECT stock FROM productos WHERE id = ? FOR UPDATE");
        if (!$productStmt) {
            throw new Exception('Error al preparar consulta de producto: ' . $conn->error);
        }
        $productStmt->bind_param("i", $productId);
        $productStmt->execute();
        $product = $productStmt->get_result()->fetch_assoc();
        $productStmt->close();

        if (!$product) {
            $conn->rollback();
            send_json(404, ['status' => 'error', 'message' => 'Producto no encontrado']);
        }

        $stock = intval($product['stock']);
        if ($stock < $quantity) {
            $conn->rollback();
            send_json(409, ['status' => 'error', 'message' => 'Stock insuficiente. Disponibles: ' . $stock]);
        }

        $stockStmt = $conn->prepare("UPDATE productos SET stock = stock - ?, updated_at = NOW() WHERE id = ? AND stock >= ?");
        if (!$stockStmt) {
            throw new Exception('Error al preparar reserva de stock: ' . $conn->error);
        }
        $stockStmt->bind_param("iii", $quantity, $productId, $quantity);
        $stockStmt->execute();
        if ($stockStmt->affected_rows !== 1) {
            throw new Exception('No se pudo reservar el stock');
        }
        $stockStmt->close();

        $expiresSql = date('Y-m-d H:i:s', strtotime('+5 minutes'));
        $ins = $conn->prepare("INSERT INTO reservations (user_id, product_id, quantity, status, reserved_at, expires_at) VALUES (?, ?, ?, 'active', NOW(), ?)");
        if (!$ins) {
            throw new Exception('Error al preparar reserva: ' . $conn->error);
        }
        $ins->bind_param("iiis", $userId, $productId, $quantity, $expiresSql);
        if (!$ins->execute()) {
            throw new Exception('No se pudo crear la reserva');
        }

        $reservationId = $conn->insert_id;
        $remainingStock = $stock - $quantity;
        $ins->close();
        $conn->commit();

        send_json(200, [
            'status' => 'success',
            'data' => [
                'id' => $reservationId,
                'expires_at' => $expiresSql,
                'available_stock' => $remainingStock,
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

        $productId = intval($reservation['product_id']);
        $quantity = intval($reservation['quantity']);

        $updateStock = $conn->prepare("UPDATE productos SET stock = stock + ?, updated_at = NOW() WHERE id = ?");
        if (!$updateStock) {
            throw new Exception('Error al devolver stock: ' . $conn->error);
        }
        $updateStock->bind_param("ii", $quantity, $productId);
        $updateStock->execute();
        $updateStock->close();

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
