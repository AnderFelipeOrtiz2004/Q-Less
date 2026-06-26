import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/sound_service.dart';
import '../utils/image_utils.dart';
import 'fade_slide_entry.dart';
import 'hover_elevated_card.dart';

/// Tarjeta compacta para grid de 2 columnas (home y catálogo admin).
class ProductGridTile extends StatelessWidget {
  const ProductGridTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onBuy,
    this.onFavorite,
    this.isFavorite = false,
    this.showAdminActions = false,
    this.onEdit,
    this.onDelete,
    this.animationIndex = 0,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final bool showAdminActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final int animationIndex;

  static const Color _brandGreen = Color(0xFF3EC13B);

  bool get _outOfStock => product.availableStock <= 0;

  @override
  Widget build(BuildContext context) {
    return FadeSlideEntry(
      duration: Duration(milliseconds: 280 + (animationIndex % 8) * 35),
      verticalOffset: 28,
      curve: Curves.easeOutBack,
      child: HoverElevatedCard(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                _outOfStock ? Colors.grey.shade50 : const Color(0xFFF7FBF7),
              ],
            ),
            border: Border.all(
              color: _outOfStock
                  ? Colors.red.shade100
                  : const Color(0xFFE6EEE6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.05,
                      child: Hero(
                        tag: 'product-image-${product.id}',
                        child: buildProductImage(
                          product.imagePath,
                          product.imageUrl,
                          fit: BoxFit.cover,
                          context: context,
                          placeholder: Container(
                            color: Colors.grey.shade100,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 42,
                              color: Colors.black26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (onFavorite != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            SoundService.playClick();
                            onFavorite!();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_outOfStock)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Agotado',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.precio}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _brandGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product.availableStock}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (showAdminActions) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onEdit == null
                                  ? null
                                  : () {
                                      SoundService.playEdit();
                                      onEdit!();
                                    },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                foregroundColor: _brandGreen,
                              ),
                              child: const Icon(Icons.edit_outlined, size: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onDelete == null
                                  ? null
                                  : () {
                                      SoundService.playClick();
                                      onDelete!();
                                    },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                foregroundColor: Colors.red,
                              ),
                              child: const Icon(Icons.delete_outline, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ] else if (onBuy != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: FilledButton.icon(
                          onPressed: _outOfStock
                              ? null
                              : () {
                                  SoundService.playPurchase();
                                  onBuy!();
                                },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                          label: const Text(
                            'Comprar',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
