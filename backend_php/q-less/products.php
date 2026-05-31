<?php
// Limpieza: SIN encabezados CORS (ya los maneja el httpd.conf de Apache)
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

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

function image_url($path) {
    if (!is_string($path) || trim($path) === '') {
        return 'https://via.placeholder.com/600x400?text=No-Image';
    }
    $path = trim($path);
    if (preg_match('/^https?:\/\//i', $path)) {
        return $path;
    }
    $scheme = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https' : 'http';
    $hostUrl = $scheme . '://' . $_SERVER['HTTP_HOST'];
    $cleanPath = ltrim($path, '/');
    
    // Si por alguna razón la ruta ya incluye la palabra 'backend/', se la quitamos para no duplicarla
    if (strpos($cleanPath, 'backend/') === 0) {
        $cleanPath = substr($cleanPath, 8);
    }

    // CORRECCIÓN: Apuntamos directamente a la carpeta backend que es donde están tus imágenes reales
    return $hostUrl . '/backend/' . $cleanPath; 
}

// Lógica de base de datos
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $query = "SELECT p.id, p.nombre, p.descripcion, p.categoria, p.precio, p.stock, p.image_path, COALESCE(SUM(r.quantity),0) AS reserved 
              FROM productos p 
              LEFT JOIN reservations r ON r.product_id = p.id AND r.status = 'active' 
              GROUP BY p.id ORDER BY p.id DESC";

    $result = $conn->query($query);
    $products = [];
    while ($row = $result->fetch_assoc()) {
        $row['image_url'] = image_url($row['image_path']);
        $row['available_stock'] = max(0, $row['stock'] - $row['reserved']);
        $products[] = $row;
    }
    send_json(200, ['status' => 'success', 'data' => $products]);
} else {
    send_json(405, ['status' => 'error', 'message' => 'Método no permitido']);
}
?>