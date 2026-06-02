import 'dart:async';

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/carrito_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/sound_service.dart';
import '../utils/image_utils.dart';

class CartPage extends StatefulWidget {
  final int userId;
  final String userName;
  final List<CartItem> cartItems;
  final Function(List<CartItem>) onCartUpdate;
  final VoidCallback onPurchaseComplete;
  final VoidCallback? onContinueShopping;

  const CartPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.cartItems,
    required this.onCartUpdate,
    required this.onPurchaseComplete,
    this.onContinueShopping,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const Color _brandGreen = Color(0xFF56C900);
  late List<CartItem> _items;
  bool _isProcessing = false;
  Timer? _expirationTimer;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cartItems);
    _startExpirationWatcher();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  void _startExpirationWatcher() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      final now = DateTime.now();
      final expiredItems = _items.where((item) {
        final expiresAt = item.reservationExpiresAt;
        return expiresAt != null && expiresAt.isBefore(now);
      }).toList();

      if (expiredItems.isEmpty) {
        setState(() {});
        return;
      }

      for (final expired in expiredItems) {
        if (expired.reservationId != null) {
          await ProductService.releaseReservation(reservationId: expired.reservationId!);
        }
      }

      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) {
          final expiresAt = item.reservationExpiresAt;
          return expiresAt != null && expiresAt.isBefore(now);
        });
      });
      widget.onCartUpdate(_items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reserva expirada y producto removido del carrito'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  int get _itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  int get _totalPrice {
    return _items.fold(0, (sum, item) => sum + item.totalPrice);
  }

  Future<void> _removeItem(int index) async {
    final item = _items[index];
    if (item.reservationId != null) {
      await CarritoService.eliminarDelCarrito(reservationId: item.reservationId!);
    }
    if (!mounted) return;
    setState(() {
      _items.removeAt(index);
    });
    widget.onCartUpdate(_items);
    widget.onContinueShopping?.call();
  }

  Future<void> _changeQuantity(int index, int delta) async {
    final item = _items[index];
    final newQty = item.quantity + delta;

    if (newQty <= 0) {
      await _removeItem(index);
      return;
    }

    if (item.reservationId == null) return;

    setState(() => _isProcessing = true);

    final response = await CarritoService.actualizarCantidad(
      reservationId: item.reservationId!,
      userId: widget.userId,
      quantity: newQty,
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (response['status'] == 'success') {
      final data = response['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _items[index] = CartItem(
          product: item.product,
          quantity: newQty,
          reservationId: item.reservationId,
          reservationExpiresAt:
              DateTime.tryParse(data['expires_at']?.toString() ?? '') ??
                  item.reservationExpiresAt,
        );
      });
      widget.onCartUpdate(_items);
      widget.onContinueShopping?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']?.toString() ?? 'No se pudo actualizar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processPurchase() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      int successCount = 0;
      final List<int> failedIndices = [];

      // Procesar cada compra
      for (int i = 0; i < _items.length; i++) {
        final cartItem = _items[i];
        final product = cartItem.product;

        final orderResponse = await OrderService.createOrder(
          userId: widget.userId,
          productId: product.id,
          productName: product.nombre,
          quantity: cartItem.quantity,
          price: product.precio,
          productImageUrl: product.imageUrl,
          reservationId: cartItem.reservationId,
        );

        if (orderResponse['success'] == true) {
          successCount++;
        } else {
          failedIndices.add(i);
        }
      }

      if (!mounted) return;

      if (successCount == _items.length) {
        try {
          await SoundService.playSuccess();
        } catch (_) {}
        if (!mounted) return;
        // Todas las compras fueron exitosas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('¡Compra exitosa! Se compraron $_itemCount producto(s)'),
            backgroundColor: _brandGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        // Limpiar el carrito y actualizar
        widget.onCartUpdate([]);
        widget.onPurchaseComplete();

        // Ir a la página de mis compras
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (successCount > 0) {
        // Compra parcial
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compra parcial: Se compraron $successCount de ${_items.length} productos',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        final failedItems =
            failedIndices.map((index) => _items[index]).toList();
        _items = failedItems;
        widget.onCartUpdate(_items);

        if (_items.isEmpty && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // Ninguna compra fue exitosa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al procesar compra. Intenta de nuevo.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mi Carrito'),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega productos para comenzar a comprar',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      child: Text(
                        'Continuar Comprando',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final cartItem = _items[index];
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(
                          '${cartItem.product.id}-${cartItem.reservationId ?? index}',
                        ),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + index * 35),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildCartItem(cartItem, index),
                      );
                    },
                  ),
                ),
                // Resumen
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtotal (${_items.length} items)',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '\$$_totalPrice',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '\$$_totalPrice',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processPurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        scale: _isProcessing ? 0.97 : 1.0,
                        child: _isProcessing
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirmar Compra',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () {
                            widget.onContinueShopping?.call();
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side:
                                const BorderSide(color: _brandGreen, width: 2),
                          ),
                          child: const Text(
                            'Continuar Comprando',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _brandGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatRemainingTime(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Reserva expirada';
    }
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return 'Reserva expira en ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCartItem(CartItem cartItem, int index) {
    final product = cartItem.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: buildProductImage(
              product.imagePath,
              product.imageUrl,
              fit: BoxFit.cover,
              placeholder: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.black38,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${product.precio} x ${cartItem.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (cartItem.reservationExpiresAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatRemainingTime(cartItem.reservationExpiresAt!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isProcessing
                          ? null
                          : () => _changeQuantity(index, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: _brandGreen,
                    ),
                    Text(
                      '${cartItem.quantity}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _isProcessing
                          ? null
                          : () => _changeQuantity(index, 1),
                      icon: const Icon(Icons.add_circle_outline),
                      color: _brandGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isProcessing ? null : () => _removeItem(index),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
