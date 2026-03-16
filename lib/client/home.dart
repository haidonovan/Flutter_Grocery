import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/grocery_store_state.dart';
import '../main.dart';
import '../widgets/app_page_route.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/theme_mode_menu.dart';
import '../widgets/coupon_banner.dart';
import 'cart.dart';
import 'checkout.dart';
import 'favorites.dart';
import 'models.dart';
import 'order_history.dart';
import 'product_detail.dart';
import 'product_list.dart';
import 'profile.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({
    super.key,
    required this.userEmail,
    required this.store,
    required this.onLogout,
    required this.themeMode,
    required this.themeStyle,
    required this.onThemeModeChanged,
    required this.onThemeStyleChanged,
  });

  final String userEmail;
  final GroceryStoreState store;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _currentTabIndex = 0;
  bool _couponPrompted = false;

  String get _title {
    switch (_currentTabIndex) {
      case 0:
        return 'Shop';
      case 1:
        return 'Favorites';
      case 2:
        return 'Cart';
      case 3:
        return 'Orders';
      default:
        return 'Profile';
    }
  }

  List<_NavItem> get _navItems => const [
    _NavItem('Shop', Icons.storefront),
    _NavItem('Favorites', Icons.favorite),
    _NavItem('Cart', Icons.shopping_cart),
    _NavItem('Orders', Icons.receipt_long),
    _NavItem('Profile', Icons.person),
  ];

  Widget _buildMobileDrawer(bool isMobile) {
    final topItems = _navItems
        .take(_navItems.length - 1)
        .toList(growable: false);
    final profileItem = _navItems.last;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: topItems.length,
                itemBuilder: (context, index) {
                  final item = topItems[index];
                  return ListTile(
                    leading: Icon(item.icon),
                    title: Text(item.label),
                    selected: _currentTabIndex == index,
                    onTap: () {
                      setState(() {
                        _currentTabIndex = index;
                      });
                      if (isMobile) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: ListTile(
                leading: Icon(profileItem.icon),
                title: Text(profileItem.label),
                selected: _currentTabIndex == _navItems.length - 1,
                onTap: () {
                  setState(() {
                    _currentTabIndex = _navItems.length - 1;
                  });
                  if (isMobile) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(String productId) {
    final success = widget.store.addToCart(productId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Added to cart.' : 'Cannot add more. Stock limit reached.',
        ),
      ),
    );
  }

  Future<void> _openProductDetail(String productId) async {
    final product = widget.store.getProductById(productId);
    if (product == null) {
      return;
    }

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          cartQuantity: widget.store.cartQuantityForProduct(product.id),
          onAddToCart: () {
            _addToCart(product.id);
          },
          store: widget.store,
        ),
      ),
    );
  }

  String _formatInvoiceDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showAnimatedNoticeDialog({
    required String title,
    required String message,
    required IconData icon,
    bool isError = false,
  }) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = isError ? scheme.error : scheme.primary;

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: title,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Okay'),
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
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInvoiceDialog(OrderRecord order) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtotal = order.lines.fold<double>(0, (sum, line) => sum + line.subtotal);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Invoice',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EntranceMotion(
                            active: true,
                            duration: const Duration(milliseconds: 440),
                            beginOffset: const Offset(0, -0.04),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long_rounded,
                                    color: scheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order placed',
                                        style: theme.textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invoice ${order.id}',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          EntranceMotion(
                            active: true,
                            delay: const Duration(milliseconds: 70),
                            duration: const Duration(milliseconds: 440),
                            beginOffset: const Offset(0, -0.03),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _InvoiceStat(
                                  label: 'Date',
                                  value: _formatInvoiceDate(order.createdAt),
                                ),
                                _InvoiceStat(
                                  label: 'Payment',
                                  value: order.paymentMethod,
                                ),
                                _InvoiceStat(
                                  label: 'Status',
                                  value: order.status.name,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          EntranceMotion(
                            active: true,
                            delay: const Duration(milliseconds: 120),
                            duration: const Duration(milliseconds: 440),
                            beginOffset: const Offset(0, -0.025),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Shipping address',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(order.shippingAddress),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          EntranceMotion(
                            active: true,
                            delay: const Duration(milliseconds: 170),
                            duration: const Duration(milliseconds: 440),
                            beginOffset: const Offset(0, -0.02),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Items',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 10),
                                ...order.lines.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final line = entry.value;
                                  return EntranceMotion(
                                    active: true,
                                    delay: Duration(milliseconds: 220 + (index * 35)),
                                    duration: const Duration(milliseconds: 420),
                                    beginOffset: const Offset(0, -0.018),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  line.productName,
                                                  style: theme.textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Qty ${line.quantity} | ${line.discountPercent > 0 ? '${line.discountPercent.toStringAsFixed(0)}% off' : 'Regular price'}',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: scheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '\$${line.subtotal.toStringAsFixed(2)}',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          EntranceMotion(
                            active: true,
                            delay: Duration(milliseconds: 240 + (order.lines.length * 35)),
                            duration: const Duration(milliseconds: 420),
                            beginOffset: const Offset(0, -0.016),
                            child: Column(
                              children: [
                                Divider(color: scheme.outlineVariant),
                                const SizedBox(height: 8),
                                _InvoiceAmountRow(
                                  label: 'Subtotal',
                                  value: '\$${subtotal.toStringAsFixed(2)}',
                                ),
                                if (order.couponCode != null && order.couponDiscount != null)
                                  _InvoiceAmountRow(
                                    label: 'Coupon ${order.couponCode}',
                                    value: '-\$${order.couponDiscount!.toStringAsFixed(2)}',
                                    highlight: true,
                                  ),
                                const SizedBox(height: 6),
                                _InvoiceAmountRow(
                                  label: 'Total',
                                  value: '\$${order.total.toStringAsFixed(2)}',
                                  prominent: true,
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.check_circle_outline),
                                    label: const Text('View orders'),
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
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, -0.02),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCheckout() async {
    final request = await Navigator.of(context).push<CheckoutRequest>(
      AppPageRoute<CheckoutRequest>(
        builder: (_) => CheckoutPage(
          totalAmount: widget.store.cartTotal,
          itemCount: widget.store.cartItemCount,
        ),
      ),
    );

    if (!mounted || request == null) {
      return;
    }

    final result = await widget.store.placeOrder(
      shippingAddress: request.shippingAddress,
      paymentMethod: request.paymentMethod,
      couponCode: request.couponCode,
    );

    if (!mounted) {
      return;
    }

    if (!result.success) {
      await _showAnimatedNoticeDialog(
        title: 'Order could not be placed',
        message: result.message ?? 'Order placement failed.',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
      return;
    }

    setState(() {
      _currentTabIndex = 3;
    });

    final order = result.order;
    if (order != null) {
      await _showInvoiceDialog(order);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Order placed successfully.')),
      );
    }
  }

  Future<void> _maybeShowCouponPrompt() async {
    if (_couponPrompted || widget.store.activeCoupons.isEmpty) {
      return;
    }
    _couponPrompted = true;

    final prefs = await SharedPreferences.getInstance();
    final key = 'shown_coupons_${widget.userEmail}';
    final shown = prefs.getStringList(key) ?? [];

    final nextCoupon = widget.store.activeCoupons.firstWhere(
      (coupon) => !shown.contains(coupon.code),
      orElse: () => widget.store.activeCoupons.first,
    );

    if (shown.contains(nextCoupon.code)) {
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CouponBanner(coupon: nextCoupon),
      ),
    );

    shown.add(nextCoupon.code);
    await prefs.setStringList(key, shown);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final orders = widget.store.allOrders;
        final cartItems = widget.store.cartItems;
        final products = widget.store.storefrontProducts;
        final favoriteProducts = products
            .where((product) => widget.store.isFavorite(product.id))
            .toList(growable: false);
        final isMobile = MediaQuery.of(context).size.width < 600;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowCouponPrompt();
        });

        final body = IndexedStack(
          index: _currentTabIndex,
          children: [
            EntranceMotion(
              active: _currentTabIndex == 0,
              child: ProductListPage(
                products: products,
                cartQuantityForProduct: widget.store.cartQuantityForProduct,
                onOpenProduct: _openProductDetail,
                onAddToCart: _addToCart,
                isFavorite: widget.store.isFavorite,
                onToggleFavorite: widget.store.toggleFavorite,
                isLoading:
                    widget.store.isInitializing ||
                    widget.store.isLoadingProducts,
              ),
            ),
            EntranceMotion(
              active: _currentTabIndex == 1,
              child: FavoritesPage(
                products: favoriteProducts,
                cartQuantityForProduct: widget.store.cartQuantityForProduct,
                onOpenProduct: _openProductDetail,
                onAddToCart: _addToCart,
                isFavorite: widget.store.isFavorite,
                onToggleFavorite: widget.store.toggleFavorite,
              ),
            ),
            EntranceMotion(
              active: _currentTabIndex == 2,
              child: CartPage(
                items: cartItems,
                totalAmount: widget.store.cartTotal,
                onIncrease: (item) {
                  final success = widget.store.increaseCartQuantity(
                    item.product.id,
                  );
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot exceed current stock.'),
                      ),
                    );
                  }
                },
                onDecrease: (item) {
                  widget.store.decreaseCartQuantity(item.product.id);
                },
                onRemove: (item) {
                  widget.store.removeFromCart(item.product.id);
                },
                onCheckout: _openCheckout,
              ),
            ),
            EntranceMotion(
              active: _currentTabIndex == 3,
              child: OrderHistoryPage(
                orders: orders,
                isLoading: widget.store.isLoadingOrders,
              ),
            ),
            EntranceMotion(
              active: _currentTabIndex == 4,
              child: ProfilePage(
                userEmail: widget.userEmail,
                totalOrders: orders.length,
                onLogout: widget.onLogout,
                onSendSupport: widget.store.submitSupportTicket,
                onReplySupport: widget.store.sendSupportThreadMessage,
                onCloseSupport: widget.store.closeSupportTicket,
                activeCoupons: widget.store.activeCoupons,
                supportTickets: widget.store.mySupportTickets,
                isLoading: widget.store.isInitializing,
              ),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              ThemeModeMenu(
                themeMode: widget.themeMode,
                themeStyle: widget.themeStyle,
                onChanged: widget.onThemeModeChanged,
                onStyleChanged: widget.onThemeStyleChanged,
              ),
              const SizedBox(width: 4),
              if (_currentTabIndex != 2)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _currentTabIndex = 2;
                      });
                    },
                    tooltip: 'Open cart',
                    icon: Badge(
                      isLabelVisible: widget.store.cartItemCount > 0,
                      label: Text('${widget.store.cartItemCount}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                ),
            ],
          ),
          drawer: isMobile ? _buildMobileDrawer(isMobile) : null,
          body: body,
          bottomNavigationBar: isMobile
              ? null
              : NavigationBar(
                  selectedIndex: _currentTabIndex,
                  destinations: _navItems
                      .map(
                        (item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                      )
                      .toList(),
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentTabIndex = index;
                    });
                  },
                ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _InvoiceStat extends StatelessWidget {
  const _InvoiceStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _InvoiceAmountRow extends StatelessWidget {
  const _InvoiceAmountRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary
        : prominent
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant;
    final textStyle = prominent
        ? theme.textTheme.titleLarge
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textStyle?.copyWith(color: color),
            ),
          ),
          Text(
            value,
            style: textStyle?.copyWith(
              color: color,
              fontWeight: prominent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
