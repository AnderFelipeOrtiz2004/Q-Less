import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'product_service.dart';

class ChatbotService {
  ChatbotService._();
  static final ChatbotService instance = ChatbotService._();

  static const int _maxRetryAttempts = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  String? _apiKey;
  String? _backendUrl;
  String? _configurationError;

  final List<_ModelConfig> _models = const [
    _ModelConfig('gemini-2.5-flash'),
    _ModelConfig('gemini-2.0-flash'),
    _ModelConfig('gemini-1.5-flash', apiVersion: 'v1'),
    _ModelConfig('gemini-1.5-flash-latest', apiVersion: 'v1'),
  ];

  void init() {
    _configurationError = null;

    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim();
    final backendUrl = dotenv.env['CHATBOT_BACKEND_URL']?.trim();

    if ((apiKey == null || apiKey.isEmpty) &&
        (backendUrl == null || backendUrl.isEmpty)) {
      _configurationError =
          'Debe configurar GEMINI_API_KEY o CHATBOT_BACKEND_URL en .env.';
      throw Exception(_configurationError);
    }

    _apiKey = apiKey;
    _backendUrl = backendUrl;
  }

  Future<String> sendMessage(
      String userMessage, List<Map<String, String>> chatHistory) async {
    final apiKey = _apiKey;
    final backendUrl = _backendUrl;

    if ((apiKey == null || apiKey.isEmpty) &&
        (backendUrl == null || backendUrl.isEmpty)) {
      return _configurationError ??
          'El servicio de chat no esta inicializado. Verifica el archivo .env o reinicia la app.';
    }

    final sanitizedUserMessage = _sanitizeText(userMessage);
    if (sanitizedUserMessage.isEmpty) {
      return 'El mensaje está vacío o no es válido.';
    }

    if (backendUrl != null && backendUrl.isNotEmpty) {
      return _sendHistoryToBackend(
        backendUrl,
        _normalizeHistory(chatHistory),
      );
    }

    final prompt = await _buildProjectPrompt(sanitizedUserMessage);
    Object? lastError;

    for (final config in _models) {
      try {
        final model = GenerativeModel(
          model: config.name,
          apiKey: apiKey!,
          requestOptions: config.apiVersion == null
              ? null
              : RequestOptions(apiVersion: config.apiVersion),
        );

        final response = await _generateWithRetry(model, prompt);
        final text = response.text;
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }

        return 'No recibi una respuesta clara del asistente.';
      } catch (e) {
        lastError = e;
        if (_isModelNotFoundError(e)) {
          continue;
        }
        if (_isRetriableError(e)) {
          continue;
        }

        return 'Error al comunicarse con el modelo: ${e.toString()}';
      }
    }

    return 'No se encontro un modelo de Gemini disponible para esta API key. Ultimo error: ${lastError.toString()}';
  }

  Future<String> _sendHistoryToBackend(
      String backendUrl, List<Map<String, String>> chatHistory) async {
    final normalizedHistory = _normalizeHistory(chatHistory);

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(backendUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'history': normalizedHistory}),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['success'] == true) {
            return payload['bot_response']?.toString() ??
                'No se recibió una respuesta válida del backend.';
          }

          final serverMessage = payload['message']?.toString();
          if (serverMessage != null && _isRetriableErrorMessage(serverMessage)) {
            if (attempt < _maxRetryAttempts) {
              await Future.delayed(_retryDelays[attempt - 1]);
              continue;
            }
          }

          return serverMessage ??
              'Backend devolvió una respuesta inesperada.';
        }

        if (response.statusCode == 503 || response.statusCode == 429) {
          if (attempt < _maxRetryAttempts) {
            await Future.delayed(_retryDelays[attempt - 1]);
            continue;
          }
        }

        return 'Error del backend: ${response.statusCode}';
      } catch (e) {
        if (attempt < _maxRetryAttempts && _isRetriableError(e)) {
          await Future.delayed(_retryDelays[attempt - 1]);
          continue;
        }
        return 'Error al conectar con el backend del chatbot: ${e.toString()}';
      }
    }

    return 'El chatbot no está disponible en este momento. Intenta nuevamente en unos segundos.';
  }

  Future<String> _buildProjectPrompt(String userMessage) async {
    final stockContext = await _loadStockContext();
    final cleanedMessage = _sanitizeText(userMessage);

    return '''
Eres el asistente de Q-LESS para proyectos escolares. Responde en español, claro y accionable.

La persona pide:
$cleanedMessage

Inventario actual de productos comprables:
$stockContext

Formato obligatorio de respuesta:
MATERIALES
- Lista breve de materiales necesarios.

PASOS
1. Pasos concretos para hacer el proyecto.

DISPONIBLES EN PRODUCTOS
- Menciona solamente productos del inventario con stock que sirvan para este proyecto.
- Si ninguno sirve o no se pudo cargar el inventario, dilo de forma amable y sugiere revisar Productos.

CONSEJOS
- 2 o 3 recomendaciones cortas.

No uses Markdown con asteriscos, tablas ni encabezados con #.
''';
  }

  Future<String> _loadStockContext() async {
    try {
      final products = await ProductService.fetchProducts();
      final available = products
          .where((product) => product.availableStock > 0)
          .take(30)
          .toList();

      if (available.isEmpty) {
        return 'No hay productos con stock disponible en este momento.';
      }

      return available.map(_formatProductForPrompt).join('\n');
    } catch (_) {
      return 'No se pudo cargar el inventario en este momento.';
    }
  }

  String _formatProductForPrompt(Product product) {
    return '- ${product.nombre} | categoria: ${product.categoria} | precio: \$${product.precio} | stock: ${product.availableStock} | descripcion: ${product.descripcion}';
  }

  Future<dynamic> _generateWithRetry(
    GenerativeModel model,
    String prompt,
  ) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await model.generateContent([Content.text(prompt)]);
      } catch (e) {
        lastError = e;
        if (attempt >= _maxRetryAttempts || !_isRetriableError(e)) {
          rethrow;
        }
        await Future.delayed(_retryDelays[attempt - 1]);
      }
    }

    throw lastError ?? Exception('Error desconocido al generar la respuesta.');
  }

  bool _isRetriableError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('503') || text.contains('429') ||
        text.contains('server error') || text.contains('rate limit');
  }

  bool _isRetriableErrorMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('503') || text.contains('429') ||
        text.contains('server error') || text.contains('rate limit');
  }

  List<Map<String, String>> _normalizeHistory(
      List<Map<String, String>> history) {
    final normalized = <Map<String, String>>[];

    for (final entry in history) {
      final role = entry['role']?.toLowerCase().trim();
      final content = _sanitizeText(entry['content']?.toString() ?? '');
      if (role == null || content.isEmpty) continue;
      if (role != 'user' && role != 'model') continue;

      if (normalized.isNotEmpty && normalized.last['role'] == role) {
        normalized.last['content'] =
            '${normalized.last['content']}\n$content';
      } else {
        normalized.add({'role': role, 'content': content});
      }
    }

    while (normalized.isNotEmpty && normalized.first['role'] != 'user') {
      normalized.removeAt(0);
    }

    return normalized;
  }

  String _sanitizeText(String input) {
    var text = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  bool _isModelNotFoundError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('not found for api version') ||
        text.contains('is not found') ||
        text.contains('404');
  }

  void dispose() {}
}

class _ModelConfig {
  const _ModelConfig(this.name, {this.apiVersion});

  final String name;
  final String? apiVersion;
}
