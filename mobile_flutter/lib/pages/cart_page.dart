import 'dart:async';

import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../services/carrito_service.dart';
import '../services/discount_wheel_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/sound_service.dart';
import '../utils/image_utils.dart';
import '../widgets/quantity_input.dart';
import '../widgets/staggered_fade_in.dart';
import '../widgets/discount_wheel_dialog.dart';
import '../widgets/fade_slide_entry.dart';

class CartPage extends StatefulWidget {
  final int userId;
  final String userName;
  final bool purchasesEnabled;
  final bool emailVerified;
  final List<CartItem> cartItems;
  final Function(List<CartItem>) onCartUpdate;
  final VoidCallback onPurchaseComplete;
  final VoidCallback? onContinueShopping;

  const CartPage({
    super.key,
    required this.userId,
    required this.userName,
    this.purchasesEnabled = false,
    this.emailVerified = true,
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
  bool _purchaseLocked = false;
  Timer? _expirationTimer;
  int? _discountPercent;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.cartItems);
    _startExpirationWatcher();
    _loadActiveDiscount();
  }

  Future<void> _loadActiveDiscount() async {
    final percent = await DiscountWheelService.activeDiscountPercent();
    if (!mounted) return;
    setState(() => _discountPercent = percent);
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

  int get _discountAmount {
    final percent = _discountPercent ?? 0;
    return DiscountWheelService.discountAmount(_totalPrice, percent);
  }

  int get _finalTotal {
    final total = _totalPrice - _discountAmount;
    return total < 0 ? 0 : total;
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

  Future<void> _setQuantity(int index, int newQty) async {
    final item = _items[index];

    if (newQty <= 0) {
      await _removeItem(index);
      return;
    }

    final maxQty = item.quantity + item.product.availableStock;
    if (newQty > maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solo puedes reservar hasta $maxQty unidades',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (item.reservationId == null || newQty == item.quantity) return;

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
      final stockLeft = int.tryParse(data['stock']?.toString() ?? '') ??
          item.product.availableStock;
      final availableStock =
          int.tryParse(data['available_stock']?.toString() ?? '') ??
              (newQty + stockLeft);
      setState(() {
        _items[index] = CartItem(
          product: item.product.copyWith(
            availableStock: availableStock,
            stock: availableStock,
          ),
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
    if (_purchaseLocked || _isProcessing) return;

    if (!widget.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes verificar tu correo Gmail antes de enviar una compra.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!widget.purchasesEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tus compras aún no están habilitadas. Un administrador debe activarlas.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _purchaseLocked = true;
    setState(() {
      _isProcessing = true;
    });

    try {
      int successCount = 0;
      final List<int> failedIndices = [];
      String? successMessage;
      String? lastError;

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
          successMessage = orderResponse['message']?.toString();
        } else {
          failedIndices.add(i);
          lastError = orderResponse['message']?.toString();
        }
      }

      if (!mounted) return;

      if (successCount == _items.length) {
        try {
          await SoundService.playSuccess();
        } catch (_) {}
        if (_discountPercent != null && _discountPercent! > 0) {
          await DiscountWheelService.clearActiveDiscount();
        }
        if (!mounted) return;
        // Todas las compras fueron exitosas
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage ??
                  'Solicitud enviada. Un administrador revisará tu compra ($_itemCount producto(s)).',
            ),
            backgroundColor: _brandGreen,
            duration: const Duration(seconds: 4),
          ),
        );

        // Limpiar el carrito y actualizar
        widget.onCartUpdate([]);
        widget.onPurchaseComplete();

        if (mounted) {
          await DiscountWheelDialog.showIfAvailable(context);
        }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lastError ?? 'Error al procesar compra. Intenta de nuevo.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
      _purchaseLocked = false;
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
              child: FadeSlideEntry(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
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
              ),
            )
          : Column(
              children: [
                if (!widget.emailVerified)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.mark_email_unread_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Verifica tu correo Gmail para poder enviar compras.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!widget.purchasesEnabled)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFE8A838), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tu compra quedará pendiente hasta que un administrador habilite tus compras. Luego podrás enviar la solicitud desde el carrito.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule, color: _brandGreen, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Al enviar la compra quedará PENDIENTE. Cuando el admin la apruebe, recibirás tu código de compra por Gmail.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      final cartItem = _items[index];
                      return StaggeredFadeIn(
                        key: ValueKey(
                          '${cartItem.product.id}-${cartItem.reservationId ?? index}',
                        ),
                        index: index,
                        offsetY: 16,
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
                      if (_discountPercent != null && _discountPercent! > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descuento ruleta (-$_discountPercent%)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '-\$$_discountAmount',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
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
                            '\$$_finalTotal',
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
                          onPressed: (!_isProcessing &&
                                  widget.purchasesEnabled &&
                                  widget.emailVerified)
                              ? _processPurchase
                              : null,
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
                                'Enviar solicitud (pendiente)',
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
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;
    if (hours > 0) {
      return 'Reserva expira en ${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
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
              width: 80,
              height: 80,
              context: context,
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
                  _ReservationCountdown(
                    expiresAt: cartItem.reservationExpiresAt!,
                    formatter: _formatRemainingTime,
                  ),
                ],
                const SizedBox(height: 8),
                QuantityInput(
                  value: cartItem.quantity,
                  max: cartItem.quantity + cartItem.product.availableStock,
                  enabled: !_isProcessing,
                  onChanged: (qty) => _setQuantity(index, qty),
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

class _ReservationCountdown extends StatefulWidget {
  final DateTime expiresAt;
  final String Function(DateTime) formatter;

  const _ReservationCountdown({
    required this.expiresAt,
    required this.formatter,
  });

  @override
  State<_ReservationCountdown> createState() => _ReservationCountdownState();
}

class _ReservationCountdownState extends State<_ReservationCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.formatter(widget.expiresAt),
      style: const TextStyle(
        fontSize: 12,
        color: Colors.orange,
      ),
    );
  }
}
