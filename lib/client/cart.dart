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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 560;
    final isWide = width >= 760;
    final theme = Theme.of(context);

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
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 940),
                    child: _CartItemCard(
                      item: item,
                      compact: isCompact,
                      onIncrease: () => onIncrease(item),
                      onDecrease: () => onDecrease(item),
                      onRemove: () => onRemove(item),
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
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 940),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'Total',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(width: 16),
                                    Flexible(
                                      child: Text(
                                        '\$${totalAmount.toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 280,
                                child: PressScale(
                                  child: FilledButton(
                                    onPressed: onCheckout,
                                    child: const Text('Proceed to checkout'),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme.colorScheme
                                                .onSurfaceVariant,
                                            letterSpacing: 0.4,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '\$${totalAmount.toStringAsFixed(2)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
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
            ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.compact,
  });

  final CartViewItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactSizing = compact || constraints.maxWidth < 420;

        return Card(
          child: Padding(
            padding: EdgeInsets.all(useCompactSizing ? 14 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CartImage(
                  imageUrl: item.product.imageUrl,
                  compact: useCompactSizing,
                ),
                SizedBox(width: useCompactSizing ? 14 : 18),
                Expanded(
                  child: _CartItemInfo(
                    item: item,
                    compact: useCompactSizing,
                  ),
                ),
                SizedBox(width: useCompactSizing ? 12 : 20),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: useCompactSizing ? 104 : 132,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _QuantityStepper(
                        quantity: item.quantity,
                        onIncrease: onIncrease,
                        onDecrease: onDecrease,
                        compact: useCompactSizing,
                      ),
                      SizedBox(height: useCompactSizing ? 8 : 10),
                      TextButton.icon(
                        onPressed: onRemove,
                        style: TextButton.styleFrom(
                          visualDensity: useCompactSizing
                              ? VisualDensity.compact
                              : VisualDensity.standard,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Remove'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CartImage extends StatelessWidget {
  const _CartImage({required this.imageUrl, required this.compact});

  final String imageUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 82.0 : 104.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Colors.black12,
          child: const Icon(Icons.image_not_supported),
        ),
      ),
    );
  }
}

class _CartItemInfo extends StatelessWidget {
  const _CartItemInfo({required this.item, required this.compact});

  final CartViewItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.product.name,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.product.discountPercent > 0
              ? '\$${item.product.discountedPrice.toStringAsFixed(2)} each - was \$${item.product.price.toStringAsFixed(2)}'
              : '\$${item.product.price.toStringAsFixed(2)} each',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(999),
          ),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
              children: [
                const TextSpan(text: 'Subtotal '),
                TextSpan(
                  text: '\$${item.subtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    required this.compact,
  });

  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = compact ? 20.0 : 22.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 4,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrease,
            icon: Icon(Icons.remove_circle_outline, size: iconSize),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tight(
              Size(compact ? 30 : 34, compact ? 30 : 34),
            ),
          ),
          SizedBox(
            width: compact ? 24 : 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onIncrease,
            icon: Icon(Icons.add_circle_outline, size: iconSize),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tight(
              Size(compact ? 30 : 34, compact ? 30 : 34),
            ),
          ),
        ],
      ),
    );
  }
}

