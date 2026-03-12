import 'package:flutter/material.dart';

import 'models.dart';

class ProductListPage extends StatefulWidget {
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
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _query = '';
  String _selectedCategory = 'All';
  String _sort = 'Featured';

  List<String> get _categories {
    final values = <String>{'All'};
    for (final product in widget.products) {
      values.add(product.category);
    }
    return values.toList();
  }

  List<Product> get _filtered {
    final lower = _query.trim().toLowerCase();
    final filtered = widget.products.where((product) {
      if (_selectedCategory != 'All' && product.category != _selectedCategory) {
        return false;
      }
      if (lower.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(lower) ||
          product.description.toLowerCase().contains(lower) ||
          product.category.toLowerCase().contains(lower);
    }).toList();

    switch (_sort) {
      case 'Price: Low to High':
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Stock':
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      default:
        break;
    }

    return filtered;
  }

  int _columnsForWidth(double width) {
    if (width >= 1100) {
      return 4;
    }
    if (width >= 760) {
      return 3;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const Center(child: Text('No products available right now.'));
    }

    final products = _filtered;
    final columns = _columnsForWidth(MediaQuery.of(context).size.width);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search products, categories, deals',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;

              final categoryChips = SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  },
                ),
              );

              final sortDropdown = DropdownButtonFormField<String>(
                initialValue: _sort,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Featured', child: Text('Featured')),
                  DropdownMenuItem(
                    value: 'Price: Low to High',
                    child: Text('Price: Low to High'),
                  ),
                  DropdownMenuItem(
                    value: 'Price: High to Low',
                    child: Text('Price: High to Low'),
                  ),
                  DropdownMenuItem(value: 'Stock', child: Text('Stock')),
                  DropdownMenuItem(value: 'Name', child: Text('Name')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _sort = value;
                  });
                },
              );

              if (isCompact) {
                return Column(
                  children: [
                    categoryChips,
                    const SizedBox(height: 10),
                    SizedBox(height: 44, child: sortDropdown),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: categoryChips),
                  const SizedBox(width: 12),
                  SizedBox(width: 220, child: sortDropdown),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No matching products.'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final currentCartQty = widget.cartQuantityForProduct(
                      product.id,
                    );
                    final canAdd =
                        currentCartQty < product.stock && product.stock > 0;

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => widget.onOpenProduct(product.id),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      product.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const ColoredBox(
                                                color: Colors.black12,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.image_not_supported,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    top: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        product.category,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '\$${product.price.toStringAsFixed(2)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const Spacer(),
                                      if (currentCartQty > 0)
                                        Text(
                                          'In cart: $currentCartQty',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        product.stock > 0
                                            ? '${product.stock} in stock'
                                            : 'Out of stock',
                                        style: TextStyle(
                                          color: product.stock <= 5
                                              ? Colors.red
                                              : Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Spacer(),
                                      FilledButton(
                                        onPressed: canAdd
                                            ? () =>
                                                  widget.onAddToCart(product.id)
                                            : null,
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                        ),
                                        child: Text(canAdd ? 'Add' : 'Out'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
