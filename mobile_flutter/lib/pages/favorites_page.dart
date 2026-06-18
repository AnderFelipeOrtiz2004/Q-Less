import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/favorites_service.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../utils/transition_utils.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  final int userId;
  final String userRole;
  final void Function(Product, int)? onAddToCart;

  const FavoritesPage({
    super.key,
    required this.userId,
    required this.userRole,
    this.onAddToCart,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Product> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ids = await FavoritesService.getFavoriteIds(userId: widget.userId);
      final all = await ProductService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _favorites = all.where((p) => ids.contains(p.id)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBrandGreen,
        foregroundColor: Colors.white,
        title: const Text('Favoritos'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes favoritos aún',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toca el corazón en un producto para guardarlo aquí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = _favorites[index];
                      final outOfStock = product.availableStock <= 0;
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          child: Icon(
                            outOfStock
                                ? Icons.block
                                : Icons.inventory_2_outlined,
                            color: outOfStock ? Colors.red : kBrandGreen,
                          ),
                        ),
                        title: Text(product.nombre),
                        subtitle: Text(
                          outOfStock
                              ? 'Sin stock'
                              : '\$${product.precio} · Disp: ${product.availableStock}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () async {
                            await FavoritesService.toggleFavorite(
                              userId: widget.userId,
                              productId: product.id,
                            );
                            _load();
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            fadeSlideRoute(
                              ProductDetailPage(
                                product: product,
                                userId: widget.userId,
                                userRole: widget.userRole,
                                onAddToCart: widget.onAddToCart,
                              ),
                            ),
                          ).then((_) => _load());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
