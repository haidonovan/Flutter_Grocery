import 'package:flutter/material.dart';

import '../store/grocery_store_state.dart';
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
  });

  final String userEmail;
  final GroceryStoreState store;
  final VoidCallback onLogout;

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int _currentTabIndex = 0;

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

    final result = widget.store.placeOrder(
      customerEmail: widget.userEmail,
      shippingAddress: request.shippingAddress,
      paymentMethod: request.paymentMethod,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Order placed successfully.')),
    );

    if (result.success) {
      setState(() {
        _currentTabIndex = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final orders = widget.store.ordersForUser(widget.userEmail);
        final cartItems = widget.store.cartItems;
        final products = widget.store.storefrontProducts;

        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
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
          body: IndexedStack(
            index: _currentTabIndex,
            children: [
              ProductListPage(
                products: products,
                cartQuantityForProduct: widget.store.cartQuantityForProduct,
                onOpenProduct: _openProductDetail,
                onAddToCart: _addToCart,
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
              OrderHistoryPage(orders: orders),
              ProfilePage(
                userEmail: widget.userEmail,
                totalOrders: orders.length,
                onLogout: widget.onLogout,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront),
                label: 'Shop',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_cart),
                label: 'Cart',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ],
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
