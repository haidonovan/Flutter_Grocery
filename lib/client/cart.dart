import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/press_scale.dart';

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
    final isCompact = MediaQuery.of(context).size.width < 520;

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
              return EntranceMotion(
                delay: Duration(milliseconds: 80 + (index * 60)),
                duration: const Duration(milliseconds: 820),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Flex(
                      direction: isCompact ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: isCompact
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
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
                        SizedBox(
                          width: isCompact ? 0 : 12,
                          height: isCompact ? 12 : 0,
                        ),
                        if (isCompact)
                          SizedBox(
                            width: double.infinity,
                            child: _CartItemDetails(
                              item: item,
                              onIncrease: () => onIncrease(item),
                              onDecrease: () => onDecrease(item),
                              onRemove: () => onRemove(item),
                              stacked: true,
                            ),
                          )
                        else
                          Expanded(
                            child: _CartItemDetails(
                              item: item,
                              onIncrease: () => onIncrease(item),
                              onDecrease: () => onDecrease(item),
                              onRemove: () => onRemove(item),
                              stacked: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        EntranceMotion(
          delay: const Duration(milliseconds: 220),
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          '\$${totalAmount.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PressScale(
                    child: FilledButton(
                      onPressed: onCheckout,
                      child: const Text('Proceed to checkout'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartItemDetails extends StatelessWidget {
  const _CartItemDetails({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.stacked,
  });

  final CartViewItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.product.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          item.product.discountPercent > 0
              ? '\$${item.product.discountedPrice.toStringAsFixed(2)} each (was \$${item.product.price.toStringAsFixed(2)})'
              : '\$${item.product.price.toStringAsFixed(2)} each',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );

    final controls = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onDecrease,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${item.quantity}'),
            IconButton(
              onPressed: onIncrease,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        TextButton(onPressed: onRemove, child: const Text('Remove')),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [info, const SizedBox(height: 8), controls],
      );
    }

    return Row(
      children: [
        Expanded(child: info),
        const SizedBox(width: 8),
        controls,
      ],
    );
  }
}
