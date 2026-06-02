import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/product.dart';

class ProductService {
  static String get baseUrl => getBaseUrl();
  static String get _endpoint => apiUrl(baseUrl, 'products.php');
  static String get _reservationsEndpoint => apiUrl(baseUrl, 'reservations.php');

  /// Helper method to clean raw string data before JSON decoding
  /// This prevents FormatException caused by accidental leading characters (e.g. spaces, commas, BOM)
  static String _cleanResponseBody(String body) {
    if (body.isEmpty) return '{}';
    String cleaned = body.trim();
    if (cleaned.contains('{')) {
      cleaned = cleaned.substring(cleaned.indexOf('{'));
    }
    return cleaned;
  }

  static Future<Map<String, dynamic>> reserveProduct({
    required int userId,
    required int productId,
    required int quantity,
  }) async {
    final uri = Uri.parse(_reservationsEndpoint);
    final response = await http
        .post(uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'create',
              'user_id': userId,
              'product_id': productId,
              'quantity': quantity,
            }))
        .timeout(apiTimeout, onTimeout: () => throw Exception('Connection timeout'));

    final cleanedBody = _cleanResponseBody(response.body);
    final jsonResponse = jsonDecode(cleanedBody);
    return jsonResponse;
  }

  static Future<Map<String, dynamic>> releaseReservation({
    required int reservationId,
  }) async {
    final uri = Uri.parse(_reservationsEndpoint);
    final response = await http
        .post(uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'release',
              'reservation_id': reservationId,
            }))
        .timeout(apiTimeout, onTimeout: () => throw Exception('Connection timeout'));

    final cleanedBody = _cleanResponseBody(response.body);
    final jsonResponse = jsonDecode(cleanedBody);
    return jsonResponse;
  }

  static Future<Map<String, dynamic>> confirmReservation({
    required int reservationId,
  }) async {
    final uri = Uri.parse(_reservationsEndpoint);
    final response = await http
        .post(uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': 'confirm',
              'reservation_id': reservationId,
            }))
        .timeout(apiTimeout, onTimeout: () => throw Exception('Connection timeout'));

    final cleanedBody = _cleanResponseBody(response.body);
    final jsonResponse = jsonDecode(cleanedBody);
    return jsonResponse;
  }

  static Future<List<Product>> fetchProducts() async {
    final response = await http.get(
      Uri.parse('$_endpoint?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: const {
        'Accept': 'application/json',
      },
    ).timeout(
      apiTimeout,
      onTimeout: () => throw Exception('Connection timeout'),
    );

    final cleanedBody = _cleanResponseBody(response.body);
    final jsonResponse = jsonDecode(cleanedBody);
    if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
      throw Exception(
          jsonResponse['message'] ?? 'No se pudieron cargar productos');
    }

    final items = jsonResponse['data'] as List<dynamic>? ?? [];
    return items
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> createProduct({
    required Product product,
    required int userId,
    required String role,
    Uint8List? imageBytes,
    String? imageFileName,
  }) {
    return _sendProduct(
      method: 'POST',
      product: product,
      userId: userId,
      role: role,
      imageBytes: imageBytes,
      imageFileName: imageFileName,
    );
  }

  static Future<Map<String, dynamic>> updateProduct({
    required Product product,
    required int userId,
    required String role,
    Uint8List? imageBytes,
    String? imageFileName,
  }) {
    return _sendProduct(
      method: 'PUT',
      product: product,
      userId: userId,
      role: role,
      imageBytes: imageBytes,
      imageFileName: imageFileName,
    );
  }

  static Future<Map<String, dynamic>> deleteProduct({
    required int productId,
    required int userId,
    required String role,
  }) async {
    final response = await http
        .delete(
          Uri.parse(_endpoint),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'id': productId,
            'user_id': userId,
            'role': role,
          }),
        )
        .timeout(
          apiTimeout,
          onTimeout: () => throw Exception('Connection timeout'),
        );

    return _parseResponse(response);
  }

  static Future<Map<String, dynamic>> _sendProduct({
    required String method,
    required Product product,
    required int userId,
    required String role,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    final body = product.toJson(fallbackUserId: userId)
      ..['user_id'] = userId
      ..['role'] = role;

    if (imageBytes != null && imageBytes.isNotEmpty) {
      body['image_base64'] = base64Encode(imageBytes);
      body['image_file_name'] = imageFileName ?? 'producto.jpg';
    }

    final uri = Uri.parse(_endpoint);
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final response = method == 'POST'
        ? await http
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(
              apiUploadTimeout,
              onTimeout: () => throw Exception('Connection timeout'),
            )
        : await http.put(uri, headers: headers, body: jsonEncode(body)).timeout(
              apiUploadTimeout,
              onTimeout: () => throw Exception('Connection timeout'),
            );

    return _parseResponse(response);
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    final cleanedBody = _cleanResponseBody(response.body);
    final jsonResponse = jsonDecode(cleanedBody);
    return {
      'success': response.statusCode >= 200 &&
          response.statusCode < 300 &&
          jsonResponse['status'] == 'success',
      'message': jsonResponse['message'] ?? 'Operacion completada',
      'data': jsonResponse['data'],
    };
  } 
}