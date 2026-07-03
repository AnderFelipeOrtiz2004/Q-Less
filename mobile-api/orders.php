<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';
require_once __DIR__ . '/helpers.php';
require_once __DIR__ . '/mail_helpers.php';
require_once __DIR__ . '/email_templates.php';

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function send_json($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit();
}

function is_admin_request($input) {
    return isset($input['role']) && strtolower(trim($input['role'])) === 'admin';
}

function resolve_admin_name(mysqli $conn, array $input): string
{
    $adminUserId = intval($input['user_id'] ?? 0);
    if ($adminUserId > 0) {
        $stmt = $conn->prepare('SELECT name FROM users WHERE id = ? LIMIT 1');
        $stmt->bind_param('i', $adminUserId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $name = trim((string) ($row['name'] ?? ''));
        if ($name !== '') {
            return $name;
        }
    }

    $envName = trim(load_local_env('ADMIN_NAME'));
    return $envName !== '' ? $envName : 'Administrador';
}

function send_purchase_approved_email(array $buyer, array $order, string $adminName): bool
{
    $email = strtolower(trim((string) ($buyer['email'] ?? '')));
    if (!is_gmail_email($email)) {
        return false;
    }

    $buyerName = trim((string) ($buyer['name'] ?? 'Cliente'));
    $orderId = (int) ($order['id'] ?? 0);
    $productName = (string) ($order['product_name'] ?? 'Producto');
    $quantity = (int) ($order['quantity'] ?? 1);
    $unitPrice = (int) ($order['price'] ?? 0);
    $total = (int) ($order['total_price'] ?? 0);
    $purchaseCode = (string) $orderId;

    $mail = qless_purchase_code_email(
        $buyerName,
        $purchaseCode,
        $productName,
        $quantity,
        $unitPrice,
        $total
    );

    return send_app_email(
        $email,
        'Compra aceptada - Código ' . $purchaseCode,
        $mail['plain'],
        $mail['html']
    );
}

$method = $_SERVER['REQUEST_METHOD'];
$json_input = json_decode(file_get_contents('php://input'), true) ?: [];
$input = array_merge($_REQUEST, $json_input);
$action = isset($input['action']) ? trim((string) $input['action']) : '';

repair_legacy_reserved_stock($conn);
expire_active_reservations($conn);

// Crear solicitud de compra (pendiente de aprobación admin)
if ($method === 'POST' && $action === 'create') {
    $userId = intval($input['user_id'] ?? 0);
    $productId = intval($input['product_id'] ?? 0);
    $quantity = intval($input['quantity'] ?? 1);
    $reservationId = intval($input['reservation_id'] ?? 0);

    if ($userId <= 0 || $productId <= 0 || $quantity <= 0) {
        send_json(400, ['status' => 'error', 'message' => 'Datos de compra inválidos']);
    }

    $purchaseCheck = user_can_purchase($conn, $userId);
    if (!$purchaseCheck['ok']) {
        send_json(403, [
            'status' => 'error',
            'message' => $purchaseCheck['message'],
            'code' => $purchaseCheck['code'] ?? null,
        ]);
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
        $orderImage = compact_order_image_path($prod['image_path'] ?? '');
        if ($orderImage === '') {
            $orderImage = compact_order_image_path($input['product_image_url'] ?? '');
        }

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
            $orderImage
        );
        if (!$ins->execute()) {
            throw new Exception('No se pudo registrar la solicitud: ' . $conn->error);
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
            'message' => 'Solicitud enviada. Tu compra quedó PENDIENTE hasta que un administrador la apruebe.',
            'data' => [
                'order_id' => $orderId,
                'order_status' => $status,
                'status_label' => 'Pendiente de aprobación',
            ],
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

        mark_web_cart_purchased($conn, intval($order['user_id']), $productId);

        $userStmt = $conn->prepare('SELECT id, name, email FROM users WHERE id = ? LIMIT 1');
        $uid = intval($order['user_id']);
        $userStmt->bind_param('i', $uid);
        $userStmt->execute();
        $buyer = $userStmt->get_result()->fetch_assoc();
        $userStmt->close();

        $upd = $conn->prepare("UPDATE ordenes SET status = 'aprobada', updated_at = NOW() WHERE id = ?");
        $upd->bind_param('i', $orderId);
        $upd->execute();
        $upd->close();

        $adminName = resolve_admin_name($conn, $input);
        $emailSent = $buyer ? send_purchase_approved_email($buyer, $order, $adminName) : false;

        $conn->commit();
        send_json(200, [
            'status' => 'success',
            'message' => $emailSent
                ? "Compra aprobada. Se envió el código {$orderId} al correo del usuario."
                : "Compra aprobada. Código de compra: {$orderId}. No se pudo enviar el correo (revisa SMTP).",
            'data' => [
                'order_id' => $orderId,
                'purchase_code' => (string) $orderId,
                'order_status' => 'aprobada',
                'email_sent' => $emailSent,
                'admin_name' => $adminName,
            ],
        ]);
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
        $conn->begin_transaction();

        $stmt = $conn->prepare('SELECT * FROM ordenes WHERE id = ? FOR UPDATE');
        $stmt->bind_param('i', $orderId);
        $stmt->execute();
        $order = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$order) {
            $conn->rollback();
            send_json(404, ['status' => 'error', 'message' => 'Orden no encontrada']);
        }
        if ($order['status'] !== 'pendiente') {
            $conn->rollback();
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

        release_web_cart_mirror($conn, intval($order['user_id']), $productId);

        $upd = $conn->prepare("UPDATE ordenes SET status = 'rechazada', updated_at = NOW() WHERE id = ?");
        $upd->bind_param('i', $orderId);
        $upd->execute();
        $upd->close();

        $conn->commit();
        send_json(200, ['status' => 'success', 'message' => 'Compra rechazada']);
    } catch (Throwable $e) {
        $conn->rollback();
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
        $orders[] = format_order_row($row);
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

if ($method === 'GET' && $action === 'get_pending_orders') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $userNameExpr = orders_buyer_name_sql_expr();
    $legacyJoin = '';
    $legacyCheck = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if ($legacyCheck && $legacyCheck->num_rows > 0) {
        $legacyJoin = 'LEFT JOIN usuarios leg ON leg.id = o.user_id';
    }

    $res = $conn->query(
        "SELECT o.*, $userNameExpr AS user_name, u.email AS user_email,
                COALESCE(u.email_verified, 0) AS email_verified
         FROM ordenes o
         LEFT JOIN users u ON u.id = o.user_id
         $legacyJoin
         WHERE o.status = 'pendiente'
           AND u.id IS NOT NULL
         ORDER BY o.created_at ASC"
    );
    if (!$res) {
        send_json(500, ['status' => 'error', 'message' => 'Error al consultar pendientes']);
    }

    $orders = [];
    while ($row = $res->fetch_assoc()) {
        $orders[] = format_order_row($row);
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

if ($method === 'GET' && $action === 'get_all_orders') {
    if (!is_admin_request($input)) {
        send_json(403, ['status' => 'error', 'message' => 'No autorizado']);
    }

    $userNameExpr = orders_buyer_name_sql_expr();
    $legacyJoin = '';
    $legacyCheck = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if ($legacyCheck && $legacyCheck->num_rows > 0) {
        $legacyJoin = 'LEFT JOIN usuarios leg ON leg.id = o.user_id';
    }

    $res = $conn->query(
        "SELECT o.*, $userNameExpr AS user_name, u.email AS user_email,
                COALESCE(u.email_verified, 0) AS email_verified
         FROM ordenes o
         LEFT JOIN users u ON u.id = o.user_id
         $legacyJoin
         ORDER BY o.created_at DESC"
    );
    if (!$res) {
        send_json(500, ['status' => 'error', 'message' => 'Error al consultar órdenes']);
    }

    $orders = [];
    while ($row = $res->fetch_assoc()) {
        $orders[] = format_order_row($row);
    }
    send_json(200, ['status' => 'success', 'data' => $orders]);
}

send_json(400, ['status' => 'error', 'message' => 'Acción no válida']);
