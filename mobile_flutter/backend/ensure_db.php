<?php
/**
 * Ejecuta una vez tras desplegar:
 * https://tu-dominio.com/q-less/ensure_db.php
 */
require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');

$adminEmail = strtolower(trim(load_local_env('ADMIN_EMAIL') ?: 'felipeortiz37@gmail.com'));
$adminStmt = $conn->prepare('SELECT id, name, role FROM users WHERE email = ? LIMIT 1');
$adminStmt->bind_param('s', $adminEmail);
$adminStmt->execute();
$admin = $adminStmt->get_result()->fetch_assoc();
$adminStmt->close();

echo json_encode([
    'status' => 'success',
    'message' => 'Base de datos lista (users, ordenes, reservas, admin).',
    'mysql' => $conn->ping(),
    'base_url' => $baseUrl,
    'admin' => $admin ? [
        'email' => $adminEmail,
        'role' => $admin['role'],
        'password_hint' => 'Usa la contraseña definida en ADMIN_PASSWORD',
    ] : null,
], JSON_UNESCAPED_UNICODE);
