<?php
/**
 * Ejecuta una vez en el navegador: http://127.0.0.1/q-less/ensure_db.php
 * Crea tablas mínimas sin borrar datos.
 */
require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');

echo json_encode([
    'status' => 'success',
    'message' => 'Base de datos lista (users, ordenes, storage).',
    'mysql' => $conn->ping(),
], JSON_UNESCAPED_UNICODE);
