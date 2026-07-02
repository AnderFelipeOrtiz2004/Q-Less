<?php

function get_chatbot_suggestions(): array
{
    return [
        '¿Cómo hacer una maqueta del sistema solar?',
        '¿Qué materiales necesito para un robot escolar?',
        '¿Qué productos hay disponibles ahora?',
        'Ayúdame con un proyecto de cartón',
        'Ideas para una feria de ciencias',
    ];
}

function is_greeting_message(string $text): bool
{
    $lower = mb_strtolower(trim($text), 'UTF-8');
    if ($lower === '') {
        return false;
    }

    $greetings = [
        'hola', 'buenos dias', 'buenos días', 'buenas tardes', 'buenas noches',
        'buen dia', 'buen día', 'hey', 'hi', 'hello', 'saludos', 'que tal', 'qué tal',
    ];

    foreach ($greetings as $greeting) {
        if ($lower === $greeting || str_starts_with($lower, $greeting . ' ') || str_starts_with($lower, $greeting . ',')) {
            return true;
        }
    }

    return false;
}

function contains_profanity(string $text): bool
{
    $lower = mb_strtolower($text, 'UTF-8');
    $patterns = [
        '/\b(mierda|pendejo|pendeja|puta|puto|hijueputa|hp|marica|gonorrea|imbecil|idiota|estupido|estúpido|carajo|verga|cul[oó]|chinga|chingar|joder|coño|cabron|cabrona|malparido|hpta)\b/u',
        '/\b(fuck|shit|bitch|asshole|damn|bastard|dick|pussy)\b/u',
    ];

    foreach ($patterns as $pattern) {
        if (preg_match($pattern, $lower)) {
            return true;
        }
    }

    return false;
}

function build_greeting_response(): string
{
    return "¡Hola! Soy tu asistente de proyectos escolares de Q-LESS.\n\n"
        . "Puedo ayudarte con materiales, pasos, productos con stock y consejos para tu proyecto.\n\n"
        . "Elige una sugerencia o escribe tu pregunta.";
}

function extract_chatbot_category(string $text): string
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

function fetch_chatbot_products(mysqli $conn): array
{
    $products = [];
    if (function_exists('expire_active_reservations')) {
        expire_active_reservations($conn);
    }

    $result = $conn->query(
        'SELECT id, nombre, descripcion, categoria, precio, stock
         FROM productos
         WHERE stock > 0
         ORDER BY nombre ASC
         LIMIT 100'
    );
    if (!$result) {
        return $products;
    }
    while ($row = $result->fetch_assoc()) {
        $products[] = $row;
    }
    return $products;
}

function filter_products_for_topic(array $products, string $category, string $question): array
{
    $terms = array_filter(explode(' ', mb_strtolower($category . ' ' . $question, 'UTF-8')));
    $matched = [];
    foreach ($products as $product) {
        $haystack = mb_strtolower(
            ($product['nombre'] ?? '') . ' ' .
            ($product['categoria'] ?? '') . ' ' .
            ($product['descripcion'] ?? ''),
            'UTF-8'
        );
        foreach ($terms as $term) {
            if (mb_strlen($term) >= 4 && mb_strpos($haystack, $term) !== false) {
                $matched[] = $product;
                break;
            }
        }
    }
    if (count($matched) > 0) {
        return array_slice($matched, 0, 6);
    }
    return array_slice($products, 0, 4);
}

function format_product_lines(array $products): string
{
    if (count($products) === 0) {
        return '- No hay productos con stock en este momento. Revisa la sección Productos de la app.';
    }
    $lines = [];
    foreach ($products as $product) {
        $nombre = trim((string) ($product['nombre'] ?? 'Producto'));
        $categoria = trim((string) ($product['categoria'] ?? 'General'));
        $precio = number_format((float) ($product['precio'] ?? 0), 0, '.', '');
        $stock = (int) ($product['stock'] ?? 0);
        $lines[] = sprintf('- %s · %s · $%s · Stock: %d', $nombre, $categoria, $precio, $stock);
    }
    return implode("\n", $lines);
}

function build_local_chatbot_response(string $question, string $category, array $products): string
{
    $picked = filter_products_for_topic($products, $category, $question);
    $productBlock = format_product_lines($picked);

    $guides = [
        'sistema solar' => [
            'materiales' => [
                'Cartulina o papel de varios colores',
                'Palillos o alambre delgado para sostener planetas',
                'Pelotas de icopor, tapas o bolas pequeñas para planetas',
                'Pegante, cinta y marcadores',
                'Cartón corrugado para la base',
            ],
            'pasos' => [
                'Investiga el orden de los planetas y el tamaño relativo.',
                'Prepara una base circular de cartón y marca las órbitas.',
                'Fabrica el Sol y los planetas con bolas o círculos de cartulina.',
                'Pinta cada planeta con colores representativos.',
                'Coloca los planetas en palillos y fíjalos a la base.',
                'Añade etiquetas con el nombre de cada planeta.',
            ],
            'consejos' => [
                'Usa una escala simplificada; no hace falta tamaño exacto.',
                'Puedes colgar el modelo con hilo para un efecto 3D.',
            ],
        ],
        'maqueta' => [
            'materiales' => ['Cartón', 'Cartulina', 'Pegante', 'Tijeras', 'Regla', 'Pintura o marcadores'],
            'pasos' => [
                'Define escala y partes principales del proyecto.',
                'Corta las piezas en cartón según tu boceto.',
                'Ensambla con pegante y refuerza uniones con cinta.',
                'Pinta y rotula cada parte.',
            ],
            'consejos' => ['Empieza con un boceto en hoja antes de cortar cartón.'],
        ],
        'robot' => [
            'materiales' => ['Cartón', 'Pegante', 'Cables o hilos', 'Motores o piezas recicladas si aplica'],
            'pasos' => [
                'Diseña la estructura del cuerpo en cartón.',
                'Monta ruedas o patas estables.',
                'Integra sensores o luces si tu proyecto lo requiere.',
            ],
            'consejos' => ['Prueba que la base no se caiga antes de decorar.'],
        ],
    ];

    $guide = $guides[$category] ?? [
        'materiales' => [
            'Cartulina o papel',
            'Cartón corrugado',
            'Pegante, tijeras y marcadores',
        ],
        'pasos' => [
            'Define el objetivo del proyecto escolar.',
            'Reúne materiales según la lista.',
            'Arma un prototipo pequeño antes de la versión final.',
            'Presenta resultados con fotos o demostración.',
        ],
        'consejos' => [
            'Revisa el inventario de Q-LESS para materiales con stock.',
            'Divide el trabajo en etapas de 30 minutos.',
        ],
    ];

    $materiales = implode("\n", array_map(fn ($m) => "- $m", $guide['materiales']));
    $pasos = '';
    $n = 1;
    foreach ($guide['pasos'] as $paso) {
        $pasos .= $n . '. ' . $paso . "\n";
        $n++;
    }
    $consejos = implode("\n", array_map(fn ($c) => '- ' . $c, $guide['consejos']));

    return trim(
        "MATERIALES\n$materiales\n\n" .
        "PASOS\n$pasos\n" .
        "DISPONIBLES EN PRODUCTOS\n$productBlock\n\n" .
        "CONSEJOS\n$consejos"
    );
}

function call_gemini_api(string $apiKey, string $systemPrompt): ?string
{
    $payload = json_encode([
        'contents' => [['parts' => [['text' => $systemPrompt]]]],
        'generationConfig' => [
            'temperature' => 0.85,
            'maxOutputTokens' => 1200,
            'topP' => 0.92,
        ],
    ]);

    $models = [
        'v1beta/models/gemini-2.5-flash:generateContent',
        'v1beta/models/gemini-2.0-flash:generateContent',
        'v1beta/models/gemini-1.5-flash:generateContent',
    ];

    foreach ($models as $modelPath) {
        $endpoint = 'https://generativelanguage.googleapis.com/' . $modelPath . '?key=' . urlencode($apiKey);
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
        curl_close($ch);

        if ($httpCode === 200 && is_string($response)) {
            $responseData = json_decode($response, true);
            $text = $responseData['candidates'][0]['content']['parts'][0]['text'] ?? null;
            if (is_string($text) && trim($text) !== '') {
                return trim($text);
            }
        }
    }

    return null;
}

function sanitize_chatbot_response(string $text): string
{
    $lines = preg_split("/\r\n|\r|\n/", $text);
    $blocked = '/gemini|modo local|inteligencia artificial|cuota de|api de|proveedor|asistente virtual/i';
    $cleaned = [];
    foreach ($lines as $line) {
        if (!preg_match($blocked, $line)) {
            $cleaned[] = $line;
        }
    }
    $result = trim(preg_replace("/\n{3,}/", "\n\n", implode("\n", $cleaned)));
    return $result !== '' ? $result : $text;
}

function send_chatbot_success(string $botResponse, array $extra = []): void
{
    $payload = array_merge(
        ['bot_response' => sanitize_chatbot_response($botResponse)],
        $extra
    );

    echo json_encode([
        'status' => 'success',
        'data' => $payload,
    ], JSON_UNESCAPED_UNICODE);
    exit();
}
