import 'dart:async';

import 'package:flutter/material.dart';

import 'models.dart';
import '../widgets/skeleton.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    required this.products,
    required this.cartQuantityForProduct,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.isLoading,
  });

  final List<Product> products;
  final int Function(String productId) cartQuantityForProduct;
  final void Function(String productId) onOpenProduct;
  final void Function(String productId) onAddToCart;
  final bool Function(String productId) isFavorite;
  final Future<void> Function(String productId) onToggleFavorite;
  final bool isLoading;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _query = '';
  String _selectedCategory = 'All';
  String _sort = 'Featured';
  final Map<String, int> _visibleRowsByCategory = {};

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
        filtered.sort(
          (a, b) => a.discountedPrice.compareTo(b.discountedPrice),
        );
        break;
      case 'Price: High to Low':
        filtered.sort(
          (a, b) => b.discountedPrice.compareTo(a.discountedPrice),
        );
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

  Map<String, List<Product>> _grouped(List<Product> items) {
    final map = <String, List<Product>>{};
    for (final product in items) {
      map.putIfAbsent(product.category, () => []).add(product);
    }
    return map;
  }

  List<Product> _carouselItems(List<Product> items) {
    if (items.isEmpty) {
      return [];
    }
    if (items.length >= 5) {
      return items.take(5).toList(growable: false);
    }
    final result = <Product>[];
    var index = 0;
    while (result.length < 5) {
      result.add(items[index % items.length]);
      index += 1;
    }
    return result;
  }

  int _visibleRows(String category, int maxRows) {
    return _visibleRowsByCategory[category] ?? maxRows;
  }

  void _showMoreRows(String category) {
    setState(() {
      _visibleRowsByCategory[category] =
          (_visibleRowsByCategory[category] ?? 3) + 3;
    });
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
    if (widget.isLoading) {
      final columns = _columnsForWidth(MediaQuery.of(context).size.width);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: const SkeletonBox(height: 48),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: const [
                Expanded(child: SkeletonBox(height: 36)),
                SizedBox(width: 12),
                SizedBox(width: 200, child: SkeletonBox(height: 36)),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              itemCount: columns * 3,
              itemBuilder: (context, index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: SkeletonBox(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                    ),
                    SizedBox(height: 10),
                    SkeletonBox(height: 14, width: 120),
                    SizedBox(height: 6),
                    SkeletonBox(height: 12),
                    SizedBox(height: 10),
                    SkeletonBox(height: 36),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    if (widget.products.isEmpty) {
      return const Center(child: Text('No products available right now.'));
    }

    final products = _filtered;
    final columns = _columnsForWidth(MediaQuery.of(context).size.width);
    final grouped = _grouped(products);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search products, categories, deals',
              prefixIcon: Icon(Icons.search),
              filled: true,
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
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: grouped.entries.map((entry) {
                    final category = entry.key;
                    final items = entry.value;
                    final carouselItems = _carouselItems(items);
                    final visibleRows = _visibleRows(category, 3);
                    final maxItems = visibleRows * columns;
                    final visibleItems = items.take(maxItems).toList();
                    final hasMore = items.length > visibleItems.length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              category,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Spacer(),
                            Text('${items.length} items'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: MediaQuery.of(context).size.width >= 1000
                              ? 240
                              : 160,
                          child: CategoryCarousel(
                            items: carouselItems,
                            onOpenProduct: widget.onOpenProduct,
                            isFavorite: widget.isFavorite,
                            onToggleFavorite: widget.onToggleFavorite,
                          ),
                        ),
                        const SizedBox(height: 14),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: visibleItems.length,
                          itemBuilder: (context, index) {
                            final product = visibleItems[index];
                            final currentCartQty =
                                widget.cartQuantityForProduct(product.id);
                            final canAdd =
                                currentCartQty < product.stock &&
                                    product.stock > 0;

                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => widget.onOpenProduct(product.id),
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
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
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  const ColoredBox(
                                                    color: Colors.black12,
                                                    child: Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 12,
                                            top: 12,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                product.category,
                                                style:
                                                    const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          if (product.isDiscountActive)
                                            Positioned(
                                              right: 12,
                                              top: 12,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '-${product.discountPercent.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onPrimary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            right: 10,
                                            bottom: 10,
                                            child: Material(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withValues(alpha: 0.9),
                                              shape: const CircleBorder(),
                                              child: IconButton(
                                                icon: Icon(
                                                  widget.isFavorite(product.id)
                                                      ? Icons.star_rounded
                                                      : Icons.star_border_rounded,
                                                ),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                onPressed: () =>
                                                    widget.onToggleFavorite(
                                                      product.id,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            product.description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: List.generate(
                                                      5,
                                                      (star) => Icon(
                                                        star <
                                                                product
                                                                    .ratingAvg
                                                                    .round()
                                                            ? Icons.star_rounded
                                                            : Icons
                                                                .star_border_rounded,
                                                        size: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '(${product.ratingCount})',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  if (product.isDiscountActive)
                                                    Text(
                                                      '\$${product.price.toStringAsFixed(2)}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            decoration:
                                                                TextDecoration
                                                                    .lineThrough,
                                                            color: Theme.of(
                                                              context,
                                                            )
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                    ),
                                                  Text(
                                                    '\$${product.discountedPrice.toStringAsFixed(2)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall,
                                                  ),
                                                  if (currentCartQty > 0)
                                                    Text(
                                                      'In cart: $currentCartQty',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (product.isDiscountActive &&
                                              product.discountEnd != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Ends ${product.discountEnd!.toLocal().toString().split(' ').first}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  product.stock > 0
                                                      ? '${product.stock} in stock'
                                                      : 'Out of stock',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: product.stock <= 5
                                                        ? Colors.red
                                                        : Colors.green,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              FilledButton(
                                                onPressed: canAdd
                                                    ? () =>
                                                          widget.onAddToCart(
                                                            product.id,
                                                          )
                                                    : null,
                                                style:
                                                    FilledButton.styleFrom(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 14,
                                                    vertical: 6,
                                                  ),
                                                ),
                                                child: Text(
                                                  canAdd ? 'Add' : 'Out',
                                                ),
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
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _showMoreRows(category),
                                icon: const Icon(Icons.expand_more),
                                label: const Text('Show more'),
                              ),
                            ),
                          ),
                        const SizedBox(height: 28),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class CategoryCarousel extends StatefulWidget {
  const CategoryCarousel({
    super.key,
    required this.items,
    required this.onOpenProduct,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final List<Product> items;
  final void Function(String productId) onOpenProduct;
  final bool Function(String productId) isFavorite;
  final Future<void> Function(String productId) onToggleFavorite;

  @override
  State<CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<CategoryCarousel> {
  PageController? _controller;
  Timer? _timer;
  double _viewportFraction = 0.9;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || widget.items.isEmpty) {
        return;
      }
      final next = (_controller?.page?.round() ?? 0) + 1;
      final target = next % widget.items.length;
      _controller?.animateToPage(
        target,
        duration: const Duration(milliseconds: 2800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final nextFraction = isWide ? 1.0 : 0.9;
    if (_viewportFraction != nextFraction) {
      _viewportFraction = nextFraction;
      _controller?.dispose();
      _controller = PageController(viewportFraction: _viewportFraction);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;
    return PageView.builder(
      controller: _controller,
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final product = widget.items[index];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onOpenProduct(product.id),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(Icons.image_not_supported),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: isWide ? 18 : 12,
                        horizontal: isWide ? 8 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (isWide
                                    ? Theme.of(context).textTheme.titleLarge
                                    : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            product.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: isWide ? 13 : null,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                        5,
                                        (star) => Icon(
                                          star < product.ratingAvg.round()
                                              ? Icons.star_rounded
                                              : Icons.star_border_rounded,
                                          size: 14,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '(${product.ratingCount})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    if (product.isDiscountActive)
                                      Text(
                                        '\$${product.price.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    Text(
                                      '\$${product.discountedPrice.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  widget.isFavorite(product.id)
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                ),
                                color: Theme.of(context).colorScheme.primary,
                                onPressed: () =>
                                    widget.onToggleFavorite(product.id),
                              ),
                            ],
                          ),
                          if (product.isDiscountActive &&
                              product.discountEnd != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Ends ${product.discountEnd!.toLocal().toString().split(' ').first}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
