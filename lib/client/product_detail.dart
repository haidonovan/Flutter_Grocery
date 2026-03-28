import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
import '../widgets/entrance_motion.dart';
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes the comment permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

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

  Future<void> _toggleFavorite(ScaffoldMessengerState messenger) async {
    if (!widget.store.isAuthenticated) {
      _ensureLogin();
      messenger.showSnackBar(
        const SnackBar(content: Text('Login to favorite products.')),
      );
      return;
    }
    try {
      await widget.store.toggleFavorite(widget.product.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _submitRating(
    int ratingValue,
    ScaffoldMessengerState messenger,
  ) async {
    if (!widget.store.isAuthenticated) {
      _ensureLogin();
      messenger.showSnackBar(
        const SnackBar(content: Text('Login to rate products.')),
      );
      return;
    }
    try {
      await widget.store.submitRating(widget.product.id, ratingValue);
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _buildProductHero(
    BuildContext context, {
    required bool isFavorite,
    required ScaffoldMessengerState messenger,
  }) {
    return EntranceMotion(
      delay: const Duration(milliseconds: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.product.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.24),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: Chip(label: Text(widget.product.category)),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => _toggleFavorite(messenger),
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChips(BuildContext context) {
    return EntranceMotion(
      delay: const Duration(milliseconds: 80),
      child: Wrap(
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
    );
  }

  Widget _buildDeliveryCard(BuildContext context) {
    return EntranceMotion(
      delay: const Duration(milliseconds: 360),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.95),
              Theme.of(
                context,
              ).colorScheme.secondaryContainer.withValues(alpha: 0.82),
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Same-day pickup available for essentials and fresh items.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlinePurchaseCard(BuildContext context, bool canAdd) {
    final theme = Theme.of(context);
    return EntranceMotion(
      delay: const Duration(milliseconds: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: theme.cardColor.withValues(alpha: 0.94),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to cart', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '\$${widget.product.discountedPrice.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.cartQuantity > 0
                  ? '${widget.cartQuantity} already in your cart'
                  : 'Ready to add this item to your cart.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canAdd ? widget.onAddToCart : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(canAdd ? 'Add to cart' : 'Out of stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryColumn(
    BuildContext context, {
    required bool canAdd,
    required bool showInlinePurchaseCard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetaChips(context),
        const SizedBox(height: 12),
        EntranceMotion(
          delay: const Duration(milliseconds: 160),
          child: Text(
            widget.product.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        EntranceMotion(
          delay: const Duration(milliseconds: 220),
          child: Text(
            '\$${widget.product.discountedPrice.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
        EntranceMotion(
          delay: const Duration(milliseconds: 280),
          child: Text(
            widget.product.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        _buildDeliveryCard(context),
        if (showInlinePurchaseCard) ...[
          const SizedBox(height: 20),
          _buildInlinePurchaseCard(context, canAdd),
        ],
      ],
    );
  }

  Widget _buildFeedbackSection(
    BuildContext context, {
    required List<ProductComment> comments,
    required bool canComment,
    required ScaffoldMessengerState messenger,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntranceMotion(
          delay: const Duration(milliseconds: 440),
          child: Text(
            'Rate this product',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          children: List.generate(5, (index) {
            final ratingValue = index + 1;
            final isActive = widget.product.ratingAvg >= ratingValue;
            return IconButton(
              onPressed: () => _submitRating(ratingValue, messenger),
              icon: Icon(
                isActive ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        EntranceMotion(
          delay: const Duration(milliseconds: 520),
          child: Text(
            'Customer comments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingComments)
          const LinearProgressIndicator()
        else if (comments.isEmpty)
          const Text('No comments yet. Be the first to comment.'),
        const SizedBox(height: 8),
        ...comments.asMap().entries.map((entry) {
          final comment = entry.value;
          final canEdit = widget.store.isAdmin ||
              (widget.store.userId != null &&
                  widget.store.userId == comment.userId);
          return EntranceMotion(
            delay: Duration(milliseconds: 560 + (entry.key * 50)),
            duration: const Duration(milliseconds: 760),
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _CommentAvatar(comment: comment),
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                title: Text(comment.userDisplayName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comment.userDisplayName != comment.userEmail) ...[
                      const SizedBox(height: 2),
                      Text(
                        comment.userEmail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
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
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    : null,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        if (!canComment)
          FilledButton.tonal(
            onPressed: () {
              _ensureLogin();
              messenger.showSnackBar(
                const SnackBar(content: Text('Login to add a comment.')),
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
    );
  }

  Widget _buildMobileBottomBar(BuildContext context, bool canAdd) {
    return EntranceMotion(
      delay: const Duration(milliseconds: 260),
      child: SafeArea(
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
              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
  }

  @override
  Widget build(BuildContext context) {
    final canAdd =
        widget.cartQuantity < widget.product.stock && widget.product.stock > 0;
    final messenger = ScaffoldMessenger.of(context);

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final comments = widget.store.commentsFor(widget.product.id);
        final isFavorite = widget.store.isFavorite(widget.product.id);
        final canComment = widget.store.isAuthenticated;
        final isDesktop = MediaQuery.of(context).size.width >= 1000;

        if (isDesktop) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.product.name),
              actions: [
                IconButton(
                  onPressed: () => _toggleFavorite(messenger),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final mediaQuery = MediaQuery.of(context);
                const horizontalPadding = 24.0;
                const verticalPadding = 24.0;
                const columnGap = 28.0;
                final rightPanelWidth = constraints.maxWidth >= 1500 ? 460.0 : 420.0;
                final availableImageWidth =
                    constraints.maxWidth -
                    (horizontalPadding * 2) -
                    columnGap -
                    rightPanelWidth;
                final imageHeightCap =
                    mediaQuery.size.height -
                    mediaQuery.padding.top -
                    kToolbarHeight -
                    (verticalPadding * 2) -
                    40;
                var imageSide = availableImageWidth;
                if (imageSide > imageHeightCap) {
                  imageSide = imageHeightCap;
                }
                if (imageSide < 460) {
                  imageSide = 460;
                }
                final desktopContentWidth =
                    imageSide + columnGap + rightPanelWidth;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    verticalPadding,
                    horizontalPadding,
                    40,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: desktopContentWidth,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: imageSide,
                            child: _buildProductHero(
                              context,
                              isFavorite: isFavorite,
                              messenger: messenger,
                            ),
                          ),
                          const SizedBox(width: columnGap),
                          SizedBox(
                            width: rightPanelWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryColumn(
                                  context,
                                  canAdd: canAdd,
                                  showInlinePurchaseCard: true,
                                ),
                                const SizedBox(height: 20),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: _buildFeedbackSection(
                                      context,
                                      comments: comments,
                                      canComment: canComment,
                                      messenger: messenger,
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
                );
              },
            ),
          );
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 320,
                actions: [
                  IconButton(
                    onPressed: () => _toggleFavorite(messenger),
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
                      _buildSummaryColumn(
                        context,
                        canAdd: canAdd,
                        showInlinePurchaseCard: false,
                      ),
                      const SizedBox(height: 20),
                      _buildFeedbackSection(
                        context,
                        comments: comments,
                        canComment: canComment,
                        messenger: messenger,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildMobileBottomBar(context, canAdd),
        );
      },
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.comment});

  final ProductComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imageUrl = comment.userProfileImageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.92),
            scheme.secondaryContainer.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _CommentAvatarFallback(comment: comment);
                },
              )
            : _CommentAvatarFallback(comment: comment),
      ),
    );
  }
}

class _CommentAvatarFallback extends StatelessWidget {
  const _CommentAvatarFallback({required this.comment});

  final ProductComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        comment.userInitials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
