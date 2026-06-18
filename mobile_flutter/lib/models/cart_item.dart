import 'product.dart';

class CartItem {
  final Product product;
  int quantity;
  int? reservationId;
  DateTime? reservationExpiresAt;

  CartItem({
    required this.product,
    required this.quantity,
    this.reservationId,
    this.reservationExpiresAt,
  });

  int get totalPrice => product.precio * quantity;
}
