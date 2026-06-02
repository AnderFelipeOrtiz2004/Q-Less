<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Método no permitido. Use POST.']);
    exit();
}

$body = file_get_contents('php://input');
$data = json_decode($body, true);

if (!is_array($data) || !isset($data['history']) || !is_array($data['history'])) {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'Payload inválido. Se espera {"history": [{"role":"user","content":"..."}, ...]}.',
    ]);
    exit();
}

$userId = isset($data['user_id']) ? intval($data['user_id']) : null;

$conn->query(
    "CREATE TABLE IF NOT EXISTS chatbot_historial (
        id INT PRIMARY KEY AUTO_INCREMENT,
        user_id INT NULL,
        pregunta TEXT NOT NULL,
        categoria VARCHAR(100) NULL,
        fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_id (user_id),
        INDEX idx_categoria (categoria),
        INDEX idx_fecha (fecha)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
);

$question = '';
foreach ($data['history'] as $entry) {
    if (!is_array($entry) || !isset($entry['role'], $entry['content'])) {
        continue;
    }
    if (strtolower(trim((string) $entry['role'])) === 'user') {
        $question = trim((string) $entry['content']);
    }
}

$category = isset($data['categoria']) && trim((string) $data['categoria']) !== ''
    ? trim((string) $data['categoria'])
    : extract_chatbot_category($question);

if ($question !== '') {
    $insertStmt = $conn->prepare(
        'INSERT INTO chatbot_historial (user_id, pregunta, categoria, fecha) VALUES (?, ?, ?, NOW())'
    );
    if ($insertStmt) {
        $userIdParam = $userId ?? 0;
        $insertStmt->bind_param('iss', $userIdParam, $question, $category);
        $insertStmt->execute();
        $insertStmt->close();
    }
}

$apiKey = load_local_env('GEMINI_API_KEY');
if ($apiKey === '') {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Configura GEMINI_API_KEY en q-less/.env',
    ]);
    exit();
}

$historyText = '';
foreach ($data['history'] as $entry) {
    if (!is_array($entry) || !isset($entry['role'], $entry['content'])) {
        continue;
    }
    $role = strtoupper(trim((string) $entry['role']));
    $content = trim((string) $entry['content']);
    $historyText .= "$role: $content\n";
}

$systemPrompt = "Eres el asistente de Q-LESS para proyectos escolares. Responde en español, claro y accionable."
    . "\n\nHistorial de conversación:\n"
    . $historyText
    . "\n\nFormato requerido de respuesta:\n"
    . "MATERIALES\n- Lista breve de materiales necesarios.\n\n"
    . "PASOS\n1. Pasos concretos para realizar el proyecto.\n\n"
    . "DISPONIBLES EN PRODUCTOS\n- Solo menciona productos del inventario con stock que sirvan para el proyecto.\n\n"
    . "CONSEJOS\n- 2 o 3 recomendaciones cortas.\n\n"
    . "No uses Markdown con asteriscos, tablas ni encabezados con #.";

$payload = json_encode([
    'contents' => [
        [
            'parts' => [
                ['text' => $systemPrompt],
            ],
        ],
    ],
    'generationConfig' => [
        'temperature' => 0.7,
        'maxOutputTokens' => 800,
    ],
]);

$endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key='
    . urlencode($apiKey);

$ch = curl_init($endpoint);
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Content-Type: application/json; charset=utf-8'],
    CURLOPT_POSTFIELDS => $payload,
    CURLOPT_TIMEOUT => 45,
]);

$response = curl_exec($ch);
$httpCode = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($response === false || $httpCode !== 200) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Error en la API de Gemini: ' . ($curlError ?: "HTTP $httpCode"),
    ]);
    exit();
}

$responseData = json_decode($response, true);
$botResponse = $responseData['candidates'][0]['content']['parts'][0]['text'] ?? null;

if (!is_string($botResponse) || trim($botResponse) === '') {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'No se obtuvo respuesta válida del asistente.',
    ]);
    exit();
}

echo json_encode([
    'status' => 'success',
    'data' => [
        'bot_response' => trim($botResponse),
    ],
]);

function extract_chatbot_category($text)
{
    $lower = mb_strtolower($text, 'UTF-8');
    $categories = [
        'sistema solar' => ['sistema solar', 'planeta', 'planetas', 'luna', 'sol', 'marte', 'venus', 'jupiter', 'júpiter', 'saturno', 'urano', 'neptuno', 'tierra'],
        'cartón' => ['cartón', 'carton', 'corrugado', 'caja', 'cartulina'],
        'maqueta' => ['maqueta', 'modelo', 'escala', 'proyecto', 'maquet'],
        'robot' => ['robot', 'robótica', 'robotica', 'arduino', 'motores', 'sensores'],
        'papel' => ['papel', 'cartulina', 'origami', 'folleto'],
        'madera' => ['madera', 'palillo', 'balsa', 'tabla'],
    ];
    foreach ($categories as $category => $terms) {
        foreach ($terms as $term) {
            if (mb_strpos($lower, $term) !== false) {
                return $category;
            }
        }
    }
    return 'general';
}
