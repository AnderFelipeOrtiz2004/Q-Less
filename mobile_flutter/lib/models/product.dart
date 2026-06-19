class Product {
  final int id;
  final String nombre;
  final String descripcion;
  final String categoria;
  final int precio;
  final int stock;
  final int availableStock;
  final String imageUrl;
  final String imagePath;
  final int? userId;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.precio,
    required this.stock,
    required this.availableStock,
    required this.imageUrl,
    this.imagePath = '',
    this.userId,
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: use null-aware access and toString() safely
    final rawId = json['id'] ?? json['ID'] ?? json['Id'];
    final rawNombre = json['nombre'] ?? json['name'];
    final rawDescripcion = json['descripcion'] ?? json['description'];
    final rawCategoria = json['categoria'] ?? json['id_catalogo'] ?? 'General';
    final rawPrecio = json['precio'] ?? json['price'];
    final rawStock = json['stock'] ?? 0;
    final rawAvailable = json['available_stock'] ?? json['available'] ?? rawStock;

    final rawImageUrl = json['image_url'] ?? json['imageUrl'];
    final rawImagePath = json['image_path'] ?? json['imagePath'];
    final imagePath = (rawImagePath?.toString() ?? '').trim();
    final imageUrl = (rawImageUrl?.toString().trim().isNotEmpty == true
        ? rawImageUrl.toString().trim()
        : imagePath);

    int parseInt(dynamic v) {
      if (v == null) return 0;
      final s = v is String ? v : v.toString();
      return int.tryParse(s) ?? 0;
    }

    return Product(
      id: parseInt(rawId),
      nombre: rawNombre?.toString() ?? '',
      descripcion: rawDescripcion?.toString() ?? '',
      categoria: rawCategoria?.toString() ?? 'General',
      precio: parseInt(rawPrecio),
      stock: parseInt(rawStock),
      availableStock: parseInt(rawAvailable),
      imageUrl: imageUrl,
      imagePath: imagePath,
      userId: json['user_id'] == null
          ? null
          : int.tryParse(json['user_id'].toString()),
      createdAt: json['created_at'] != null &&
              json['created_at'].toString().trim().isNotEmpty &&
              json['created_at'].toString() != '0000-00-00 00:00:00'
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson({int? fallbackUserId}) {
    final relativePath = _relativeImagePath();
    return {
      if (id > 0) 'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'precio': precio,
      'stock': stock,
      if (relativePath.isNotEmpty) 'image_path': relativePath,
      'user_id': userId ?? fallbackUserId ?? 1,
    };
  }

  String _relativeImagePath() {
    String extract(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return '';

      final match = RegExp(
        r'storage/(?:products|productos|avatars)/[^\s?]+',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match != null) return match.group(0)!;

      if (trimmed.startsWith('storage/')) return trimmed;
      if (!trimmed.startsWith('http') && !trimmed.startsWith('blob:')) {
        return trimmed;
      }
      return trimmed.startsWith('http') ? trimmed : '';
    }

    final fromPath = extract(imagePath);
    if (fromPath.isNotEmpty) return fromPath;
    return extract(imageUrl);
  }
  
  /// Returns a copy of this product with optional updated fields.
  Product copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    String? categoria,
    int? precio,
    int? stock,
    int? availableStock,
    String? imageUrl,
    String? imagePath,
    int? userId,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      availableStock: availableStock ?? this.availableStock,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
