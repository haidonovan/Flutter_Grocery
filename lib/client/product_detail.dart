import 'package:flutter/material.dart';

import 'models.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.cartQuantity,
    required this.onAddToCart,
  });

  final Product product;
  final int cartQuantity;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final canAdd = cartQuantity < product.stock && product.stock > 0;

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              product.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.image_not_supported)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.category.toUpperCase()),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Available stock: ${product.stock}',
                  style: TextStyle(
                    color: product.stock <= 5 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  product.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canAdd ? onAddToCart : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(canAdd ? 'Add to cart' : 'Out of stock'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
