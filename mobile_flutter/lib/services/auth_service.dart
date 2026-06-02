import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/constants.dart';
import '../models/index.dart';

class AuthService {
  /// Base URL configurada para acceder al backend en XAMPP
  static const String _defaultBaseUrl = BASE_URL;

  static String get baseUrl {
    final configuredUrl = dotenv.env['API_BASE_URL']?.trim();
    if (configuredUrl == null || configuredUrl.isEmpty) {
      return _defaultBaseUrl;
    }
    var url = configuredUrl.replaceAll(RegExp(r'/backend/?$'), '');
    if (url.endsWith('/backend')) {
      url = url.substring(0, url.length - '/backend'.length);
    }
    url = url.replaceAll('/backend/', '/');
    return url.endsWith('/') ? url : '$url/';
  }

  static String _connectionErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('TimeoutException') || text.contains('Connection timed out')) {
      return 'No se pudo conectar al servidor (XAMPP). Abre el panel de XAMPP e inicia Apache y MySQL.';
    }
    if (text.contains('Connection refused') || text.contains('Failed host lookup')) {
      return 'No hay conexión con el backend. Usa la URL http://127.0.0.1/q-less/ y activa Apache.';
    }
    return 'Error de conexión: $text';
  }

  static String _cleanResponseBody(String body) {
    if (body.isEmpty) return '{}';
    String cleaned = body.trim();
    // Busca el inicio del JSON para descartar posibles errores de PHP o espacios
    int jsonStartIndex = cleaned.indexOf('{');
    if (jsonStartIndex != -1) {
      return cleaned.substring(jsonStartIndex);
    }
    return '{}';
  }

  static Future<Map<String, dynamic>> registerUser({
    required String nombre,
    required String correo,
    required String password,
    String role = 'aprendiz',
  }) async {
    try {
      final url = Uri.parse(apiUrl(baseUrl, 'register.php'));
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'nombre': nombre.trim(),
          'correo': correo.trim(),
          'password': password,
          'role': ['aprendiz', 'instructor'].contains(role.toLowerCase()) ? role.toLowerCase() : 'aprendiz',
        }),
      ).timeout(
        apiTimeout,
        onTimeout: () => throw Exception(
          'El servidor no respondió. Verifica que Apache y MySQL estén activos en XAMPP.',
        ),
      );

      final jsonResponse = jsonDecode(_cleanResponseBody(response.body));

      return {
        'success': response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'Error en el servidor',
        'data': jsonResponse['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(e),
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> loginUser({
    required String correo,
    required String password,
  }) async {
    try {
      final url = Uri.parse(apiUrl(baseUrl, 'login.php'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'correo': correo.trim(),
          'password': password,
        }),
      ).timeout(
        apiTimeout,
        onTimeout: () => throw Exception(
          'El servidor no respondió. Verifica que Apache y MySQL estén activos en XAMPP.',
        ),
      );

      final jsonResponse = jsonDecode(_cleanResponseBody(response.body));

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        return {
          'success': true,
          'message': jsonResponse['message'],
          'user': jsonResponse['user'] != null ? User.fromJson(jsonResponse['user']) : null,
        };
      } else {
        return {
          'success': false,
          'message': jsonResponse['message'] ?? 'Credenciales inválidas',
          'user': null,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(e),
        'user': null,
      };
    }
  }
}