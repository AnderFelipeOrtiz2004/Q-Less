import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/index.dart';
import 'network_status_service.dart';
import 'server_config_service.dart';

class AuthService {
  static String get baseUrl => getBaseUrl();

  static Future<String?> _prepareMobileConnection() async {
    if (!await NetworkStatusService.hasWifi()) {
      return NetworkStatusService.noWifiMessage;
    }
    final connected = await ServerConfigService.ensureConnectedOnMobile();
    if (!connected) {
      return NetworkStatusService.wifiNoServerMessage;
    }
    return null;
  }

  static String _cleanResponseBody(String body) {
    if (body.isEmpty) return '{}';
    String cleaned = body.trim();
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
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {'success': false, 'message': networkError, 'data': null};
    }

    try {
      final url = Uri.parse(apiUrl(getBaseUrl(), 'register.php'));

      final response = await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'nombre': nombre.trim(),
          'correo': correo.trim(),
          'password': password,
          'role': ['aprendiz', 'instructor'].contains(role.toLowerCase())
              ? role.toLowerCase()
              : 'aprendiz',
        }),
      ).timeout(
        apiTimeout,
        onTimeout: () => throw Exception('timeout'),
      );

      final jsonResponse = jsonDecode(_cleanResponseBody(response.body));

      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'Error en el servidor',
        'data': jsonResponse['data'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.wifiNoServerMessage,
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> loginUser({
    required String correo,
    required String password,
  }) async {
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {
        'success': false,
        'message': networkError,
        'user': null,
      };
    }

    try {
      final url = Uri.parse(apiUrl(getBaseUrl(), 'login.php'));

      final response = await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': correo.trim(),
          'correo': correo.trim(),
          'password': password,
        }),
      ).timeout(
        apiTimeout,
        onTimeout: () => throw Exception('timeout'),
      );

      final jsonResponse = jsonDecode(_cleanResponseBody(response.body));

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        return {
          'success': true,
          'message': jsonResponse['message'],
          'user': jsonResponse['user'] != null
              ? User.fromJson(jsonResponse['user'])
              : null,
        };
      } else {
        return {
          'success': false,
          'message': jsonResponse['message'] ?? 'Credenciales inválidas',
          'user': null,
        };
      }
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.wifiNoServerMessage,
        'user': null,
      };
    }
  }
}
