<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido. Use POST.',
    ]);
    exit;
}

$body = file_get_contents('php://input');
$data = json_decode($body, true);

if (!is_array($data) || !isset($data['history']) || !is_array($data['history'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Payload inválido. Se espera {"history": [{"role":"user","content":"..."}, ...]}.',
    ]);
    exit;
}

$apiKey = getenv('GEMINI_API_KEY') ?: '';
if (empty($apiKey)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'La variable de entorno GEMINI_API_KEY no está configurada en el servidor.',
    ]);
    exit;
}

$historyText = '';
foreach ($data['history'] as $entry) {
    if (!is_array($entry) || !isset($entry['role']) || !isset($entry['content'])) {
        continue;
    }
    $role = strtoupper(trim($entry['role']));
    $content = trim($entry['content']);
    $historyText .= "$role: $content\n";
}

$systemPrompt = "Eres el asistente de Q-LESS para proyectos escolares. Responde en español, claro y accionable."
    . "\n\nUtiliza el historial de conversación para mantener contexto y evita repetir instrucciones ya dadas.";

$fullPrompt = $systemPrompt
    . "\n\nHistorial de conversación:\n"
    . $historyText
    . "\n\nFormato requerido de respuesta:\n"
    . "MATERIALES\n- Lista breve de materiales necesarios.\n\n"
    . "PASOS\n1. Pasos concretos para realizar el proyecto.\n\n"
    . "DISPONIBLES EN PRODUCTOS\n- Solo menciona productos del inventario con stock que sirvan para el proyecto.\n\n"
    . "CONSEJOS\n- 2 o 3 recomendaciones cortas.\n\n"
    . "No uses Markdown con asteriscos, tablas ni encabezados con #.";

$payload = json_encode([
    'prompt' => [
        'text' => $fullPrompt,
    ],
    'temperature' => 0.7,
    'max_output_tokens' => 800,
]);

$ch = curl_init();
$endpoint = 'https://generativelanguage.googleapis.com/v1beta2/models/gemini-1.5-flash:generateText?key=' . urlencode($apiKey);

curl_setopt($ch, CURLOPT_URL, $endpoint);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json; charset=utf-8',
]);
curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$curlError = curl_error($ch);
curl_close($ch);

if ($response === false || $httpCode !== 200) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error en la llamada a la API generativa: ' . ($curlError ?: "HTTP $httpCode"),
    ]);
    exit;
}

$responseData = json_decode($response, true);
if (!is_array($responseData)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Respuesta inválida del proveedor de IA.',
    ]);
    exit;
}

$botResponse = null;
if (isset($responseData['candidates'][0]['content'])) {
    $botResponse = $responseData['candidates'][0]['content'];
} elseif (isset($responseData['output'][0]['content'][0]['text'])) {
    $botResponse = $responseData['output'][0]['content'][0]['text'];
}

if (empty($botResponse)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'No se obtuvo contenido válido de la API generativa.',
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'bot_response' => trim($botResponse),
]);
