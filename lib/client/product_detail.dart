import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import 'models.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.cartQuantity,
    required this.onAddToCart,
    required this.store,
    this.onRequireLogin,
  });

  final Product product;
  final int cartQuantity;
  final VoidCallback onAddToCart;
  final GroceryStoreState store;
  final VoidCallback? onRequireLogin;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final TextEditingController _commentController = TextEditingController();
  bool _loadingComments = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.store.loadComments(widget.product.id);
    if (mounted) {
      setState(() {
        _loadingComments = false;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _ensureLogin() {
    widget.onRequireLogin?.call();
  }

  Future<void> _submitComment() async {
    final message = _commentController.text.trim();
    if (message.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comment is too short.')));
      return;
    }

    final result = await widget.store.addComment(widget.product.id, message);
    if (!mounted) {
      return;
    }
    if (result.success) {
      _commentController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to add comment.')),
      );
    }
  }

  Future<void> _editComment(ProductComment comment) async {
    final controller = TextEditingController(text: comment.message);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == null || updated.length < 3) {
      return;
    }

    final result = await widget.store.updateComment(
      widget.product.id,
      comment.id,
      updated,
    );
    if (!mounted) {
      return;
    }
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to update comment.')),
      );
    }
  }

  Future<void> _deleteComment(ProductComment comment) async {
    final result = await widget.store.deleteComment(
      widget.product.id,
      comment.id,
    );
    if (!mounted) {
      return;
    }
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to delete comment.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        widget.cartQuantity < widget.product.stock && widget.product.stock > 0;

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final comments = widget.store.commentsFor(widget.product.id);
        final isFavorite = widget.store.isFavorite(widget.product.id);
        final canComment = widget.store.isAuthenticated;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 320,
                actions: [
                  IconButton(
                    onPressed: () {
                      if (!widget.store.isAuthenticated) {
                        _ensureLogin();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login to favorite products.'),
                          ),
                        );
                        return;
                      }
                      widget.store.toggleFavorite(widget.product.id);
                    },
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.product.name),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        widget.product.imageUrl,
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
                          Chip(label: Text(widget.product.category)),
                          Chip(
                            label: Text(
                              widget.product.stock > 0
                                  ? '${widget.product.stock} available'
                                  : 'Out of stock',
                            ),
                            backgroundColor: widget.product.stock > 0
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                          ),
                          Chip(
                            label: Text(
                              '${widget.product.ratingAvg.toStringAsFixed(1)} * (${widget.product.ratingCount})',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${widget.product.discountedPrice.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.product.isDiscountActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${widget.product.discountPercent.toStringAsFixed(0)}% off',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        widget.product.description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.95),
                              Theme.of(context).colorScheme.secondaryContainer
                                  .withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.local_shipping_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Free delivery over \$50',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Same-day pickup available for essentials and fresh items.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Rate this product',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          final ratingValue = index + 1;
                          final isActive =
                              widget.product.ratingAvg >= ratingValue;
                          return IconButton(
                            onPressed: () {
                              if (!widget.store.isAuthenticated) {
                                _ensureLogin();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Login to rate products.'),
                                  ),
                                );
                                return;
                              }
                              widget.store.submitRating(
                                widget.product.id,
                                ratingValue,
                              );
                            },
                            icon: Icon(
                              isActive ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Customer comments',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_loadingComments)
                        const LinearProgressIndicator()
                      else if (comments.isEmpty)
                        const Text('No comments yet. Be the first to comment.'),
                      const SizedBox(height: 8),
                      ...comments.map((comment) {
                        final canEdit =
                            widget.store.isAdmin ||
                            (widget.store.userId != null &&
                                widget.store.userId == comment.userId);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(comment.userEmail),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(comment.message),
                                const SizedBox(height: 6),
                                Text(
                                  comment.isEdited
                                      ? 'Edited - ${comment.createdAt.toLocal()}'
                                      : comment.createdAt.toLocal().toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: canEdit
                                ? PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _editComment(comment);
                                      } else if (value == 'delete') {
                                        _deleteComment(comment);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      if (!canComment)
                        FilledButton.tonal(
                          onPressed: () {
                            _ensureLogin();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Login to add a comment.'),
                              ),
                            );
                          },
                          child: const Text('Login to comment'),
                        )
                      else
                        Column(
                          children: [
                            TextField(
                              controller: _commentController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Write a comment',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _submitComment,
                                child: const Text('Post comment'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 420;
                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '\$${widget.product.discountedPrice.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: canAdd ? widget.onAddToCart : null,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: Text(canAdd ? 'Add to cart' : 'Out of stock'),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total'),
                            Text(
                              '\$${widget.product.discountedPrice.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: canAdd ? widget.onAddToCart : null,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(canAdd ? 'Add to cart' : 'Out of stock'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
