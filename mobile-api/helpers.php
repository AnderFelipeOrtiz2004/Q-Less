<?php

function ensure_default_admin(mysqli $conn): void
{
    ensure_users_table($conn);

    $email = strtolower(trim(load_local_env('ADMIN_EMAIL')));
    if ($email === '') {
        $email = 'felipeortiz37@gmail.com';
    }

    $name = load_local_env('ADMIN_NAME');
    if ($name === '') {
        $name = 'Felipe Ortiz';
    }

    $role = 'admin';
    $plainPassword = load_local_env('ADMIN_PASSWORD');
    if ($plainPassword === '') {
        $plainPassword = 'Felipe117';
    }
    $password = password_hash($plainPassword, PASSWORD_BCRYPT);

    $stmt = $conn->prepare('SELECT id FROM users WHERE email = ? LIMIT 1');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $exists = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($exists) {
        $upd = $conn->prepare('UPDATE users SET name = ?, password = ?, role = ? WHERE email = ?');
        if ($upd) {
            $upd->bind_param('ssss', $name, $password, $role, $email);
            $upd->execute();
            $upd->close();
        }
        return;
    }

    $ins = $conn->prepare('INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, ?)');
    if ($ins) {
        $ins->bind_param('ssss', $name, $email, $password, $role);
        $ins->execute();
        $ins->close();
    }
}

function ensure_demo_products(mysqli $conn): void
{
    $res = $conn->query('SELECT COUNT(*) AS total FROM productos');
    if (!$res) {
        return;
    }
    $row = $res->fetch_assoc();
    $res->free();
    if (intval($row['total'] ?? 0) > 0) {
        return;
    }

    $products = [
        ['Lapiz No2 Negro', 'Lapiz grafito No.2 para dibujo y escritura.', 'Lapices', 800, 120, 'storage/products/lapiz.png'],
        ['Cartulinas de colores', 'Paquete de cartulinas surtidas para maquetas.', 'Cartulinas', 2200, 45, 'storage/products/cartulinas.png'],
        ['Tijeras escolares', 'Tijeras de punta redonda para trabajos manuales.', 'Herramientas', 2400, 30, 'storage/products/tijeras.png'],
        ['Esfero negro', 'Esfero de tinta negra de escritura fluida.', 'Escritura', 1200, 80, 'storage/products/esfero.png'],
        ['Cuaderno 100 hojas', 'Cuaderno rayado de 100 hojas.', 'Cuadernos', 3500, 60, 'storage/products/cuaderno.png'],
    ];

    $stmt = $conn->prepare(
        'INSERT INTO productos (nombre, descripcion, categoria, precio, stock, image_path, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())'
    );
    if (!$stmt) {
        return;
    }

    foreach ($products as $product) {
        [$nombre, $descripcion, $categoria, $precio, $stock, $imagePath] = $product;
        $stmt->bind_param('sssiss', $nombre, $descripcion, $categoria, $precio, $stock, $imagePath);
        $stmt->execute();
    }
    $stmt->close();
}

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

    ensure_users_role_column($conn);
    migrate_legacy_usuarios_table($conn);
}

function ensure_users_role_column(mysqli $conn): void
{
    $check = $conn->query("SHOW COLUMNS FROM users LIKE 'role'");
    if ($check && $check->num_rows > 0) {
        return;
    }

    @$conn->query(
        "ALTER TABLE users ADD COLUMN role VARCHAR(30) NOT NULL DEFAULT 'aprendiz' AFTER password"
    );

    $rolCheck = $conn->query("SHOW COLUMNS FROM users LIKE 'rol'");
    if ($rolCheck && $rolCheck->num_rows > 0) {
        @$conn->query(
            "UPDATE users SET role = CASE
                WHEN LOWER(rol) IN ('admin', 'administrador') THEN 'admin'
                WHEN LOWER(rol) IN ('instructor') THEN 'instructor'
                ELSE 'aprendiz'
            END"
        );
    }
}

function ensure_productos_table(mysqli $conn): void
{
    $conn->query(
        "CREATE TABLE IF NOT EXISTS productos (
            id INT PRIMARY KEY AUTO_INCREMENT,
            nombre VARCHAR(150) NOT NULL,
            descripcion TEXT NULL,
            categoria VARCHAR(80) NOT NULL DEFAULT 'Cuadernos',
            precio INT NOT NULL DEFAULT 0,
            stock INT NOT NULL DEFAULT 0,
            image_path VARCHAR(255) NULL,
            user_id INT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $columns = [
        'categoria' => "VARCHAR(80) NOT NULL DEFAULT 'Cuadernos'",
        'image_path' => 'VARCHAR(255) NULL',
        'user_id' => 'INT NULL',
    ];

    foreach ($columns as $column => $definition) {
        $res = $conn->query("SHOW COLUMNS FROM productos LIKE '$column'");
        if ($res && $res->num_rows === 0) {
            @$conn->query("ALTER TABLE productos ADD COLUMN $column $definition");
        }
    }
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

function deduct_product_stock(mysqli $conn, int $productId, int $quantity): bool
{
    if ($quantity <= 0) {
        return false;
    }
    $stmt = $conn->prepare(
        'UPDATE productos SET stock = stock - ?, updated_at = NOW() WHERE id = ? AND stock >= ?'
    );
    $stmt->bind_param('iii', $quantity, $productId, $quantity);
    $stmt->execute();
    $ok = $stmt->affected_rows === 1;
    $stmt->close();
    return $ok;
}

function restore_product_stock(mysqli $conn, int $productId, int $quantity): void
{
    if ($quantity <= 0) {
        return;
    }
    $stmt = $conn->prepare(
        'UPDATE productos SET stock = stock + ?, updated_at = NOW() WHERE id = ?'
    );
    $stmt->bind_param('ii', $quantity, $productId);
    $stmt->execute();
    $stmt->close();
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

    // El stock en BD ya se descuenta al reservar en el carrito.
    return ['stock' => $stock, 'reserved' => $reserved, 'available' => max(0, $stock)];
}

function expire_active_reservations(mysqli $conn): void
{
    $res = $conn->query(
        "SELECT id, product_id, quantity FROM reservations
         WHERE status = 'active' AND expires_at <= NOW()"
    );
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            restore_product_stock(
                $conn,
                intval($row['product_id']),
                intval($row['quantity'])
            );
        }
        $res->free();
    }

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
