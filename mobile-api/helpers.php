<?php

function ensure_default_admin(mysqli $conn): void
{
    ensure_users_table($conn);
    upsert_admin_user(
        $conn,
        admin_env_email(),
        admin_env_password(),
        load_local_env('ADMIN_NAME') ?: 'Felipe Ortiz'
    );
}

function upsert_admin_user(mysqli $conn, string $email, string $plainPassword, string $name = 'Administrador'): void
{
    $email = strtolower(trim($email));
    if ($email === '') {
        return;
    }

    $role = 'admin';
    $passwordHash = password_hash($plainPassword, PASSWORD_BCRYPT);

    $stmt = $conn->prepare('SELECT id, password FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1');
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        $userId = (int) $existing['id'];
        $upd = $conn->prepare(
            'UPDATE users SET name = ?, email = ?, password = ?, role = ?, email_verified = 1, purchases_enabled = 1 WHERE id = ?'
        );
        if ($upd) {
            $upd->bind_param('ssssi', $name, $email, $passwordHash, $role, $userId);
            $upd->execute();
            $upd->close();
        }
        if (table_has_column($conn, 'users', 'rol')) {
            @$conn->query("UPDATE users SET rol = 'admin' WHERE id = " . $userId);
        }
        return;
    }

    $ins = $conn->prepare(
        'INSERT INTO users (name, email, password, role, email_verified, purchases_enabled, created_at, updated_at)
         VALUES (?, ?, ?, ?, 1, 1, NOW(), NOW())'
    );
    if ($ins) {
        $ins->bind_param('ssss', $name, $email, $passwordHash, $role);
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

function admin_env_email(): string
{
    $email = strtolower(trim(load_local_env('ADMIN_EMAIL')));
    if ($email !== '') {
        return $email;
    }
    return 'ortizgarciafelipe37@gmail.com';
}

function admin_env_password(): string
{
    $pass = load_local_env('ADMIN_PASSWORD');
    return $pass !== '' ? $pass : 'Felipe117';
}

function admin_credentials_match(string $email, string $password): bool
{
    $email = strtolower(trim($email));
    if (!hash_equals(admin_env_password(), $password)) {
        return false;
    }

    $allowedEmails = array_unique([
        admin_env_email(),
        'admin@qless.app',
        'ortizgarciafelipe37@gmail.com',
    ]);

    return in_array($email, $allowedEmails, true);
}

function is_designated_admin_email(string $email): bool
{
    $email = strtolower(trim($email));
    $allowedEmails = array_unique([
        admin_env_email(),
        'admin@qless.app',
        'ortizgarciafelipe37@gmail.com',
    ]);

    return in_array($email, $allowedEmails, true);
}

function is_gmail_email(string $email): bool
{
    $email = strtolower(trim($email));
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }

    $domain = substr(strrchr($email, '@') ?: '', 1);
    return in_array($domain, ['gmail.com', 'googlemail.com'], true);
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
    ensure_users_profile_columns($conn);
    ensure_users_commerce_columns($conn);
    migrate_legacy_usuarios_table($conn);
    sync_users_display_names($conn);
    sync_users_display_names_v2($conn);
}

function ensure_users_commerce_columns(mysqli $conn): void
{
    $columns = [
        'email_verified' => 'TINYINT(1) NOT NULL DEFAULT 0',
        'purchases_enabled' => 'TINYINT(1) NOT NULL DEFAULT 0',
    ];

    foreach ($columns as $column => $definition) {
        $res = $conn->query("SHOW COLUMNS FROM users LIKE '$column'");
        if ($res && $res->num_rows === 0) {
            @$conn->query("ALTER TABLE users ADD COLUMN $column $definition");
        }
    }

    ensure_users_terms_columns($conn);

    $flagFile = __DIR__ . '/storage/.users_commerce_v1';
    if (!is_file($flagFile)) {
        @$conn->query('UPDATE users SET email_verified = 1');
        $adminWhere = "LOWER(role) = 'admin'";
        $rolCheck = $conn->query("SHOW COLUMNS FROM users LIKE 'rol'");
        if ($rolCheck && $rolCheck->num_rows > 0) {
            $adminWhere = "(LOWER(role) = 'admin' OR LOWER(rol) = 'admin')";
        }
        @$conn->query("UPDATE users SET purchases_enabled = 1 WHERE {$adminWhere}");
        @file_put_contents($flagFile, date('c'));
    }
}

function ensure_users_terms_columns(mysqli $conn): void
{
    $columns = [
        'terms_accepted' => 'TINYINT(1) NOT NULL DEFAULT 0',
        'terms_accepted_at' => 'DATETIME NULL',
        'privacy_version' => "VARCHAR(20) NULL DEFAULT '1.0'",
    ];

    foreach ($columns as $column => $definition) {
        $res = $conn->query("SHOW COLUMNS FROM users LIKE '$column'");
        if ($res && $res->num_rows === 0) {
            @$conn->query("ALTER TABLE users ADD COLUMN $column $definition");
        }
    }

    $flagFile = __DIR__ . '/storage/.users_terms_v1';
    if (!is_file($flagFile)) {
        @$conn->query('UPDATE users SET terms_accepted = 1, privacy_version = \'1.0\' WHERE terms_accepted = 0');
        @file_put_contents($flagFile, date('c'));
    }
}

function ensure_users_profile_columns(mysqli $conn): void
{
    $columns = [
        'avatar_path' => 'VARCHAR(255) NULL',
        'description' => 'TEXT NULL',
    ];

    foreach ($columns as $column => $definition) {
        $res = $conn->query("SHOW COLUMNS FROM users LIKE '$column'");
        if ($res && $res->num_rows === 0) {
            @$conn->query("ALTER TABLE users ADD COLUMN $column $definition");
        }
    }
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

function repair_null_timestamps(mysqli $conn, ?string $table = null): void
{
    $tables = $table !== null ? [$table] : ['users', 'productos'];

    foreach ($tables as $target) {
        $exists = $conn->query("SHOW TABLES LIKE '{$target}'");
        if (!$exists || $exists->num_rows === 0) {
            continue;
        }

        $res = $conn->query("SHOW COLUMNS FROM `$target` LIKE 'created_at'");
        if (!$res || $res->num_rows === 0) {
            continue;
        }

        @$conn->query(
            "UPDATE `$target` SET created_at = NOW()
             WHERE created_at IS NULL
                OR created_at = ''
                OR YEAR(created_at) < 2000"
        );

        $resUpd = $conn->query("SHOW COLUMNS FROM `$target` LIKE 'updated_at'");
        if ($resUpd && $resUpd->num_rows > 0) {
            @$conn->query(
                "UPDATE `$target` SET updated_at = COALESCE(NULLIF(updated_at, ''), created_at, NOW())
                 WHERE updated_at IS NULL
                    OR updated_at = ''
                    OR YEAR(updated_at) < 2000"
            );
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

    $paymentColumns = [
        'payment_url' => 'VARCHAR(500) NULL',
        'mp_preference_id' => 'VARCHAR(120) NULL',
        'mp_external_reference' => 'VARCHAR(120) NULL',
    ];
    foreach ($paymentColumns as $column => $definition) {
        $res = $conn->query("SHOW COLUMNS FROM ordenes LIKE '$column'");
        if ($res && $res->num_rows === 0) {
            @$conn->query("ALTER TABLE ordenes ADD COLUMN $column $definition");
        }
    }

    migrate_ordenes_user_ids_to_users($conn);
}

function migrate_ordenes_user_ids_to_users(mysqli $conn): void
{
    $flagFile = __DIR__ . '/storage/.ordenes_users_sync_v2';
    if (is_file($flagFile)) {
        return;
    }

    $legacy = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if (!$legacy || $legacy->num_rows === 0) {
        @file_put_contents($flagFile, date('c'));
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

    $emailCol = isset($columns['correo']) ? 'correo' : (isset($columns['email']) ? 'email' : null);
    if ($emailCol === null) {
        @file_put_contents($flagFile, date('c'));
        return;
    }

    @$conn->query(
        "UPDATE ordenes o
         INNER JOIN usuarios leg ON leg.id = o.user_id
         INNER JOIN users u ON LOWER(TRIM(u.email)) = LOWER(TRIM(leg.$emailCol))
         SET o.user_id = u.id
         WHERE o.user_id <> u.id"
    );

    @file_put_contents($flagFile, date('c'));
}

function normalize_storage_image_path(?string $path): string
{
    $path = trim((string) $path);
    if ($path === '') {
        return '';
    }

    if (preg_match('#(storage/(?:products|productos|avatars)/[^\s?]+)#i', $path, $matches)) {
        return $matches[1];
    }

    if (str_starts_with($path, 'storage/')) {
        return $path;
    }

    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }

    if (preg_match('/^blob:/i', $path) || stripos($path, 'data:image/') !== false) {
        return '';
    }

    return $path;
}

function legacy_usuarios_name_expr(string $alias = 'leg'): string
{
    global $conn;

    $legacy = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if (!$legacy || $legacy->num_rows === 0) {
        return 'NULL';
    }

    $columns = [];
    $result = $conn->query('SHOW COLUMNS FROM usuarios');
    if (!$result) {
        return 'NULL';
    }
    while ($row = $result->fetch_assoc()) {
        $columns[$row['Field']] = true;
    }

    $parts = [];
    if (isset($columns['nombre'])) {
        $parts[] = "NULLIF(TRIM($alias.nombre), '')";
    }
    if (isset($columns['name'])) {
        $parts[] = "NULLIF(TRIM($alias.name), '')";
    }
    if (isset($columns['correo'])) {
        $parts[] = "NULLIF(TRIM($alias.correo), '')";
    }
    if (isset($columns['email'])) {
        $parts[] = "NULLIF(TRIM($alias.email), '')";
    }

    return $parts === [] ? 'NULL' : 'COALESCE(' . implode(', ', $parts) . ')';
}

function orders_buyer_name_sql_expr(): string
{
    global $conn;

    $usersExpr = users_name_sql_expr('u', "''");
    $legacyExpr = legacy_usuarios_name_expr('leg');
    $legacyTable = $conn->query("SHOW TABLES LIKE 'usuarios'");
    $hasLegacy = $legacyTable && $legacyTable->num_rows > 0;

    if ($hasLegacy) {
        return "COALESCE(NULLIF($usersExpr, ''), $legacyExpr, CONCAT('Usuario ', o.user_id))";
    }

    return "COALESCE(NULLIF($usersExpr, ''), CONCAT('Usuario ', o.user_id))";
}

function order_buyer_is_eligible(array $row): bool
{
    $email = strtolower(trim((string) ($row['user_email'] ?? '')));
    $verified = intval($row['email_verified'] ?? 0) === 1;

    return $email !== ''
        && is_gmail_email($email)
        && $verified;
}

function user_can_purchase(mysqli $conn, int $userId): array
{
    $stmt = $conn->prepare(
        "SELECT id, email,
                COALESCE(email_verified, 1) AS email_verified,
                COALESCE(purchases_enabled, 0) AS purchases_enabled
         FROM users WHERE id = ? LIMIT 1"
    );
    $stmt->bind_param('i', $userId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        return ['ok' => false, 'message' => 'Usuario no encontrado'];
    }
    if (!is_gmail_email((string) $user['email'])) {
        return ['ok' => false, 'message' => 'Solo cuentas Gmail pueden comprar en Q-LESS.'];
    }
    if (intval($user['email_verified']) !== 1) {
        return ['ok' => false, 'message' => 'Debes verificar tu correo Gmail antes de comprar.'];
    }
    if (intval($user['purchases_enabled']) !== 1) {
        return [
            'ok' => false,
            'message' => 'Tus compras aún no están habilitadas. Un administrador debe activarlas.',
            'code' => 'purchases_disabled',
        ];
    }

    return ['ok' => true, 'user' => $user];
}

function table_has_column(mysqli $conn, string $table, string $column): bool
{
    static $cache = [];
    $key = $table . '.' . $column;
    if (array_key_exists($key, $cache)) {
        return $cache[$key];
    }

    $safeTable = preg_replace('/[^a-z0-9_]/i', '', $table);
    $safeColumn = preg_replace('/[^a-z0-9_]/i', '', $column);
    $res = $conn->query("SHOW COLUMNS FROM `$safeTable` LIKE '$safeColumn'");
    $cache[$key] = $res && $res->num_rows > 0;

    return $cache[$key];
}

function users_role_sql_expr(string $alias = ''): string
{
    global $conn;

    $prefix = $alias !== '' ? $alias . '.' : '';
    $hasRole = table_has_column($conn, 'users', 'role');
    $hasRol = table_has_column($conn, 'users', 'rol');

    if ($hasRole && $hasRol) {
        return "COALESCE(NULLIF({$prefix}role, ''), NULLIF({$prefix}rol, ''), 'aprendiz')";
    }
    if ($hasRole) {
        return "COALESCE(NULLIF({$prefix}role, ''), 'aprendiz')";
    }
    if ($hasRol) {
        return "COALESCE(NULLIF({$prefix}rol, ''), 'aprendiz')";
    }

    return "'aprendiz'";
}

function users_name_sql_expr(string $alias = 'u', string $fallbackIdExpr = ''): string
{
    global $conn;

    $prefix = $alias !== '' ? $alias . '.' : '';
    $parts = [];

    if (table_has_column($conn, 'users', 'name')) {
        $parts[] = "NULLIF(TRIM({$prefix}name), '')";
    }
    if (table_has_column($conn, 'users', 'nombre')) {
        $parts[] = "NULLIF(TRIM({$prefix}nombre), '')";
    }
    if (table_has_column($conn, 'users', 'email')) {
        $parts[] = "NULLIF(TRIM({$prefix}email), '')";
    }

    $fallback = $fallbackIdExpr !== ''
        ? $fallbackIdExpr
        : ($alias !== '' ? "CONCAT('Usuario ', {$alias}.id)" : "CONCAT('Usuario ', o.user_id)");

    if ($parts === []) {
        return $fallback;
    }

    return 'COALESCE(' . implode(', ', $parts) . ", $fallback)";
}

function sync_users_display_names(mysqli $conn): void
{
    $flagFile = __DIR__ . '/storage/.users_names_sync_v1';
    if (is_file($flagFile)) {
        return;
    }

    if (table_has_column($conn, 'users', 'nombre') && table_has_column($conn, 'users', 'name')) {
        @$conn->query(
            "UPDATE users
             SET name = nombre
             WHERE (name IS NULL OR TRIM(name) = '')
               AND nombre IS NOT NULL
               AND TRIM(nombre) <> ''"
        );
    }

    if (table_has_column($conn, 'users', 'name') && table_has_column($conn, 'users', 'email')) {
        @$conn->query(
            "UPDATE users
             SET name = SUBSTRING_INDEX(email, '@', 1)
             WHERE name IS NULL OR TRIM(name) = ''"
        );
    }

    @file_put_contents($flagFile, date('c'));
}

function sync_users_display_names_v2(mysqli $conn): void
{
    $flagFile = __DIR__ . '/storage/.users_names_sync_v2';
    if (is_file($flagFile)) {
        return;
    }

    if (table_has_column($conn, 'users', 'name') && table_has_column($conn, 'users', 'email')) {
        @$conn->query(
            "UPDATE users
             SET name = SUBSTRING_INDEX(email, '@', 1)
             WHERE name IS NULL OR TRIM(name) = ''"
        );
    }

    $legacy = $conn->query("SHOW TABLES LIKE 'usuarios'");
    if ($legacy && $legacy->num_rows > 0) {
        $columns = [];
        $result = $conn->query('SHOW COLUMNS FROM usuarios');
        while ($row = $result->fetch_assoc()) {
            $columns[$row['Field']] = true;
        }

        $emailCol = isset($columns['correo']) ? 'correo' : (isset($columns['email']) ? 'email' : null);
        $nameCol = isset($columns['nombre']) ? 'nombre' : (isset($columns['name']) ? 'name' : null);

        if ($emailCol !== null && $nameCol !== null) {
            @$conn->query(
                "UPDATE users u
                 INNER JOIN usuarios leg ON LOWER(TRIM(u.email)) = LOWER(TRIM(leg.$emailCol))
                 SET u.name = leg.$nameCol
                 WHERE (u.name IS NULL OR TRIM(u.name) = '')
                   AND leg.$nameCol IS NOT NULL
                   AND TRIM(leg.$nameCol) <> ''"
            );
        }
    }

    @file_put_contents($flagFile, date('c'));
}

function format_order_row(array $row): array
{
    $row['product_image_url'] = resolve_image_url($row['product_image_url'] ?? null);

    $userName = trim((string) ($row['user_name'] ?? ''));
    $userEmail = trim((string) ($row['user_email'] ?? ''));
    $userId = (int) ($row['user_id'] ?? 0);

    if ($userEmail === '' && isset($row['correo'])) {
        $userEmail = trim((string) $row['correo']);
        $row['user_email'] = $userEmail;
    }

    if ($userName === '' || preg_match('/^Usuario\s+\d+$/i', $userName)) {
        $row['user_name'] = $userEmail !== ''
            ? $userEmail
            : ($userId > 0 ? 'Usuario ' . $userId : 'Usuario');
    }

    $row['email_verified'] = intval($row['email_verified'] ?? 0) === 1;
    $row['buyer_eligible'] = order_buyer_is_eligible($row);

    return $row;
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

function cart_reservations_table_exists(mysqli $conn): bool
{
    static $exists = null;
    if ($exists !== null) {
        return $exists;
    }

    $res = $conn->query("SHOW TABLES LIKE 'cart_reservations'");
    $exists = $res && $res->num_rows > 0;
    return $exists;
}

function get_mobile_reserved_qty(mysqli $conn, int $productId, ?int $excludeReservationId = null): int
{
    if ($excludeReservationId !== null && $excludeReservationId > 0) {
        $stmt = $conn->prepare(
            "SELECT COALESCE(SUM(quantity), 0) AS qty FROM reservations
             WHERE product_id = ? AND status = 'active' AND expires_at > NOW() AND id <> ?"
        );
        $stmt->bind_param('ii', $productId, $excludeReservationId);
    } else {
        $stmt = $conn->prepare(
            "SELECT COALESCE(SUM(quantity), 0) AS qty FROM reservations
             WHERE product_id = ? AND status = 'active' AND expires_at > NOW()"
        );
        $stmt->bind_param('i', $productId);
    }

    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return intval($row['qty'] ?? 0);
}

function get_web_only_cart_reserved_qty(mysqli $conn, int $productId): int
{
    if (!cart_reservations_table_exists($conn)) {
        return 0;
    }

    $stmt = $conn->prepare(
        "SELECT COALESCE(SUM(cr.cantidad), 0) AS qty FROM cart_reservations cr
         WHERE cr.producto_id = ? AND cr.status = 'active' AND cr.expires_at > NOW()
         AND NOT EXISTS (
             SELECT 1 FROM reservations r
             WHERE r.user_id = cr.user_id AND r.product_id = cr.producto_id
             AND r.status = 'active' AND r.expires_at > NOW()
         )"
    );
    $stmt->bind_param('i', $productId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    return intval($row['qty'] ?? 0);
}

function get_active_reserved_qty(mysqli $conn, int $productId, ?int $excludeReservationId = null): int
{
    return get_mobile_reserved_qty($conn, $productId, $excludeReservationId)
        + get_web_only_cart_reserved_qty($conn, $productId);
}

function sync_web_cart_reservation(
    mysqli $conn,
    int $userId,
    int $productId,
    int $quantity,
    string $expiresAt
): void {
    if (!cart_reservations_table_exists($conn) || $userId <= 0 || $productId <= 0 || $quantity <= 0) {
        return;
    }

    $stmt = $conn->prepare(
        "SELECT id FROM cart_reservations
         WHERE user_id = ? AND producto_id = ? AND status = 'active' LIMIT 1"
    );
    $stmt->bind_param('ii', $userId, $productId);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        $upd = $conn->prepare(
            "UPDATE cart_reservations
             SET cantidad = ?, expires_at = ?, updated_at = NOW()
             WHERE id = ?"
        );
        $id = intval($existing['id']);
        $upd->bind_param('isi', $quantity, $expiresAt, $id);
        $upd->execute();
        $upd->close();
        return;
    }

    $ins = $conn->prepare(
        "INSERT INTO cart_reservations (user_id, producto_id, cantidad, status, expires_at, created_at, updated_at)
         VALUES (?, ?, ?, 'active', ?, NOW(), NOW())"
    );
    $ins->bind_param('iiis', $userId, $productId, $quantity, $expiresAt);
    $ins->execute();
    $ins->close();
}

function release_web_cart_mirror(mysqli $conn, int $userId, int $productId): void
{
    if (!cart_reservations_table_exists($conn) || $userId <= 0 || $productId <= 0) {
        return;
    }

    $stmt = $conn->prepare(
        "UPDATE cart_reservations
         SET status = 'released', updated_at = NOW()
         WHERE user_id = ? AND producto_id = ? AND status = 'active'"
    );
    $stmt->bind_param('ii', $userId, $productId);
    $stmt->execute();
    $stmt->close();
}

function mark_web_cart_purchased(mysqli $conn, int $userId, int $productId): void
{
    if (!cart_reservations_table_exists($conn) || $userId <= 0 || $productId <= 0) {
        return;
    }

    $stmt = $conn->prepare(
        "UPDATE cart_reservations
         SET status = 'purchased', purchased_at = NOW(), updated_at = NOW()
         WHERE user_id = ? AND producto_id = ? AND status = 'active'"
    );
    $stmt->bind_param('ii', $userId, $productId);
    $stmt->execute();
    $stmt->close();
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
        "SELECT id, user_id, product_id, quantity FROM reservations
         WHERE status = 'active' AND expires_at <= NOW()"
    );
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            restore_product_stock(
                $conn,
                intval($row['product_id']),
                intval($row['quantity'])
            );
            release_web_cart_mirror(
                $conn,
                intval($row['user_id']),
                intval($row['product_id'])
            );
        }
        $res->free();
    }

    $conn->query(
        "UPDATE reservations SET status = 'expired'
         WHERE status = 'active' AND expires_at <= NOW()"
    );

    if (!cart_reservations_table_exists($conn)) {
        return;
    }

    $webRes = $conn->query(
        "SELECT cr.id, cr.user_id, cr.producto_id, cr.cantidad FROM cart_reservations cr
         WHERE cr.status = 'active' AND cr.expires_at <= NOW()
         AND NOT EXISTS (
             SELECT 1 FROM reservations r
             WHERE r.user_id = cr.user_id AND r.product_id = cr.producto_id
             AND r.status = 'active'
         )"
    );
    if ($webRes) {
        while ($row = $webRes->fetch_assoc()) {
            restore_product_stock(
                $conn,
                intval($row['producto_id']),
                intval($row['cantidad'])
            );
        }
        $webRes->free();
    }

    $conn->query(
        "UPDATE cart_reservations
         SET status = 'released', updated_at = NOW()
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
        'storage/productos/' . $basename,
        'products/' . $basename,
        'productos/' . $basename,
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
            glob(__DIR__ . '/storage/productos/*' . $suffix . '.*') ?: [],
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
                    $cache[trim($parts[0])] = trim($parts[1], " \t\"'");
                }
            }
        }
    }

    return $cache[$key] ?? (getenv($key) ?: '');
}
