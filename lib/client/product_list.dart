import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/entrance_motion.dart';
import '../widgets/hover_lift.dart';
import '../widgets/press_scale.dart';
import 'models.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    required this.products,
    required this.cartQuantityForProduct,
    required this.onOpenProduct,
    required this.onAddToCart,
    this.isLoading = false,
    this.isFavorite,
    this.onToggleFavorite,
  });

  final List<Product> products;
  final int Function(String productId) cartQuantityForProduct;
  final void Function(String productId) onOpenProduct;
  final void Function(String productId) onAddToCart;
  final bool isLoading;
  final bool Function(String productId)? isFavorite;
  final void Function(String productId)? onToggleFavorite;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  String _query = '';
  String _selectedCategory = 'All';
  String _sort = 'Featured';
  final Map<String, int> _categoryPages = {};
  int _contentMotionEpoch = 0;

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
        filtered.sort((a, b) => a.discountedPrice.compareTo(b.discountedPrice));
        break;
      case 'Price: High to Low':
        filtered.sort((a, b) => b.discountedPrice.compareTo(a.discountedPrice));
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
    if (width >= 1200) {
      return 4;
    }
    if (width >= 900) {
      return 3;
    }
    return 2;
  }

  double _cardMainAxisExtent(double width, int columns) {
    const horizontalPadding = 32.0;
    const crossAxisSpacing = 16.0;
    final availableWidth = width - horizontalPadding;
    final cardWidth =
        (availableWidth - ((columns - 1) * crossAxisSpacing)) / columns;
    final imageHeight = cardWidth * 0.75;

    final detailsHeight = switch (columns) {
      2 when width < 430 => 188.0,
      2 => 182.0,
      3 => 176.0,
      _ => 170.0,
    };

    return imageHeight + detailsHeight;
  }

  int _pageSizeForColumns(int columns) => columns * 3;

  int _visibleCountForCategory(String category, int total, int columns) {
    final page = _categoryPages[category] ?? 1;
    final count = page * _pageSizeForColumns(columns);
    return count > total ? total : count;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.products.isEmpty) {
      return const Center(child: Text('No products available right now.'));
    }

    final products = _filtered;
    final width = MediaQuery.of(context).size.width;
    final columns = _columnsForWidth(width);
    final cardMainAxisExtent = _cardMainAxisExtent(width, columns);
    final categories = _selectedCategory == 'All'
        ? products.map((p) => p.category).toSet().toList()
        : [_selectedCategory];

    return ListView(
      children: [
        EntranceMotion(
          delay: const Duration(milliseconds: 80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.42),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products, categories, deals',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value;
                    _categoryPages.clear();
                  });
                },
              ),
            ),
          ),
        ),
        EntranceMotion(
          delay: const Duration(milliseconds: 160),
          child: Padding(
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
                            _categoryPages.clear();
                            _contentMotionEpoch += 1;
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
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Featured',
                      child: Text('Featured'),
                    ),
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
                      _categoryPages.clear();
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
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No matching products.')),
          )
        else
          ...categories.map((category) {
            final categoryProducts = products
                .where((p) => p.category == category)
                .toList();
            if (categoryProducts.isEmpty) {
              return const SizedBox.shrink();
            }
            final carouselItems = categoryProducts.take(5).toList();
            final visibleCount = _visibleCountForCategory(
              category,
              categoryProducts.length,
              columns,
            );
            final visibleProducts = categoryProducts
                .take(visibleCount)
                .toList();
            final canShowMore = visibleCount < categoryProducts.length;

            return EntranceMotion(
              delay: Duration(
                milliseconds: 240 + (categories.indexOf(category) * 120),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryCarousel(
                      title: category,
                      products: carouselItems,
                      reverse: categories.indexOf(category).isOdd,
                      onOpen: (id) => widget.onOpenProduct(id),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: cardMainAxisExtent,
                      ),
                      itemCount: visibleProducts.length,
                      itemBuilder: (context, index) {
                        final product = visibleProducts[index];
                        final currentCartQty = widget.cartQuantityForProduct(
                          product.id,
                        );
                        final canAdd =
                            currentCartQty < product.stock && product.stock > 0;

                        return EntranceMotion(
                          key: ValueKey(
                            'product-motion-$_contentMotionEpoch-$product.id',
                          ),
                          delay: Duration(milliseconds: 60 + (index * 55)),
                          duration: const Duration(milliseconds: 560),
                          beginOffset: const Offset(0, -0.06),
                          child: _ProductCard(
                            product: product,
                            canAdd: canAdd,
                            inCartQty: currentCartQty,
                            isCompact: columns == 2 && width < 430,
                            isFavorite:
                                widget.isFavorite?.call(product.id) ?? false,
                            onFavorite: widget.onToggleFavorite == null
                                ? null
                                : () => widget.onToggleFavorite!(product.id),
                            onOpen: () => widget.onOpenProduct(product.id),
                            onAdd: () => widget.onAddToCart(product.id),
                          ),
                        );
                      },
                    ),
                    if (canShowMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: FilledButton.tonal(
                            onPressed: () {
                              setState(() {
                                _categoryPages[category] =
                                    (_categoryPages[category] ?? 1) + 1;
                              });
                            },
                            child: const Text('Show more'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.canAdd,
    required this.inCartQty,
    required this.isCompact,
    required this.isFavorite,
    required this.onOpen,
    required this.onAdd,
    this.onFavorite,
  });

  final Product product;
  final bool canAdd;
  final int inCartQty;
  final bool isCompact;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      enabled: MediaQuery.of(context).size.width >= 900,
      hoverOffset: 6,
      hoverScale: 1.01,
      hoverElevation: 22,
      normalElevation: 10,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
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
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (onFavorite != null)
                            IconButton(
                              onPressed: onFavorite,
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.white,
                              ),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.description,
                        maxLines: isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '\$${product.discountedPrice.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isCompact ? 18 : null,
                                ),
                          ),
                          if (product.isDiscountActive)
                            Text(
                              '${product.discountPercent.toStringAsFixed(0)}% off',
                              style: const TextStyle(color: Colors.green),
                            ),
                          Text(
                            '${product.ratingAvg.toStringAsFixed(1)} *',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            product.stock > 0
                                ? '${product.stock} in stock'
                                : 'Out of stock',
                            style: TextStyle(
                              color: product.stock <= 5 ? Colors.red : Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          if (inCartQty > 0)
                            Text(
                              'In cart: $inCartQty',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: PressScale(
                          enabled: canAdd,
                          child: FilledButton(
                            onPressed: canAdd ? onAdd : null,
                            child: Text(canAdd ? 'Add to cart' : 'Out of stock'),
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
  }
}

class _CategoryCarousel extends StatefulWidget {
  const _CategoryCarousel({
    required this.title,
    required this.products,
    required this.reverse,
    required this.onOpen,
  });

  final String title;
  final List<Product> products;
  final bool reverse;
  final void Function(String productId) onOpen;

  @override
  State<_CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<_CategoryCarousel> {
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _pauseAutoScroll = false;
  double _offset = 0;
  static const double _spacing = 16;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      if (!mounted || widget.products.length < 2) {
        return;
      }
      if (_pauseAutoScroll) {
        _lastElapsed = Duration.zero;
        return;
      }
      if (_lastElapsed == Duration.zero) {
        _lastElapsed = elapsed;
        return;
      }
      final delta = elapsed - _lastElapsed;
      _lastElapsed = elapsed;
      if (delta.inMicroseconds <= 0) {
        return;
      }
      final width = MediaQuery.of(context).size.width;
      final cardWidth = _cardWidthForWidth(width);
      final cycleWidth = (cardWidth + _spacing) * widget.products.length;
      if (cycleWidth <= 0) {
        return;
      }
      final speed = width < 600 ? 22.0 : 28.0;
      final nextOffset =
          (_offset + (delta.inMicroseconds / 1000000) * speed) % cycleWidth;
      setState(() {
        _offset = nextOffset;
      });
    });
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant _CategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products.length != widget.products.length) {
      _offset = 0;
    }
  }

  void _setPause(bool value) {
    if (!mounted || _pauseAutoScroll == value) {
      return;
    }
    setState(() {
      _pauseAutoScroll = value;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _cardWidthForWidth(double width) {
    if (width < 600) {
      return width * 0.74;
    }
    if (width < 1024) {
      return 360;
    }
    return 420;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;
    final height = isNarrow ? 230.0 : 290.0;
    final cardWidth = _cardWidthForWidth(MediaQuery.of(context).size.width);
    final cycleWidth = (cardWidth + _spacing) * widget.products.length;
    final repeatedProducts = [
      ...widget.products,
      ...widget.products,
      ...widget.products,
    ];
    final translateX = widget.reverse
        ? (-cycleWidth + _offset)
        : (-cycleWidth - _offset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        MouseRegion(
          onEnter: (_) => _setPause(true),
          onExit: (_) => _setPause(false),
          child: GestureDetector(
            onHorizontalDragStart: (_) => _setPause(true),
            onHorizontalDragEnd: (_) => _setPause(false),
            onHorizontalDragCancel: () => _setPause(false),
            onTapDown: (_) => _setPause(true),
            onTapUp: (_) => _setPause(false),
            onTapCancel: () => _setPause(false),
            child: SizedBox(
              height: height,
              child: ClipRect(
                child: Transform.translate(
                  offset: Offset(translateX, 0),
                  child: Row(
                    children: [
                      for (var index = 0; index < repeatedProducts.length; index++) ...[
                        SizedBox(
                          width: cardWidth,
                          child: InkWell(
                            onTap: () => widget.onOpen(repeatedProducts[index].id),
                            borderRadius: BorderRadius.circular(24),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    repeatedProducts[index].imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const ColoredBox(
                                          color: Colors.black12,
                                          child: Center(
                                            child: Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.06),
                                          Colors.black.withValues(alpha: 0.78),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 22,
                                    right: 22,
                                    bottom: 20,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          repeatedProducts[index].category,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          repeatedProducts[index].name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          repeatedProducts[index].description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.16),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.12),
                                            ),
                                          ),
                                          child: Text(
                                            '\$${repeatedProducts[index].discountedPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (index != repeatedProducts.length - 1)
                          const SizedBox(width: _spacing),
                      ],
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

