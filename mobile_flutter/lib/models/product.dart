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
    final path = imagePath.trim();
    if (path.isNotEmpty) {
      if (path.contains('storage/products/')) {
        return path.substring(path.indexOf('storage/products/'));
      }
      if (path.startsWith('storage/')) {
        return path;
      }
      if (!path.startsWith('http') && !path.startsWith('blob:')) {
        return path;
      }
    }

    final url = imageUrl.trim();
    if (url.contains('storage/products/')) {
      return url.substring(url.indexOf('storage/products/'));
    }
    if (url.startsWith('storage/')) {
      return url;
    }

    return '';
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
    );
  }
}
