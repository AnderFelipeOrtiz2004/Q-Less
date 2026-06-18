import 'package:flutter/foundation.dart';
import '../services/carrito_service.dart';

/// ============================================================
/// PROVIDER: CarritoProvider
/// Maneja el estado del carrito y sincroniza con el backend
/// ============================================================
class CarritoProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  double _total = 0.0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CartItem> get items => _items;
  double get total => _total;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get cantidadItems => _items.length;

  /// Inicializa el carrito al loguear el usuario
  /// Consulta el backend para recuperar carrito guardado
  Future<void> inicializarCarrito({required int userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await CarritoService.obtenerCarrito(userId: userId);

      if (response['status'] == 'success') {
        _items = (response['data'] as List? ?? [])
            .map((item) => CartItem.fromJson(item))
            .toList();
        _calcularTotal();
      } else {
        _error = response['message'] ?? 'Error desconocido';
        _items = [];
        _total = 0.0;
      }
    } catch (e) {
      _error = 'Error al cargar carrito: $e';
      _items = [];
      _total = 0.0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Agrega un producto al carrito
  Future<bool> agregarProducto({
    required int userId,
    required int productoId,
    required String nombre,
    required double precio,
    required int cantidad,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await CarritoService.agregarAlCarrito(
        userId: userId,
        productoId: productoId,
        cantidad: cantidad,
      );

      if (response['status'] == 'success') {
        // Actualizar item en lista local (optimistic update)
        final existingIndex = _items.indexWhere((i) => i.productoId == productoId);

        if (existingIndex >= 0) {
          _items[existingIndex].cantidad += cantidad;
        } else {
          _items.add(CartItem(
            reservationId: response['data']['id'],
            productoId: productoId,
            nombre: nombre,
            cantidad: cantidad,
            precio: precio,
            expiresAt: response['data']['expires_at'],
          ));
        }

        // Recalcular total
        _calcularTotal();

        return true;
      } else {
        _error = response['message'] ?? 'Error al agregar al carrito';
        return false;
      }
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina un producto del carrito
  Future<bool> eliminarProducto(int reservationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await CarritoService.eliminarDelCarrito(
        reservationId: reservationId,
      );

      if (response['status'] == 'success') {
        // Remover de lista local
        _items.removeWhere((i) => i.reservationId == reservationId);
        _calcularTotal();
        return true;
      } else {
        _error = response['message'] ?? 'Error al eliminar producto';
        return false;
      }
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Procesa la compra
  Future<bool> procesarCompra() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Procesar cada reserva individualmente
      for (var item in _items) {
        final response = await CarritoService.procesarCompra(
          reservationId: item.reservationId,
        );
        
        if (response['status'] != 'success') {
          _error = response['message'] ?? 'Error en la compra';
          return false;
        }
      }

      // Vaciar carrito local
      _items = [];
      _total = 0.0;
      return true;
    } catch (e) {
      _error = 'Error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recalcula el total del carrito
  void _calcularTotal() {
    _total = _items.fold(0.0, (sum, item) => sum + (item.precio * item.cantidad));
  }

  /// Limpia el carrito y errores
  void limpiar() {
    _items = [];
    _total = 0.0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

/// MODELO: CartItem
/// Representa un item del carrito
class CartItem {
  final int reservationId;
  final int productoId;
  final String nombre;
  int cantidad;
  final double precio;
  final String expiresAt;
  final String? descripcion;
  final String? image_path;
  final String? categoria;

  CartItem({
    required this.reservationId,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    required this.expiresAt,
    this.descripcion,
    this.image_path,
    this.categoria,
  });

  double get subtotal => precio * cantidad;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      reservationId: json['reservation_id'] as int? ?? 0,
      productoId: json['product_id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      cantidad: json['quantity'] as int? ?? 0,
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      expiresAt: json['expires_at'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      image_path: json['image_path'] as String?,
      categoria: json['categoria'] as String?,
    );
  }
}
