<?php
require_once __DIR__ . '/cors.php';
header('Content-Type: application/json; charset=utf-8');

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/chatbot_helpers.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Método no permitido. Use POST.']);
    exit();
}

try {
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

    $products = fetch_chatbot_products($conn);
    $apiKey = load_local_env('GEMINI_API_KEY');

    if ($apiKey !== '') {
        $historyText = '';
        foreach ($data['history'] as $entry) {
            if (!is_array($entry) || !isset($entry['role'], $entry['content'])) {
                continue;
            }
            $role = strtoupper(trim((string) $entry['role']));
            $content = trim((string) $entry['content']);
            $historyText .= "$role: $content\n";
        }

        $productLines = format_product_lines(filter_products_for_topic($products, $category, $question));

        $systemPrompt = "Eres el asistente de Q-LESS para proyectos escolares. Responde en español, claro y accionable."
            . "\n\nHistorial de conversación:\n"
            . $historyText
            . "\n\nInventario con stock:\n"
            . $productLines
            . "\n\nFormato requerido de respuesta:\n"
            . "MATERIALES\n- Lista breve de materiales necesarios.\n\n"
            . "PASOS\n1. Pasos concretos para realizar el proyecto.\n\n"
            . "DISPONIBLES EN PRODUCTOS\n- Solo menciona productos del inventario con stock que sirvan para el proyecto.\n\n"
            . "CONSEJOS\n- 2 o 3 recomendaciones cortas.\n\n"
            . "No uses Markdown con asteriscos, tablas ni encabezados con #."
            . "\nNo menciones IA, Gemini, APIs ni el tipo de asistente que eres.";

        $geminiText = call_gemini_api($apiKey, $systemPrompt);
        if ($geminiText !== null) {
            send_chatbot_success($geminiText);
        }
    }

    $localResponse = build_local_chatbot_response($question, $category, $products);
    send_chatbot_success($localResponse);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Error interno del chatbot',
        'detail' => $e->getMessage(),
    ], JSON_UNESCAPED_UNICODE);
}
