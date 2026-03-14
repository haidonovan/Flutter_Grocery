import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';

class CartPage extends StatelessWidget {
  const CartPage({
    super.key,
    required this.items,
    required this.totalAmount,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onCheckout,
  });

  final List<CartViewItem> items;
  final double totalAmount;
  final void Function(CartViewItem item) onIncrease;
  final void Function(CartViewItem item) onDecrease;
  final void Function(CartViewItem item) onRemove;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Your cart is empty. Add products from the shop tab.'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.product.imageUrl,
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 84,
                                height: 84,
                                color: Colors.black12,
                                child: const Icon(Icons.image_not_supported),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.product.discountPercent > 0
                                  ? '\$${item.product.discountedPrice.toStringAsFixed(2)} each (was \$${item.product.price.toStringAsFixed(2)})'
                                  : '\$${item.product.price.toStringAsFixed(2)} each',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => onDecrease(item),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                onPressed: () => onIncrease(item),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => onRemove(item),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onCheckout,
                  child: const Text('Proceed to checkout'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
