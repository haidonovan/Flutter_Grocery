import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/grocery_store_state.dart';
import '../widgets/theme_mode_menu.dart';
import '../widgets/coupon_banner.dart';
import 'cart.dart';
import 'checkout.dart';
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
    required this.onThemeModeChanged,
  });

  final String userEmail;
  final GroceryStoreState store;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
        return 'Cart';
      case 2:
        return 'Orders';
      default:
        return 'Profile';
    }
  }

  List<_NavItem> get _navItems => const [
        _NavItem('Shop', Icons.storefront),
        _NavItem('Cart', Icons.shopping_cart),
        _NavItem('Orders', Icons.receipt_long),
        _NavItem('Profile', Icons.person),
      ];

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
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          cartQuantity: widget.store.cartQuantityForProduct(product.id),
          onAddToCart: () {
            _addToCart(product.id);
          },
          isFavorite: widget.store.isFavorite(product.id),
          onToggleFavorite: () async {
            await widget.store.toggleFavorite(product.id);
          },
          onRate: (rating) async {
            await widget.store.submitRating(product.id, rating);
            if (!mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Thanks for rating $rating stars.')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openCheckout() async {
    final request = await Navigator.of(context).push<CheckoutRequest>(
      MaterialPageRoute<CheckoutRequest>(
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

    final nextCoupon = widget.store.activeCoupons
        .firstWhere((coupon) => !shown.contains(coupon.code), orElse: () => widget.store.activeCoupons.first);

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
        final isMobile = MediaQuery.of(context).size.width < 600;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowCouponPrompt();
        });

        final navList = ListView.builder(
          itemCount: _navItems.length,
          itemBuilder: (context, index) {
            final item = _navItems[index];
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
        );

        final body = IndexedStack(
          index: _currentTabIndex,
          children: [
            ProductListPage(
              products: products,
              cartQuantityForProduct: widget.store.cartQuantityForProduct,
              onOpenProduct: _openProductDetail,
              onAddToCart: _addToCart,
              isFavorite: widget.store.isFavorite,
              onToggleFavorite: widget.store.toggleFavorite,
              isLoading:
                  widget.store.isInitializing || widget.store.isLoadingProducts,
            ),
            CartPage(
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
            OrderHistoryPage(
              orders: orders,
              isLoading: widget.store.isLoadingOrders,
            ),
            ProfilePage(
              userEmail: widget.userEmail,
              totalOrders: orders.length,
              onLogout: widget.onLogout,
              onSendSupport: widget.store.submitSupportMessage,
              activeCoupons: widget.store.activeCoupons,
              isLoading: widget.store.isInitializing,
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              ThemeModeMenu(
                themeMode: widget.themeMode,
                onChanged: widget.onThemeModeChanged,
              ),
              const SizedBox(width: 4),
              if (_currentTabIndex != 1)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Badge(
                    isLabelVisible: widget.store.cartItemCount > 0,
                    label: Text('${widget.store.cartItemCount}'),
                    child: const Icon(Icons.shopping_cart_outlined),
                  ),
                ),
            ],
          ),
          drawer: isMobile
              ? Drawer(
                  child: SafeArea(
                    child: navList,
                  ),
                )
              : null,
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
