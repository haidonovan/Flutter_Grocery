import 'package:flutter/material.dart';

import 'models.dart';
import 'product_list.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({
    super.key,
    required this.products,
    required this.cartQuantityForProduct,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final List<Product> products;
  final int Function(String productId) cartQuantityForProduct;
  final void Function(String productId) onOpenProduct;
  final void Function(String productId) onAddToCart;
  final bool Function(String productId) isFavorite;
  final void Function(String productId) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E4540), Color(0xFFB57878)],
                  ),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No favorites yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart on any product and it will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ProductListPage(
      products: products,
      cartQuantityForProduct: cartQuantityForProduct,
      onOpenProduct: onOpenProduct,
      onAddToCart: onAddToCart,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
    );
  }
}
