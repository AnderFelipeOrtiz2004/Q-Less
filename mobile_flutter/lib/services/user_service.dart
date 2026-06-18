import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/index.dart';
import 'network_status_service.dart';
import 'server_config_service.dart';

class UserService {
  static String get baseUrl => getBaseUrl();
  static String get _endpoint => apiUrl(baseUrl, 'users.php');

  static Future<String?> _prepareConnection({bool skipHealthCheck = false}) async {
    if (!await NetworkStatusService.hasConnection()) {
      return NetworkStatusService.noConnectionMessage;
    }
    if (skipHealthCheck) {
      return null;
    }
    final connected = await ServerConfigService.ensureConnectedOnMobile();
    if (!connected) {
      return NetworkStatusService.serverUnreachableMessage;
    }
    return null;
  }

  static Future<User> fetchUser({required int userId}) async {
    if (userId <= 0) {
      throw Exception('ID de usuario inválido');
    }

    final networkError = await _prepareConnection(skipHealthCheck: isOnlineApiMode);
    if (networkError != null) {
      throw Exception(networkError);
    }

    final uri = Uri.parse('$_endpoint?id=$userId');
    final response = await http.get(uri, headers: const {
      'Accept': 'application/json',
    }).timeout(
      apiTimeout,
      onTimeout: () => throw Exception('Connection timeout'),
    );

    final cleanedBody = _cleanResponseBody(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final jsonResponse = jsonDecode(cleanedBody);
    if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
      throw Exception(jsonResponse['message'] ?? 'No se pudo cargar el perfil');
    }

    return User.fromJson(jsonResponse['data'] as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? nombre,
    String? description,
    String? password,
    String? avatarBase64,
    String? avatarFileName,
  }) async {
    if (userId <= 0) {
      return {
        'status': 'error',
        'message': 'Sesión inválida. Cierra sesión e inicia de nuevo.',
      };
    }

    final networkError = await _prepareConnection(skipHealthCheck: isOnlineApiMode);
    if (networkError != null) {
      return {'status': 'error', 'message': networkError};
    }

    final uri = Uri.parse(_endpoint);

    final body = <String, dynamic>{
      'action': 'update_profile',
      'id': userId,
      if (nombre != null) 'nombre': nombre,
      if (description != null) 'description': description,
      if (password != null && password.isNotEmpty) 'password': password,
      if (avatarBase64 != null && avatarBase64.isNotEmpty)
        'avatar_base64': avatarBase64,
      if (avatarFileName != null && avatarFileName.isNotEmpty)
        'avatar_file_name': avatarFileName,
    };

    final headers = const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(
            apiUploadTimeout,
            onTimeout: () => throw Exception('Connection timeout'),
          );
    } catch (_) {
      response = await http
          .put(uri, headers: headers, body: jsonEncode(body))
          .timeout(
            apiUploadTimeout,
            onTimeout: () => throw Exception('Connection timeout'),
          );
    }

    final jsonResponse = _decodeJson(response);
    return jsonResponse is Map<String, dynamic>
        ? jsonResponse
        : Map<String, dynamic>.from(jsonResponse as Map);
  }

  static String _cleanResponseBody(String body) {
    if (body.isEmpty) return '{}';
    final cleaned = body.trim();
    final jsonStartIndex = cleaned.indexOf('{');
    if (jsonStartIndex != -1) {
      return cleaned.substring(jsonStartIndex);
    }
    return '{}';
  }

  static dynamic _decodeJson(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    return jsonDecode(_cleanResponseBody(body));
  }
}