class Order {
  final int id;
  final int userId;
  final int productId;
  final String productName;
  final int quantity;
  final int price;
  final int totalPrice;
  final String status;
  final DateTime createdAt;
  final String productImageUrl;
  final String userName;
  final String userEmail;

  Order({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    this.status = 'completada',
    required this.createdAt,
    this.productImageUrl = '',
    this.userName = '',
    this.userEmail = '',
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      productId: int.tryParse(json['product_id'].toString()) ?? 0,
      productName: (json['product_name'] ?? '').toString(),
      quantity: int.tryParse(json['quantity'].toString()) ?? 1,
      price: int.tryParse(json['price'].toString()) ?? 0,
      totalPrice: int.tryParse(json['total_price'].toString()) ?? 0,
      status: (json['status'] ?? 'completada').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      productImageUrl: (json['product_image_url'] ?? '').toString(),
      userName: (json['user_name'] ?? json['nombre'] ?? '').toString(),
      userEmail: (json['user_email'] ?? json['correo'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'user_id': userId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'total_price': totalPrice,
      'status': status,
      'product_image_url': productImageUrl,
    };
  }
}
