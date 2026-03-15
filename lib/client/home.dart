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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Order placed successfully.')),
    );

    if (result.success) {
      setState(() {
        _currentTabIndex = 2;
      });
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
