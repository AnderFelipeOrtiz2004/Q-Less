<?php

function ensure_users_table(mysqli $conn): void
{
    $conn->query(
        "CREATE TABLE IF NOT EXISTS users (
            id INT PRIMARY KEY AUTO_INCREMENT,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(100) NOT NULL,
            password VARCHAR(255) NOT NULL,
            role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz',
            avatar_path VARCHAR(255) NULL,
            description TEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY uq_users_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    migrate_legacy_usuarios_table($conn);
}

function migrate_legacy_usuarios_table(mysqli $conn): void
{
    $legacy = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if (!$legacy || $legacy->num_rows === 0) {
        return;
    }

    $columns = [];
    $result = $conn->query('SHOW COLUMNS FROM usuarios');
    if (!$result) {
        return;
    }
    while ($row = $result->fetch_assoc()) {
        $columns[$row['Field']] = true;
    }

    $nameCol = isset($columns['nombre']) ? 'nombre' : (isset($columns['name']) ? 'name' : null);
    $emailCol = isset($columns['correo']) ? 'correo' : (isset($columns['email']) ? 'email' : null);
    $passCol = isset($columns['password']) ? 'password' : (isset($columns['contrasena']) ? 'contrasena' : null);
    $roleCol = isset($columns['role']) ? 'role' : (isset($columns['rol']) ? 'rol' : null);

    if ($emailCol === null || $passCol === null) {
        return;
    }

    $nameExpr = $nameCol !== null ? "COALESCE(NULLIF($nameCol, ''), 'Usuario')" : "'Usuario'";
    $roleExpr = $roleCol !== null ? "COALESCE(NULLIF($roleCol, ''), 'aprendiz')" : "'aprendiz'";

    $sql = "INSERT IGNORE INTO users (name, email, password, role)
            SELECT $nameExpr, $emailCol, $passCol, $roleExpr
            FROM usuarios
            WHERE $emailCol IS NOT NULL AND $emailCol <> ''";

    @$conn->query($sql);
}

function ensure_ordenes_table(mysqli $conn): void
{
    $sql = "CREATE TABLE IF NOT EXISTS ordenes (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NULL,
        product_id INT NULL,
        product_name VARCHAR(150) NOT NULL,
        quantity INT NOT NULL DEFAULT 1,
        price INT NOT NULL DEFAULT 0,
        total_price INT NOT NULL DEFAULT 0,
        status VARCHAR(50) DEFAULT 'pendiente',
        reservation_id INT NULL,
        product_image_url VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_orders_user (user_id),
        INDEX idx_orders_product (product_id),
        INDEX idx_orders_status (status),
        INDEX idx_orders_created_at (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

    $conn->query($sql);

    $reservationCol = $conn->query("SHOW COLUMNS FROM ordenes LIKE 'reservation_id'");
    if ($reservationCol && $reservationCol->num_rows === 0) {
        $conn->query('ALTER TABLE ordenes ADD COLUMN reservation_id INT NULL AFTER product_id');
    }
}

/**
 * Corrige stock descontado dos veces por reservas antiguas (solo una vez).
 */
function repair_legacy_reserved_stock(mysqli $conn): void
{
    $flagFile = __DIR__ . '/storage/.stock_logic_v2';
    if (is_file($flagFile)) {
        return;
    }

    $sql = "UPDATE productos p
            INNER JOIN (
                SELECT product_id, SUM(quantity) AS qty
                FROM reservations
                WHERE status = 'active'
                GROUP BY product_id
            ) r ON r.product_id = p.id
            SET p.stock = p.stock + r.qty";

    $conn->query($sql);
    @file_put_contents($flagFile, date('c'));
}

function get_active_reserved_qty(mysqli $conn, int $productId, ?int $excludeReservationId = null): int
{
    if ($excludeReservationId !== null && $excludeReservationId > 0) {
        $stmt = $conn->prepare(
            "SELECT COALESCE(SUM(quantity), 0) AS qty FROM reservations
             WHERE product_id = ? AND status = 'active' AND id <> ?"
        );
        $stmt->bind_param('ii', $productId, $excludeReservationId);
    } else {
        $stmt = $conn->prepare(
            "SELECT COALESCE(SUM(quantity), 0) AS qty FROM reservations
             WHERE product_id = ? AND status = 'active'"
        );
        $stmt->bind_param('i', $productId);
    }

    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return intval($row['qty'] ?? 0);
}

function get_product_availability(mysqli $conn, int $productId, ?int $excludeReservationId = null): array
{
    $stmt = $conn->prepare('SELECT stock FROM productos WHERE id = ?');
    $stmt->bind_param('i', $productId);
    $stmt->execute();
    $product = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$product) {
        return ['stock' => 0, 'reserved' => 0, 'available' => 0];
    }

    $stock = intval($product['stock']);
    $reserved = get_active_reserved_qty($conn, $productId, $excludeReservationId);
    $available = max(0, $stock - $reserved);

    return ['stock' => $stock, 'reserved' => $reserved, 'available' => $available];
}

function expire_active_reservations(mysqli $conn): void
{
    $conn->query(
        "UPDATE reservations SET status = 'expired'
         WHERE status = 'active' AND expires_at <= NOW()"
    );
}

/**
 * Normaliza rutas guardadas en BD y devuelve URL absoluta servible.
 */
function resolve_image_url(?string $path): string
{
    global $baseUrl;

    if (!is_string($path) || trim($path) === '') {
        return $baseUrl . 'image.php?path=placeholder';
    }

    if (preg_match('/^https?:\/\//i', $path)) {
        return $path;
    }

    $cleanPath = ltrim(str_replace('\\', '/', trim($path)), '/');

    $basename = basename($cleanPath);
    $candidates = array_unique([
        $cleanPath,
        'storage/products/' . $basename,
        'products/' . $basename,
        'storage/' . $basename,
    ]);

    foreach ($candidates as $candidate) {
        $fullPath = __DIR__ . '/' . $candidate;
        if (is_file($fullPath)) {
            $publicPath = strpos($candidate, 'products/') === 0 && strpos($candidate, 'storage/') !== 0
                ? 'storage/products/' . $basename
                : $candidate;
            return $baseUrl . $publicPath;
        }
    }

    $hash = pathinfo($cleanPath, PATHINFO_FILENAME);
    if (preg_match('/[a-f0-9]{6,}$/i', $hash, $m)) {
        $suffix = $m[0];
        $glob = array_merge(
            glob(__DIR__ . '/storage/products/*' . $suffix . '.*') ?: [],
            glob(__DIR__ . '/products/*' . $suffix . '.*') ?: []
        );
        if ($glob && is_file($glob[0])) {
            $relative = 'storage/products/' . basename($glob[0]);
            return $baseUrl . $relative;
        }
    }

    return $baseUrl . 'image.php?path=' . rawurlencode($candidates[0]);
}

function load_local_env(string $key): string
{
    static $cache = null;
    if ($cache === null) {
        $cache = [];
        $envFile = __DIR__ . '/.env';
        if (is_file($envFile)) {
            $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            foreach ($lines as $line) {
                $line = trim($line);
                if ($line === '' || $line[0] === '#') {
                    continue;
                }
                $parts = explode('=', $line, 2);
                if (count($parts) === 2) {
                    $cache[trim($parts[0])] = trim($parts[1]);
                }
            }
        }
    }

    return $cache[$key] ?? (getenv($key) ?: '');
}
