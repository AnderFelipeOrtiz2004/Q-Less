import 'package:flutter/material.dart';

import '../models/product.dart';

import '../services/favorites_service.dart';

import '../services/sound_service.dart';
import '../utils/image_utils.dart';

import '../widgets/quantity_input.dart';



class ProductDetailPage extends StatefulWidget {

  final Product product;

  final int userId;

  final String userRole;

  final void Function(Product, int)? onAddToCart;



  const ProductDetailPage({

    super.key,

    required this.product,

    required this.userId,

    required this.userRole,

    this.onAddToCart,

  });



  @override

  State<ProductDetailPage> createState() => _ProductDetailPageState();

}



class _ProductDetailPageState extends State<ProductDetailPage> {

  static const Color _brandGreen = Color(0xFF56C900);

  int _quantity = 1;

  bool _isFavorite = false;



  bool get _outOfStock => widget.product.availableStock <= 0;



  @override

  void initState() {

    super.initState();

    _loadFavorite();

  }



  Future<void> _loadFavorite() async {

    final fav = await FavoritesService.isFavorite(
      userId: widget.userId,
      productId: widget.product.id,
    );

    if (mounted) setState(() => _isFavorite = fav);

  }



  Future<void> _toggleFavorite() async {
    SoundService.playClick();
    final fav = await FavoritesService.toggleFavorite(
      userId: widget.userId,
      productId: widget.product.id,
    );

    if (mounted) setState(() => _isFavorite = fav);

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(

        backgroundColor: _brandGreen,

        foregroundColor: Colors.white,

        elevation: 0,

        leading: const BackButton(color: Colors.white),

        title: const Text('Detalles del Producto'),

        actions: [

          IconButton(

            onPressed: _toggleFavorite,

            icon: Icon(

              _isFavorite ? Icons.favorite : Icons.favorite_border,

              color: Colors.white,

            ),

          ),

        ],

      ),

      body: SingleChildScrollView(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            if (_outOfStock)

              Material(

                color: Colors.red[700],

                child: Padding(

                  padding: const EdgeInsets.all(14),

                  child: Row(

                    children: [

                      const Icon(Icons.warning_amber_rounded,

                          color: Colors.white),

                      const SizedBox(width: 10),

                      Expanded(

                        child: Text(

                          'Ya no hay stock de este producto',

                          style: const TextStyle(

                            color: Colors.white,

                            fontWeight: FontWeight.w700,

                            fontSize: 15,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

              ),

            Container(

              width: double.infinity,

              height: 300,

              color: const Color(0xFFF5F5F5),

              padding: const EdgeInsets.all(24),

              child: Center(

                child: Hero(

                  tag: 'product-image-${widget.product.id}',

                  child: buildProductImage(

                    widget.product.imagePath,

                    widget.product.imageUrl,

                    fit: BoxFit.contain,

                    width: 280,

                    height: 260,

                    context: context,

                    placeholder: Container(

                      color: Colors.grey[200],

                      child: const Icon(

                        Icons.image_not_supported_outlined,

                        color: Colors.black38,

                        size: 60,

                      ),

                    ),

                  ),

                ),

              ),

            ),

            Padding(

              padding: const EdgeInsets.all(20),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    widget.product.nombre,

                    style: const TextStyle(

                      fontSize: 28,

                      fontWeight: FontWeight.bold,

                      color: Colors.black87,

                    ),

                  ),

                  const SizedBox(height: 12),

                  Container(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 12,

                      vertical: 6,

                    ),

                    decoration: BoxDecoration(

                      color: _brandGreen.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(20),

                    ),

                    child: Text(

                      widget.product.categoria,

                      style: const TextStyle(

                        color: _brandGreen,

                        fontSize: 12,

                        fontWeight: FontWeight.w600,

                      ),

                    ),

                  ),

                  const SizedBox(height: 20),

                  Row(

                    children: [

                      const Text(

                        'Precio:',

                        style: TextStyle(

                          fontSize: 16,

                          color: Colors.black54,

                        ),

                      ),

                      const SizedBox(width: 12),

                      Text(

                        '\$${widget.product.precio}',

                        style: const TextStyle(

                          fontSize: 32,

                          fontWeight: FontWeight.bold,

                          color: Colors.black87,

                        ),

                      ),

                      const Text(

                        ' Pesos',

                        style: TextStyle(

                          fontSize: 14,

                          color: Colors.black54,

                        ),

                      ),

                    ],

                  ),

                  const SizedBox(height: 20),

                  if (!_outOfStock)

                    Container(

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(

                        color: Colors.green[50],

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(color: Colors.green[300]!),

                      ),

                      child: Row(

                        children: [

                          const Icon(Icons.check_circle,

                              color: Colors.green, size: 20),

                          const SizedBox(width: 12),

                          Expanded(

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                Text(

                                  'Disponible',

                                  style: TextStyle(

                                    fontSize: 14,

                                    fontWeight: FontWeight.bold,

                                    color: Colors.green[700],

                                  ),

                                ),

                                Text(

                                  '${widget.product.availableStock} unidades disponibles',

                                  style: const TextStyle(

                                    fontSize: 12,

                                    color: Colors.black54,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ],

                      ),

                    ),

                  const SizedBox(height: 24),

                  const Text(

                    'Descripción',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.bold,

                      color: Colors.black87,

                    ),

                  ),

                  const SizedBox(height: 12),

                  Text(

                    widget.product.descripcion,

                    style: const TextStyle(

                      fontSize: 14,

                      color: Colors.black54,

                      height: 1.6,

                    ),

                  ),

                  const SizedBox(height: 32),

                  if (!_outOfStock) ...[

                    const Text(

                      'Cantidad',

                      style: TextStyle(

                        fontSize: 14,

                        fontWeight: FontWeight.w600,

                        color: Colors.black87,

                      ),

                    ),

                    const SizedBox(height: 10),

                    QuantityInput(

                      value: _quantity,

                      max: widget.product.availableStock,

                      onChanged: (v) => setState(() => _quantity = v),

                    ),

                    const SizedBox(height: 24),

                  ],

                  SizedBox(

                    width: double.infinity,

                    height: 56,

                    child: ElevatedButton(

                      onPressed: _outOfStock

                          ? null

                          : () {

                              widget.onAddToCart

                                  ?.call(widget.product, _quantity);

                              ScaffoldMessenger.of(context).showSnackBar(

                                SnackBar(

                                  content: Text(

                                    '${widget.product.nombre} agregado al carrito',

                                  ),

                                  backgroundColor: _brandGreen,

                                  duration: const Duration(seconds: 2),

                                ),

                              );

                              Navigator.of(context).pop();

                            },

                      style: ElevatedButton.styleFrom(

                        backgroundColor: _brandGreen,

                        foregroundColor: Colors.white,

                        disabledBackgroundColor: Colors.grey[300],

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                      ),

                      child: Text(

                        _outOfStock

                            ? 'Producto agotado'

                            : 'Comprar ($_quantity)',

                        style: const TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.bold,

                        ),

                      ),

                    ),

                  ),

                  const SizedBox(height: 12),

                  SizedBox(

                    width: double.infinity,

                    height: 56,

                    child: OutlinedButton(

                      onPressed: () => Navigator.of(context).pop(),

                      style: OutlinedButton.styleFrom(

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                        side: const BorderSide(color: _brandGreen, width: 2),

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

      ),

    );

  }

}


