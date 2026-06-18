import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../utils/profanity_filter.dart';

class ChatbotReply {
  final String text;
  final List<String> suggestions;

  const ChatbotReply({
    required this.text,
    this.suggestions = const [],
  });
}

class ChatbotProfanityException implements Exception {
  final String message;
  ChatbotProfanityException(this.message);
}

class ChatbotService {
  ChatbotService._();
  static final ChatbotService instance = ChatbotService._();

  static const int _maxRetryAttempts = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  String? _backendUrl;
  String? _configurationError;

  void init() {
    _configurationError = null;

    final envChatbot = dotenv.env['CHATBOT_BACKEND_URL']?.trim();
    _backendUrl = _normalizeBackendUrl(
      envChatbot != null && envChatbot.isNotEmpty
          ? envChatbot
          : apiUrl(getBaseUrl(), 'chatbot.php'),
    );

    if (_backendUrl == null || _backendUrl!.isEmpty) {
      _configurationError =
          'Configura CHATBOT_BACKEND_URL o API_BASE_URL en .env.';
    }
  }

  String? _normalizeBackendUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    var relative = trimmed.replaceFirst(RegExp(r'^/+'), '');
    relative = relative.replaceFirst(RegExp(r'^backend/'), '');
    final base = getBaseUrl();
    return relative.isEmpty ? base : apiUrl(base, relative);
  }

  static const List<String> defaultSuggestions = [
    '¿Cómo hacer una maqueta del sistema solar?',
    '¿Qué materiales necesito para un robot escolar?',
    '¿Qué productos hay disponibles ahora?',
    'Ayúdame con un proyecto de cartón',
    'Ideas para una feria de ciencias',
  ];

  Future<ChatbotReply> sendMessage(
      String userMessage, List<Map<String, String>> chatHistory,
      {int? userId}) async {
    final backendUrl = _backendUrl;

    if (backendUrl == null || backendUrl.isEmpty) {
      return ChatbotReply(
        text: _configurationError ??
            'El chat no está disponible. Revisa la configuración del servidor.',
      );
    }

    final sanitizedUserMessage = _sanitizeText(userMessage);
    if (sanitizedUserMessage.isEmpty) {
      return const ChatbotReply(text: 'El mensaje está vacío o no es válido.');
    }

    if (ProfanityFilter.containsProfanity(sanitizedUserMessage)) {
      throw ChatbotProfanityException(
        'Tu mensaje contiene lenguaje inapropiado. Usa un tono respetuoso.',
      );
    }

    if (_isGreeting(sanitizedUserMessage)) {
      return const ChatbotReply(
        text:
            '¡Hola! Soy tu asistente de proyectos escolares de Q-LESS.\n\n'
            'Puedo ayudarte con materiales, pasos, productos con stock y consejos.\n\n'
            'Elige una sugerencia o escribe tu pregunta.',
        suggestions: defaultSuggestions,
      );
    }

    final category = _extractChatCategory(sanitizedUserMessage);
    final backendReply = await _sendHistoryToBackend(
      backendUrl,
      _normalizeHistory(chatHistory),
      userId: userId,
      category: category,
    );

    if (!_isBackendFailureMessage(backendReply.text)) {
      return ChatbotReply(
        text: _sanitizeBotResponse(backendReply.text),
        suggestions: backendReply.suggestions,
      );
    }

    return backendReply;
  }

  bool _isGreeting(String text) {
    final lower = text.toLowerCase().trim();
    const greetings = [
      'hola',
      'buenos dias',
      'buenos días',
      'buenas tardes',
      'buenas noches',
      'hey',
      'hi',
      'hello',
      'saludos',
      'qué tal',
      'que tal',
    ];
    for (final greeting in greetings) {
      if (lower == greeting ||
          lower.startsWith('$greeting ') ||
          lower.startsWith('$greeting,')) {
        return true;
      }
    }
    return false;
  }

  Future<ChatbotReply> _sendHistoryToBackend(
      String backendUrl, List<Map<String, String>> chatHistory,
      {int? userId, String? category}) async {
    final normalizedHistory = _normalizeHistory(chatHistory);
    final requestBody = <String, dynamic>{
      'history': normalizedHistory,
      if (userId != null) 'user_id': userId,
      if (category != null && category.isNotEmpty) 'categoria': category,
    };

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(backendUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 400) {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['code'] == 'profanity_blocked') {
            throw ChatbotProfanityException(
              payload['message']?.toString() ??
                  'Tu mensaje contiene lenguaje inapropiado.',
            );
          }
        }

        if (response.statusCode == 200) {
          final payload = jsonDecode(response.body);
          if (payload is Map &&
              payload['status'] == 'success' &&
              payload['data'] is Map) {
            final data = payload['data'] as Map;
            final botResponse = data['bot_response']?.toString();
            if (botResponse != null && botResponse.isNotEmpty) {
              final suggestions = (data['suggestions'] as List?)
                      ?.map((e) => e.toString())
                      .where((e) => e.isNotEmpty)
                      .toList() ??
                  const <String>[];
              return ChatbotReply(text: botResponse, suggestions: suggestions);
            }
          }

          final serverMessage = payload['message']?.toString();
          if (serverMessage != null && _isRetriableErrorMessage(serverMessage)) {
            if (attempt < _maxRetryAttempts) {
              await Future.delayed(_retryDelays[attempt - 1]);
              continue;
            }
          }

          return ChatbotReply(
            text: serverMessage ?? 'El servidor devolvió una respuesta inesperada.',
          );
        }

        if (response.statusCode == 503 || response.statusCode == 429) {
          if (attempt < _maxRetryAttempts) {
            await Future.delayed(_retryDelays[attempt - 1]);
            continue;
          }
        }

        final responseBody = response.body;
        try {
          final payload = jsonDecode(responseBody);
          if (payload is Map && payload['message'] != null) {
            return ChatbotReply(text: payload['message'].toString());
          }
        } catch (_) {}
        return ChatbotReply(text: 'Error del servidor: ${response.statusCode}');
      } catch (e) {
        if (e is ChatbotProfanityException) rethrow;
        if (attempt < _maxRetryAttempts && _isRetriableError(e)) {
          await Future.delayed(_retryDelays[attempt - 1]);
          continue;
        }
        return const ChatbotReply(
          text: 'No se pudo conectar con el chat. Intenta de nuevo.',
        );
      }
    }

    return const ChatbotReply(
      text: 'El chat no está disponible en este momento.',
    );
  }

  String _sanitizeBotResponse(String text) {
    final blocked = RegExp(
      r'gemini|modo local|inteligencia artificial|cuota de|api de|como asistente virtual|proveedor',
      caseSensitive: false,
    );
    final lines = text.split('\n');
    final cleaned = lines.where((line) => !blocked.hasMatch(line)).join('\n');
    return cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  bool _isBackendFailureMessage(String message) {
    final lower = message.toLowerCase();
    return lower.startsWith('error del servidor') ||
        lower.startsWith('no se pudo conectar con el chat') ||
        lower.contains('no está disponible');
  }

  bool _isRetriableError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('503') ||
        text.contains('429') ||
        text.contains('server error') ||
        text.contains('rate limit');
  }

  bool _isRetriableErrorMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('503') ||
        text.contains('429') ||
        text.contains('server error') ||
        text.contains('rate limit');
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

  String _extractChatCategory(String question) {
    final lower = question.toLowerCase();
    final categories = {
      'sistema solar': [
        'sistema solar',
        'planeta',
        'planetas',
        'luna',
        'sol',
      ],
      'cartón': ['cartón', 'carton', 'corrugado', 'caja', 'cartulina'],
      'maqueta': ['maqueta', 'modelo', 'escala', 'proyecto'],
      'robot': ['robot', 'robótica', 'arduino', 'motores'],
      'papel': ['papel', 'cartulina', 'origami'],
      'madera': ['madera', 'palillo', 'balsa'],
    };
    for (final entry in categories.entries) {
      for (final term in entry.value) {
        if (lower.contains(term)) {
          return entry.key;
        }
      }
    }
    return 'general';
  }

  void dispose() {}
}
