import 'package:flutter/material.dart';

import 'models.dart';

class ProductListPage extends StatelessWidget {
  const ProductListPage({
    super.key,
    required this.products,
    required this.cartQuantityForProduct,
    required this.onOpenProduct,
    required this.onAddToCart,
  });

  final List<Product> products;
  final int Function(String productId) cartQuantityForProduct;
  final void Function(String productId) onOpenProduct;
  final void Function(String productId) onAddToCart;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('No products available right now.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final product = products[index];
        final currentCartQty = cartQuantityForProduct(product.id);
        final canAdd = currentCartQty < product.stock && product.stock > 0;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Icon(Icons.image_not_supported)),
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(product.category)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stock: ${product.stock}',
                      style: TextStyle(
                        color: product.stock <= 5 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => onOpenProduct(product.id),
                          child: const Text('Details'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: canAdd
                              ? () => onAddToCart(product.id)
                              : null,
                          child: Text(canAdd ? 'Add' : 'Out'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
