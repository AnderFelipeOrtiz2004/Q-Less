import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/index.dart';

class UserService {
  static const String baseUrl = BASE_URL;
  static String get _endpoint => apiUrl(baseUrl, 'users.php');

  static Future<User> fetchUser({required int userId}) async {
    final uri = Uri.parse('$_endpoint?id=$userId');
    final response = await http.get(uri, headers: const {
      'Accept': 'application/json',
    }).timeout(
      apiTimeout,
      onTimeout: () => throw Exception('Connection timeout'),
    );

    final cleanedBody = _cleanResponseBody(response.body);
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
    final uri = Uri.parse(_endpoint);

    final body = <String, dynamic>{
      'id': userId,
      if (nombre != null) 'nombre': nombre,
      if (description != null) 'description': description,
      if (password != null && password.isNotEmpty) 'password': password,
      if (avatarBase64 != null && avatarBase64.isNotEmpty)
        'avatar_base64': avatarBase64,
      if (avatarFileName != null && avatarFileName.isNotEmpty)
        'avatar_file_name': avatarFileName,
    };

    final response = await http
        .put(uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body))
        .timeout(
          apiUploadTimeout,
          onTimeout: () => throw Exception('Connection timeout'),
        );

    final cleanedBody = _cleanResponseBody(response.body);
    return jsonDecode(cleanedBody) as Map<String, dynamic>;
  }

  static String _cleanResponseBody(String body) {
    if (body.isEmpty) return '{}';
    String cleaned = body.trim();
    if (cleaned.contains('{')) {
      cleaned = cleaned.substring(cleaned.indexOf('{'));
    }
    return cleaned;
  }
}