import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/index.dart';

class AuthService {
  /// Base URL configurada para acceder al backend en XAMPP
  static String get baseUrl {
    // Intentamos cargar desde .env, si no, usamos la IP local 127.0.0.1
    final configuredUrl = dotenv.env['API_BASE_URL']?.trim();
    if (configuredUrl != null && configuredUrl.isNotEmpty) {
      return configuredUrl.endsWith('/') ? configuredUrl.substring(0, configuredUrl.length - 1) : configuredUrl;
    }
    // 127.0.0.1 es más estable en navegadores que 'localhost'
    return 'http://127.0.0.1/backend';
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
      final url = Uri.parse('$baseUrl/register.php');
      
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
      ).timeout(const Duration(seconds: 10));

      final jsonResponse = jsonDecode(_cleanResponseBody(response.body));

      return {
        'success': response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'Error en el servidor',
        'data': jsonResponse['data'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: ${e.toString()}', 'data': null};
    }
  }

  static Future<Map<String, dynamic>> loginUser({
    required String correo,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/login.php');

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
      ).timeout(const Duration(seconds: 10));

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
      return {'success': false, 'message': 'Error: ${e.toString()}', 'user': null};
    }
  }
}