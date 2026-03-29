import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/press_scale.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.items,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onCheckout,
  });

  final List<CartViewItem> items;
  final void Function(CartViewItem item) onIncrease;
  final void Function(CartViewItem item) onDecrease;
  final void Function(CartViewItem item) onRemove;
  final void Function(List<CartViewItem> selectedItems) onCheckout;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedProductIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedProductIds.addAll(widget.items.map((item) => item.productId));
  }

  @override
  void didUpdateWidget(covariant CartPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousIds = oldWidget.items.map((item) => item.productId).toSet();
    final currentIds = widget.items.map((item) => item.productId).toSet();

    _selectedProductIds.removeWhere((id) => !currentIds.contains(id));
    _selectedProductIds.addAll(currentIds.difference(previousIds));

    if (previousIds.isEmpty &&
        currentIds.isNotEmpty &&
        _selectedProductIds.isEmpty) {
      _selectedProductIds.addAll(currentIds);
    }
  }

  List<CartViewItem> get _selectedItems {
    return widget.items
        .where((item) => _selectedProductIds.contains(item.productId))
        .toList(growable: false);
  }

  double get _selectedTotal {
    var total = 0.0;
    for (final item in _selectedItems) {
      total += item.subtotal;
    }
    return total;
  }

  int get _selectedQuantityCount {
    return _selectedItems.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  bool get _allSelected =>
      widget.items.isNotEmpty &&
      _selectedProductIds.length == widget.items.length;

  void _setItemSelected(String productId, bool isSelected) {
    setState(() {
      if (isSelected) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedProductIds
        ..clear()
        ..addAll(widget.items.map((item) => item.productId));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 560;
    final isWide = width >= 760;
    final theme = Theme.of(context);

    if (widget.items.isEmpty) {
      return const Center(
        child: Text('Your cart is empty. Add products from the shop tab.'),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = widget.items[index];
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
                      selected: _selectedProductIds.contains(item.productId),
                      onToggleSelected: (value) =>
                          _setItemSelected(item.productId, value),
                      onIncrease: () => widget.onIncrease(item),
                      onDecrease: () => widget.onDecrease(item),
                      onRemove: () => widget.onRemove(item),
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
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.surface,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
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
                      ? _CartFooterWide(
                          selectedProductCount: _selectedItems.length,
                          selectedQuantityCount: _selectedQuantityCount,
                          totalProductCount: widget.items.length,
                          selectedTotal: _selectedTotal,
                          allSelected: _allSelected,
                          onSelectAll: _selectAll,
                          onClearSelection: _clearSelection,
                          onCheckout: _selectedItems.isEmpty
                              ? null
                              : () => widget.onCheckout(_selectedItems),
                        )
                      : _CartFooterCompact(
                          selectedProductCount: _selectedItems.length,
                          selectedQuantityCount: _selectedQuantityCount,
                          totalProductCount: widget.items.length,
                          selectedTotal: _selectedTotal,
                          allSelected: _allSelected,
                          onSelectAll: _selectAll,
                          onClearSelection: _clearSelection,
                          onCheckout: _selectedItems.isEmpty
                              ? null
                              : () => widget.onCheckout(_selectedItems),
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

class _CartFooterWide extends StatelessWidget {
  const _CartFooterWide({
    required this.selectedProductCount,
    required this.selectedQuantityCount,
    required this.totalProductCount,
    required this.selectedTotal,
    required this.allSelected,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onCheckout,
  });

  final int selectedProductCount;
  final int selectedQuantityCount;
  final int totalProductCount;
  final double selectedTotal;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  Text(
                    'Selected total',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _SelectionMetaChip(
                    label:
                        '$selectedProductCount of $totalProductCount products',
                  ),
                  _SelectionMetaChip(
                    label:
                        '$selectedQuantityCount item${selectedQuantityCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '\$${selectedTotal.toStringAsFixed(2)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: allSelected ? null : onSelectAll,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Select all'),
                  ),
                  TextButton.icon(
                    onPressed: selectedProductCount == 0
                        ? null
                        : onClearSelection,
                    icon: const Icon(Icons.radio_button_unchecked_rounded),
                    label: Text(
                      selectedProductCount == totalProductCount
                          ? 'Unselect all'
                          : 'Clear selection',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 300,
          child: PressScale(
            child: FilledButton(
              onPressed: onCheckout,
              child: Text(
                selectedProductCount == 0
                    ? 'Select products to checkout'
                    : 'Proceed to checkout',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartFooterCompact extends StatelessWidget {
  const _CartFooterCompact({
    required this.selectedProductCount,
    required this.selectedQuantityCount,
    required this.totalProductCount,
    required this.selectedTotal,
    required this.allSelected,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onCheckout,
  });

  final int selectedProductCount;
  final int selectedQuantityCount;
  final int totalProductCount;
  final double selectedTotal;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Selected total',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${selectedTotal.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SelectionMetaChip(
                    label:
                        '$selectedProductCount of $totalProductCount products',
                  ),
                  _SelectionMetaChip(
                    label:
                        '$selectedQuantityCount item${selectedQuantityCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: allSelected ? null : onSelectAll,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Select all'),
            ),
            TextButton.icon(
              onPressed: selectedProductCount == 0 ? null : onClearSelection,
              icon: const Icon(Icons.radio_button_unchecked_rounded),
              label: Text(
                selectedProductCount == totalProductCount
                    ? 'Unselect all'
                    : 'Clear selection',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        PressScale(
          child: FilledButton(
            onPressed: onCheckout,
            child: Text(
              selectedProductCount == 0
                  ? 'Select products to checkout'
                  : 'Proceed to checkout',
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionMetaChip extends StatelessWidget {
  const _SelectionMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    required this.selected,
    required this.onToggleSelected,
  });

  final CartViewItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;
  final bool compact;
  final bool selected;
  final ValueChanged<bool> onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactSizing = compact || constraints.maxWidth < 420;

        return Card(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.22)
              : Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.55)
                  : scheme.outlineVariant.withValues(alpha: 0.28),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(useCompactSizing ? 14 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CartSelectionToggle(
                  selected: selected,
                  onChanged: onToggleSelected,
                ),
                SizedBox(width: useCompactSizing ? 12 : 14),
                _CartImage(
                  imageUrl: item.product.imageUrl,
                  compact: useCompactSizing,
                ),
                SizedBox(width: useCompactSizing ? 14 : 18),
                Expanded(
                  child: _CartItemInfo(item: item, compact: useCompactSizing),
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
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
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

class _CartSelectionToggle extends StatelessWidget {
  const _CartSelectionToggle({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.primary : Colors.transparent,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outline,
            width: 2,
          ),
        ),
        child: selected
            ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
            : null,
      ),
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
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
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
