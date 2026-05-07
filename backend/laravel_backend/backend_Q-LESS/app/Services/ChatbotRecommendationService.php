<?php

namespace App\Services;

use App\Models\Producto;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

class ChatbotRecommendationService
{
    public function recommend(string $message): array
    {
        $fallbackRecommendation = $this->buildInventoryRecommendation($message);
        $provider = (string) config('services.openai.provider', 'local');
        $apiKey = trim((string) config('services.openai.api_key'));

        if ($provider !== 'openai' || $apiKey === '') {
            $fallbackRecommendation['notes'] = array_values(array_filter(
                $fallbackRecommendation['notes'],
                fn ($note) => !str_contains($note, 'OpenAI')
            ));

            return $fallbackRecommendation;
        }

        try {
            $inventory = $this->inventorySnapshot();
            $openAiRecommendation = $this->recommendWithOpenAI($message, $inventory);

            $openAiRecommendation['status'] = true;
            $openAiRecommendation['query'] = $message;
            $openAiRecommendation['notes'] = array_values(array_unique(array_merge(
                $openAiRecommendation['notes'] ?? [],
                ['La respuesta fue generada con OpenAI usando el inventario actual de Q-LESS.']
            )));

            return $this->normalizeResponseShape($openAiRecommendation, $fallbackRecommendation);
        } catch (Throwable $exception) {
            Log::warning('Fallo la integracion con OpenAI para el chatbot.', [
                'message' => $message,
                'error' => $exception->getMessage(),
            ]);

            $fallbackRecommendation['notes'][] = 'Se uso la recomendacion local para mantener el chat disponible.';

            return $fallbackRecommendation;
        }
    }

    private function recommendWithOpenAI(string $message, array $inventory): array
    {
        $response = Http::withToken(config('services.openai.api_key'))
            ->timeout((int) config('services.openai.timeout', 25))
            ->acceptJson()
            ->post('https://api.openai.com/v1/responses', [
                'model' => config('services.openai.model', 'gpt-5.4-mini'),
                'input' => [
                    [
                        'role' => 'system',
                        'content' => [
                            [
                                'type' => 'input_text',
                                'text' => $this->buildSystemPrompt(),
                            ],
                        ],
                    ],
                    [
                        'role' => 'user',
                        'content' => [
                            [
                                'type' => 'input_text',
                                'text' => $this->buildUserPrompt($message, $inventory),
                            ],
                        ],
                    ],
                ],
                'text' => [
                    'format' => [
                        'type' => 'json_schema',
                        'name' => 'inventory_recommendation',
                        'strict' => true,
                        'schema' => $this->responseSchema(),
                    ],
                ],
            ]);

        if ($response->failed()) {
            throw new RuntimeException('OpenAI respondio con error HTTP ' . $response->status());
        }

        $payload = $response->json();
        $jsonText = $payload['output_text']
            ?? $payload['output'][0]['content'][0]['text']
            ?? null;

        if (!is_string($jsonText) || trim($jsonText) === '') {
            throw new RuntimeException('OpenAI no devolvio texto estructurado.');
        }

        $decoded = json_decode($jsonText, true);

        if (!is_array($decoded)) {
            throw new RuntimeException('No fue posible interpretar la respuesta JSON de OpenAI.');
        }

        return $decoded;
    }

    private function buildSystemPrompt(): string
    {
        return implode("\n", [
            'Eres el asistente de Q-LESS, una papeleria virtual escolar.',
            'Ayudas con maquetas, dibujos, carteleras y trabajos escolares.',
            'Debes basarte unicamente en el inventario proporcionado.',
            'Si un producto tiene stock 0, debes ubicarlo en unavailable_products y explicar que no esta disponible.',
            'Si un material no existe en el inventario, no lo inventes.',
            'Sugiere alternativas unicamente a partir del inventario disponible.',
            'Responde solo con el JSON solicitado.',
            'Escribe siempre en espanol claro y amable.',
        ]);
    }

    private function buildUserPrompt(string $message, array $inventory): string
    {
        return "Consulta del usuario:\n{$message}\n\nInventario actual:\n"
            . json_encode($inventory, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }

    private function responseSchema(): array
    {
        return [
            'type' => 'object',
            'additionalProperties' => false,
            'properties' => [
                'project_title' => ['type' => 'string'],
                'summary' => ['type' => 'string'],
                'steps' => [
                    'type' => 'array',
                    'items' => ['type' => 'string'],
                ],
                'available_products' => $this->productListSchema(),
                'unavailable_products' => $this->productListSchema(),
                'alternative_products' => $this->productListSchema(),
                'notes' => [
                    'type' => 'array',
                    'items' => ['type' => 'string'],
                ],
            ],
            'required' => [
                'project_title',
                'summary',
                'steps',
                'available_products',
                'unavailable_products',
                'alternative_products',
                'notes',
            ],
        ];
    }

    private function productListSchema(): array
    {
        return [
            'type' => 'array',
            'items' => [
                'type' => 'object',
                'additionalProperties' => false,
                'properties' => [
                    'id' => ['type' => 'integer'],
                    'nombre' => ['type' => 'string'],
                    'descripcion' => ['type' => 'string'],
                    'precio' => ['type' => 'number'],
                    'stock' => ['type' => 'integer'],
                    'categoria' => ['type' => 'string'],
                    'image_path' => ['type' => ['string', 'null']],
                    'reason' => ['type' => 'string'],
                ],
                'required' => [
                    'id',
                    'nombre',
                    'descripcion',
                    'precio',
                    'stock',
                    'categoria',
                    'image_path',
                    'reason',
                ],
            ],
        ];
    }

    private function inventorySnapshot(): array
    {
        return Producto::with('categoriaRelacion')
            ->orderByDesc('stock')
            ->orderBy('nombre')
            ->get()
            ->map(function (Producto $product) {
                return [
                    'id' => (int) $product->id,
                    'nombre' => (string) $product->nombre,
                    'descripcion' => (string) ($product->descripcion ?? ''),
                    'precio' => (float) $product->precio,
                    'stock' => (int) $product->stock,
                    'categoria' => (string) ($product->categoriaRelacion->nombre ?? $product->categoria ?? ''),
                    'image_path' => $product->image_path,
                ];
            })
            ->values()
            ->all();
    }

    private function normalizeResponseShape(array $response, array $fallback): array
    {
        foreach (['available_products', 'unavailable_products', 'alternative_products', 'steps', 'notes'] as $key) {
            if (!isset($response[$key]) || !is_array($response[$key])) {
                $response[$key] = $fallback[$key] ?? [];
            }
        }

        foreach (['project_title', 'summary'] as $key) {
            if (!isset($response[$key]) || !is_string($response[$key]) || trim($response[$key]) === '') {
                $response[$key] = $fallback[$key];
            }
        }

        return $response;
    }

    private function buildInventoryRecommendation(string $message): array
    {
        $normalizedMessage = $this->normalize($message);
        $products = Producto::with('categoriaRelacion')
            ->orderByDesc('stock')
            ->orderBy('nombre')
            ->get();

        $template = $this->detectTemplate($normalizedMessage);
        $requestedKeywords = $this->buildRequestedKeywords($normalizedMessage, $template);

        $available = [];
        $unavailable = [];
        $alternatives = [];
        $usedProductIds = [];

        foreach ($requestedKeywords as $keyword) {
            $matchedProducts = $this->matchProducts($products, $keyword);

            if ($matchedProducts['available']) {
                $product = $matchedProducts['available'];
                if (!isset($usedProductIds[$product->id])) {
                    $available[] = $this->formatProduct($product, "Disponible para {$keyword}");
                    $usedProductIds[$product->id] = true;
                }

                continue;
            }

            if ($matchedProducts['unavailable']) {
                $product = $matchedProducts['unavailable'];
                if (!isset($usedProductIds[$product->id])) {
                    $unavailable[] = $this->formatProduct($product, "Relacionado con {$keyword}, pero no tiene stock");
                    $usedProductIds[$product->id] = true;
                }

                $alternative = $this->findAlternative($products, $product, $usedProductIds);
                if ($alternative) {
                    $alternatives[] = $this->formatProduct($alternative, "Alternativa para {$keyword}");
                    $usedProductIds[$alternative->id] = true;
                }

                continue;
            }

            $fallbackAlternative = $this->findKeywordAlternative($products, $keyword, $usedProductIds);
            if ($fallbackAlternative) {
                $alternatives[] = $this->formatProduct($fallbackAlternative, "Alternativa sugerida para {$keyword}");
                $usedProductIds[$fallbackAlternative->id] = true;
            }
        }

        if (count($available) === 0 && count($alternatives) === 0) {
            foreach ($products->where('stock', '>', 0) as $product) {
                if (!isset($usedProductIds[$product->id])) {
                    $alternatives[] = $this->formatProduct($product, 'Producto disponible recomendado por el inventario');
                    $usedProductIds[$product->id] = true;
                }
            }
        }

        if (count($available) > 0 || count($alternatives) > 0) {
            foreach ($products->where('stock', '>', 0) as $product) {
                if (isset($usedProductIds[$product->id])) {
                    continue;
                }

                $alternatives[] = $this->formatProduct($product, 'Tambien puede servirte como material complementario segun el inventario.');
                $usedProductIds[$product->id] = true;
            }
        }

        $summary = $this->buildSummary($template, $available, $unavailable, $alternatives, $normalizedMessage);

        return [
            'status' => true,
            'query' => $message,
            'project_title' => $template['title'],
            'summary' => $summary,
            'steps' => $template['steps'],
            'available_products' => $available,
            'unavailable_products' => $unavailable,
            'alternative_products' => $alternatives,
            'notes' => [
                'La recomendacion se calculo con el inventario actual de Q-LESS.',
                'Si un material no aparece disponible, te sugiero alternativas del mismo inventario.',
            ],
        ];
    }

    private function detectTemplate(string $normalizedMessage): array
    {
        $templates = [
            [
                'title' => 'Maqueta del sistema solar',
                'keywords' => ['sistema solar', 'planetas', 'astronomia', 'solar'],
                'materials' => ['cartulina', 'marcadores', 'lapices', 'tijeras', 'pegante', 'cartulinas'],
                'steps' => [
                    'Dibuja o marca la orbita de los planetas sobre una base oscura.',
                    'Recorta o modela los planetas con materiales livianos.',
                    'Pinta y rotula cada planeta con marcadores o lapices.',
                    'Monta la maqueta y revisa que todo quede bien fijado.',
                ],
            ],
            [
                'title' => 'Maqueta de celula',
                'keywords' => ['celula', 'animal', 'vegetal', 'organelos'],
                'materials' => ['cartulina', 'marcadores', 'lapices', 'tijeras', 'regla'],
                'steps' => [
                    'Traza la forma base de la celula y define sus partes.',
                    'Recorta las piezas o etiquetas para los organelos.',
                    'Usa colores distintos para diferenciar cada estructura.',
                    'Pega y rotula cada parte de forma clara.',
                ],
            ],
            [
                'title' => 'Cartelera o exposicion escolar',
                'keywords' => ['cartelera', 'exposicion', 'afiche', 'poster'],
                'materials' => ['cartulinas', 'marcadores', 'lapices', 'regla', 'tijeras'],
                'steps' => [
                    'Organiza el contenido principal en secciones cortas.',
                    'Marca titulos y subtitulos con buena jerarquia visual.',
                    'Recorta apoyos graficos o cuadros informativos.',
                    'Revisa ortografia y limpieza antes de entregar.',
                ],
            ],
            [
                'title' => 'Proyecto escolar general',
                'keywords' => ['maqueta', 'trabajo', 'proyecto', 'manualidad'],
                'materials' => ['cartulina', 'marcadores', 'lapices', 'tijeras', 'regla'],
                'steps' => [
                    'Define la idea principal del trabajo y el tamano final.',
                    'Selecciona una base y los materiales para construirla.',
                    'Arma primero la estructura y luego agrega detalles.',
                    'Cierra con rotulos, color y presentacion limpia.',
                ],
            ],
            [
                'title' => 'Dibujo o ilustracion escolar',
                'keywords' => ['dibujo', 'dibujar', 'ilustracion', 'boceto', 'colorear'],
                'materials' => ['lapices', 'marcadores', 'hojas', 'cartulinas', 'regla', 'carton'],
                'steps' => [
                    'Empieza con un boceto suave para definir la idea principal.',
                    'Usa hojas o cartulina como base segun el tamano del trabajo.',
                    'Marca detalles y color con lapices o marcadores segun lo que este disponible.',
                    'Revisa limpieza, bordes y presentacion final antes de entregar.',
                ],
            ],
        ];

        foreach ($templates as $template) {
            foreach ($template['keywords'] as $keyword) {
                if (str_contains($normalizedMessage, $this->normalize($keyword))) {
                    return $template;
                }
            }
        }

        return [
            'title' => 'Recomendacion de materiales',
            'keywords' => [],
            'materials' => ['cartulina', 'marcadores', 'lapices', 'regla'],
            'steps' => [
                'Describe el trabajo y define los materiales principales.',
                'Consulta el inventario antes de comprar o reservar.',
                'Selecciona primero lo que ya esta disponible.',
                'Si falta algo, usa una alternativa del catalogo.',
            ],
        ];
    }

    private function buildRequestedKeywords(string $normalizedMessage, array $template): array
    {
        $inventoryKeywords = [
            'cuaderno',
            'libreta',
            'lapiz',
            'lapices',
            'marcador',
            'marcadores',
            'cartulina',
            'cartulinas',
            'hoja',
            'hojas',
            'tijera',
            'tijeras',
            'regla',
            'pegante',
            'borrador',
            'tempera',
            'colores',
            'carton',
            'dibujo',
            'dibujar',
            'boceto',
            'ilustracion',
        ];

        $keywords = $template['materials'];

        foreach ($inventoryKeywords as $keyword) {
            if (str_contains($normalizedMessage, $this->normalize($keyword))) {
                $keywords[] = $keyword;
            }
        }

        return array_values(array_unique($keywords));
    }

    private function matchProducts($products, string $keyword): array
    {
        $normalizedKeyword = $this->normalize($keyword);
        $available = null;
        $unavailable = null;

        foreach ($products as $product) {
            $haystack = $this->normalize(
                trim(($product->nombre ?? '') . ' ' . ($product->descripcion ?? '') . ' ' . ($product->categoria ?? '') . ' ' . ($product->categoriaRelacion->nombre ?? ''))
            );

            if (!str_contains($haystack, $normalizedKeyword)) {
                continue;
            }

            if ($product->stock > 0 && $available === null) {
                $available = $product;
            }

            if ($product->stock <= 0 && $unavailable === null) {
                $unavailable = $product;
            }
        }

        return [
            'available' => $available,
            'unavailable' => $unavailable,
        ];
    }

    private function findAlternative($products, Producto $baseProduct, array $usedProductIds): ?Producto
    {
        foreach ($products as $product) {
            if (isset($usedProductIds[$product->id])) {
                continue;
            }

            if ($product->stock <= 0) {
                continue;
            }

            if ($baseProduct->categoria_id && $product->categoria_id === $baseProduct->categoria_id) {
                return $product;
            }
        }

        return null;
    }

    private function findKeywordAlternative($products, string $keyword, array $usedProductIds): ?Producto
    {
        $normalizedKeyword = $this->normalize($keyword);

        foreach ($products as $product) {
            if (isset($usedProductIds[$product->id]) || $product->stock <= 0) {
                continue;
            }

            $categoryName = $this->normalize($product->categoriaRelacion->nombre ?? $product->categoria ?? '');
            $productName = $this->normalize($product->nombre ?? '');

            if (
                str_contains($productName, $normalizedKeyword)
                || str_contains($categoryName, $normalizedKeyword)
                || str_contains($normalizedKeyword, $categoryName)
            ) {
                return $product;
            }
        }

        return null;
    }

    private function formatProduct(Producto $product, string $reason): array
    {
        return [
            'id' => (int) $product->id,
            'nombre' => (string) $product->nombre,
            'descripcion' => (string) ($product->descripcion ?? ''),
            'precio' => (float) $product->precio,
            'stock' => (int) $product->stock,
            'categoria' => (string) ($product->categoriaRelacion->nombre ?? $product->categoria ?? ''),
            'image_path' => $product->image_path,
            'reason' => $reason,
        ];
    }

    private function buildSummary(array $template, array $available, array $unavailable, array $alternatives, string $normalizedMessage): string
    {
        if (str_contains($normalizedMessage, 'dibujo') || str_contains($normalizedMessage, 'dibujar')) {
            if (count($available) > 0) {
                return 'Para tu dibujo, encontre materiales del inventario que te sirven para empezar ahora mismo.';
            }

            if (count($unavailable) > 0 && count($alternatives) > 0) {
                return 'Para tu dibujo, algunos materiales no estan disponibles, pero ya te deje alternativas del inventario.';
            }

            if (count($unavailable) > 0) {
                return 'Para tu dibujo, los materiales mas relacionados no tienen stock en este momento.';
            }
        }

        if (count($available) > 0) {
            return "Para {$template['title']}, encontre materiales en inventario que te sirven para empezar hoy mismo.";
        }

        if (count($unavailable) > 0 && count($alternatives) > 0) {
            return "Para {$template['title']}, algunos materiales utiles no tienen stock, pero ya te deje alternativas disponibles.";
        }

        if (count($unavailable) > 0) {
            return "Para {$template['title']}, en este momento los productos mas relacionados no tienen stock disponible.";
        }

        return 'Te deje una recomendacion general basada en el inventario actual de la papeleria.';
    }

    private function normalize(string $value): string
    {
        return Str::lower(Str::ascii(trim($value)));
    }
}
