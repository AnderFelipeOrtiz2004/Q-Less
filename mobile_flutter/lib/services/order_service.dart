import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';

class OrderService {
  // Ruta absoluta directa sin depender de terceros
  static const String _endpoint = 'http://localhost/backend/orders.php';

  /// Create a new order (purchase)
  static Future<Map<String, dynamic>> createOrder({
    required int userId,
    required int productId,
    required String productName,
    required int quantity,
    required int price,
    required String productImageUrl,
    int? reservationId,
  }) async {
    final body = {
      'user_id': userId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total_price': price * quantity,
      'product_image_url': productImageUrl,
      if (reservationId != null) 'reservation_id': reservationId,
      'action': 'create',
    };

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Connection timeout'),
          );

      return _parseResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Fetch user orders
  static Future<List<Order>> fetchUserOrders({
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_endpoint?user_id=$userId&action=get_user_orders'),
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      final cleanedBody = _cleanResponseBody(response.body);
      final jsonResponse = jsonDecode(cleanedBody);
      if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
        throw Exception(
            jsonResponse['message'] ?? 'No se pudieron cargar órdenes');
      }

      final items = jsonResponse['data'] as List<dynamic>? ?? [];
      return items
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  static Future<List<Order>> fetchAllOrders({
    required int userId,
    required String role,
  }) async {
    try {
      final uri = Uri.parse(
        '$_endpoint?action=get_all_orders&user_id=$userId&role=$role',
      );
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      final cleanedBody = _cleanResponseBody(response.body);
      final jsonResponse = jsonDecode(cleanedBody);
      if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
        throw Exception(
          jsonResponse['message'] ?? 'No se pudieron cargar las compras',
        );
      }

      final items = jsonResponse['data'] as List<dynamic>? ?? [];
      return items
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching admin orders: $e');
    }
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    try {
      final cleanedBody = _cleanResponseBody(response.body);
      final jsonResponse = jsonDecode(cleanedBody);
      return {
        'success': response.statusCode >= 200 &&
            response.statusCode < 300 &&
            jsonResponse['status'] == 'success',
        'message': jsonResponse['message'] ?? 'Operación completada',
        'data': jsonResponse['data'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al procesar respuesta: $e',
        'data': null,
      };
    }
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