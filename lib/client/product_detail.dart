import 'package:flutter/material.dart';

import 'models.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.cartQuantity,
    required this.onAddToCart,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onRate,
  });

  final Product product;
  final int cartQuantity;
  final VoidCallback onAddToCart;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final void Function(int rating) onRate;

  @override
  Widget build(BuildContext context) {
    final canAdd = cartQuantity < product.stock && product.stock > 0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(product.name),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: Colors.black12,
                          child: Center(child: Icon(Icons.image_not_supported)),
                        ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(product.category)),
                      Chip(
                        label: Text(
                          product.stock > 0
                              ? '${product.stock} available'
                              : 'Out of stock',
                        ),
                        backgroundColor: product.stock > 0
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < product.ratingAvg.round()
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('(${product.ratingCount})'),
                      const Spacer(),
                      IconButton(
                        onPressed: onToggleFavorite,
                        icon: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                        ),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: List.generate(
                      5,
                      (index) => OutlinedButton(
                        onPressed: () => onRate(index + 1),
                        child: Text('${index + 1}★'),
                      ),
                    ),
                  ),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.isDiscountActive
                        ? 'Now \$${product.discountedPrice.toStringAsFixed(2)}'
                        : '\$${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (product.isDiscountActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Was \$${product.price.toStringAsFixed(2)} • Save ${product.effectiveDiscountPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    product.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Free delivery on orders over \$50. Same-day pickup available.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total'),
                    Text(
                      '\$${product.discountedPrice.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: canAdd ? onAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(canAdd ? 'Add to cart' : 'Out of stock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
