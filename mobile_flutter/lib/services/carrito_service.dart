import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

/// ============================================================
/// SERVICIO: CarritoService
/// Maneja todas las operaciones HTTP del carrito con el backend
/// ============================================================
class CarritoService {
  // URL base uniforme para todas las llamadas al backend
  static const String baseUrl = BASE_URL;

  /// Obtiene el carrito actual del usuario desde la base de datos
  static Future<Map<String, dynamic>> obtenerCarrito({required int userId}) async {
    try {
      final response = await http.get(
        Uri.parse('${apiUrl(baseUrl, 'reservations.php')}?user_id=$userId&action=list'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Error del servidor: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('Error en obtenerCarrito: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Agrega un producto al carrito
  static Future<Map<String, dynamic>> agregarAlCarrito({
    required int userId,
    required int productoId,
    required int cantidad,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl(baseUrl, 'reservations.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': 'create',
          'user_id': userId,
          'product_id': productoId,
          'quantity': cantidad,
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Error del servidor al agregar'};
      }
    } catch (e) {
      debugPrint('Error en agregarAlCarrito: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Elimina un producto del carrito y devuelve el stock
  static Future<Map<String, dynamic>> eliminarDelCarrito({
    required int reservationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl(baseUrl, 'reservations.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': 'release',
          'reservation_id': reservationId,
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Error del servidor al eliminar'};
      }
    } catch (e) {
      debugPrint('Error en eliminarDelCarrito: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Actualiza la cantidad de una reserva activa
  static Future<Map<String, dynamic>> actualizarCantidad({
    required int reservationId,
    required int userId,
    required int quantity,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl(baseUrl, 'reservations.php')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'update',
          'reservation_id': reservationId,
          'user_id': userId,
          'quantity': quantity,
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error', 'message': 'Error al actualizar cantidad'};
    } catch (e) {
      debugPrint('Error en actualizarCantidad: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Procesa la compra (convierte reservas en descuentos permanentes)
  static Future<Map<String, dynamic>> procesarCompra({
    required int reservationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl(baseUrl, 'reservations.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'action': 'confirm',
          'reservation_id': reservationId,
        }),
      ).timeout(apiTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Error del servidor al confirmar'};
      }
    } catch (e) {
      debugPrint('Error en procesarCompra: $e');
      return {'status': 'error', 'message': e.toString()};
    }
  }
}