import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/index.dart';
import 'network_status_service.dart';
import 'server_config_service.dart';

class AuthService {
  static String get baseUrl => getBaseUrl();

  static Future<String?> _prepareMobileConnection() async {
    if (!await NetworkStatusService.hasConnection()) {
      return NetworkStatusService.noConnectionMessage;
    }
    final connected = await ServerConfigService.ensureConnectedOnMobile();
    if (!connected) {
      return NetworkStatusService.serverUnreachableMessage;
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

  static Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = jsonDecode(_cleanResponseBody(body));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  static Future<Map<String, dynamic>> registerUser({
    required String nombre,
    required String correo,
    required String password,
    String role = 'aprendiz',
    bool acceptedTerms = false,
    String privacyVersion = '1.0',
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
          'accepted_terms': acceptedTerms,
          'privacy_version': privacyVersion,
        }),
      ).timeout(
        apiTimeout,
        onTimeout: () => throw Exception('timeout'),
      );

      final jsonResponse = _decodeJsonMap(response);

      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ??
            (response.statusCode >= 500
                ? 'Error del servidor (${response.statusCode}). El API necesita actualizarse en Railway.'
                : 'Error en el servidor'),
        'data': jsonResponse['data'],
        'code': jsonResponse['code'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> verifyEmail({
    required String correo,
    required String code,
  }) async {
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {'success': false, 'message': networkError};
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
          'action': 'verify_email',
          'correo': correo.trim(),
          'code': code.trim(),
        }),
      ).timeout(apiTimeout);

      final jsonResponse = _decodeJsonMap(response);
      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'No se pudo verificar el correo',
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> resendVerificationCode({
    required String correo,
  }) async {
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {'success': false, 'message': networkError};
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
          'action': 'resend_code',
          'correo': correo.trim(),
        }),
      ).timeout(apiTimeout);

      final jsonResponse = _decodeJsonMap(response);
      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'No se pudo reenviar el código',
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
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

      final jsonResponse = _decodeJsonMap(response);

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
          'code': jsonResponse['code'],
          'user': null,
        };
      }
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
        'user': null,
      };
    }
  }

  static Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    bool acceptedTerms = false,
    String privacyVersion = '1.0',
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
      final url = Uri.parse(apiUrl(getBaseUrl(), 'google_login.php'));
      final response = await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
          'accepted_terms': acceptedTerms,
          'privacy_version': privacyVersion,
        }),
      ).timeout(apiTimeout);

      final jsonResponse = _decodeJsonMap(response);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        return {
          'success': true,
          'message': jsonResponse['message'],
          'user': jsonResponse['user'] != null
              ? User.fromJson(jsonResponse['user'])
              : null,
        };
      }

      return {
        'success': false,
        'message': jsonResponse['message'] ?? 'No se pudo iniciar con Google',
        'user': null,
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
        'user': null,
      };
    }
  }

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
    bool resend = false,
  }) async {
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {'success': false, 'message': networkError};
    }

    try {
      final url = Uri.parse(apiUrl(getBaseUrl(), 'password_reset.php'));
      final response = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': resend ? 'resend' : 'request',
              'email': email.trim(),
            }),
          )
          .timeout(apiTimeout);

      final jsonResponse = _decodeJsonMap(response);
      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'No se pudo enviar el código',
        'code': jsonResponse['code'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
      };
    }
  }

  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final networkError = await _prepareMobileConnection();
    if (networkError != null) {
      return {'success': false, 'message': networkError};
    }

    try {
      final url = Uri.parse(apiUrl(getBaseUrl(), 'password_reset.php'));
      final response = await http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'reset',
              'email': email.trim(),
              'code': code.trim(),
              'password': newPassword,
            }),
          )
          .timeout(apiTimeout);

      final jsonResponse = _decodeJsonMap(response);
      return {
        'success':
            response.statusCode == 200 && jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'No se pudo actualizar la contraseña',
      };
    } catch (_) {
      return {
        'success': false,
        'message': NetworkStatusService.serverUnreachableMessage,
      };
    }
  }
}
