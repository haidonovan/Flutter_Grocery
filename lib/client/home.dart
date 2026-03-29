import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../store/grocery_store_state.dart';
import '../main.dart';
import '../widgets/app_page_route.dart';
import '../widgets/animated_nav_items.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/location_view_page.dart';
import '../widgets/theme_mode_menu.dart';
import '../widgets/coupon_banner.dart';
import 'cart.dart';
import 'checkout.dart';
import 'favorites.dart';
import 'models.dart';
import 'order_history.dart';
import 'payment_screen.dart';
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
    required this.onThemeTriggerOrigin,
  });

  final String userEmail;
  final GroceryStoreState store;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;
  final ValueChanged<Offset> onThemeTriggerOrigin;

  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  static const Duration _homeAutoRefreshInterval = Duration(seconds: 15);
  static const Duration _orderProcessingMessageInterval = Duration(
    milliseconds: 1350,
  );
  static const Duration _orderProcessingExitDelay = Duration(milliseconds: 820);
  static const List<_OrderProcessingStep> _orderProcessingSteps = [
    _OrderProcessingStep(
      headline: 'Preparing your order',
      message:
          'We are reviewing your cart, coupon, and delivery details before sending everything.',
    ),
    _OrderProcessingStep(
      headline: 'Reaching the server',
      message:
          'Your phone is connecting to the store server and sending the order request now.',
    ),
    _OrderProcessingStep(
      headline: 'Waiting for confirmation',
      message:
          'The server is checking stock, totals, and payment information for this order.',
    ),
    _OrderProcessingStep(
      headline: 'Finishing things up',
      message:
          'We are getting the confirmation ready so your signature and invoice can open next.',
    ),
  ];
  static const _orderProcessingSuccessStep = _OrderProcessingStep(
    headline: 'Order confirmed',
    message: 'Your receipt is ready. Opening the confirmation view now.',
    icon: Icons.check_circle_rounded,
    isTerminal: true,
  );
  static const _orderProcessingFailureStep = _OrderProcessingStep(
    headline: 'Order could not be completed',
    message:
        'We could not finish the request this time. Closing this loader and showing the error.',
    icon: Icons.error_outline_rounded,
    isTerminal: true,
  );

  int _currentTabIndex = 0;
  int _profileMotionEpoch = 0;
  bool _couponPrompted = false;
  bool _isManualRefreshing = false;
  Timer? _homeAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _homeAutoRefreshTimer = Timer.periodic(
      _homeAutoRefreshInterval,
      (_) => _maybeAutoRefreshStorefront(),
    );
  }

  @override
  void didUpdateWidget(covariant ClientHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      _homeAutoRefreshTimer?.cancel();
      _homeAutoRefreshTimer = Timer.periodic(
        _homeAutoRefreshInterval,
        (_) => _maybeAutoRefreshStorefront(),
      );
    }
  }

  @override
  void dispose() {
    _homeAutoRefreshTimer?.cancel();
    super.dispose();
  }

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

  void _selectTab(int index) {
    setState(() {
      _currentTabIndex = index;
      if (index == 4) {
        _profileMotionEpoch += 1;
      }
    });
  }

  void _maybeAutoRefreshStorefront() {
    if (!mounted || _currentTabIndex != 0) {
      return;
    }
    widget.store.retryStorefrontIfStale(retryAfter: _homeAutoRefreshInterval);
  }

  Future<void> _refreshCurrentData() async {
    if (_isManualRefreshing) {
      return;
    }

    setState(() {
      _isManualRefreshing = true;
    });

    try {
      await widget.store.refreshAll();
    } finally {
      if (mounted) {
        setState(() {
          _isManualRefreshing = false;
        });
      }
    }
  }

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
                  return AnimatedNavTile(
                    icon: item.icon,
                    label: item.label,
                    selected: _currentTabIndex == index,
                    onTap: () {
                      _selectTab(index);
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
              child: AnimatedNavTile(
                icon: profileItem.icon,
                label: profileItem.label,
                selected: _currentTabIndex == _navItems.length - 1,
                onTap: () {
                  _selectTab(_navItems.length - 1);
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

  Widget _buildDesktopNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: _navItems
              .asMap()
              .entries
              .map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedNavPillButton(
                      icon: item.icon,
                      label: item.label,
                      selected: _currentTabIndex == index,
                      onTap: () => _selectTab(index),
                    ),
                  ),
                );
              })
              .toList(growable: false),
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

  Future<void> _showPurchaseSignature() async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlayFuture = showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Purchase Signature',
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 680),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _PurchaseSignatureOverlay();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 1320), () {
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }
    });

    await overlayFuture;
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

  Future<void> _openOrderLocation(OrderRecord order) async {
    if (!order.hasShippingLocation) {
      return;
    }

    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => OrderLocationViewPage(
          latitude: order.shippingLatitude!,
          longitude: order.shippingLongitude!,
          address: order.shippingAddress,
          placeLabel: order.shippingPlaceLabel,
        ),
      ),
    );
  }

  Future<void> _showInvoiceDialog(OrderRecord order) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtotal = order.lines.fold<double>(
      0,
      (sum, line) => sum + line.subtotal,
    );

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
                                    color: scheme.primaryContainer.withValues(
                                      alpha: 0.7,
                                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order placed',
                                        style: theme.textTheme.headlineSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Invoice ${order.id}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
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
                                color: scheme.surfaceContainerHighest
                                    .withValues(alpha: 0.55),
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
                                  if (order.hasShippingLocation) ...[
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openOrderLocation(order),
                                      icon: const Icon(Icons.map_outlined),
                                      label: const Text('View location'),
                                    ),
                                  ],
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
                                    delay: Duration(
                                      milliseconds: 220 + (index * 35),
                                    ),
                                    duration: const Duration(milliseconds: 420),
                                    beginOffset: const Offset(0, -0.018),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  line.productName,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Qty ${line.quantity} | ${line.discountPercent > 0 ? '${line.discountPercent.toStringAsFixed(0)}% off' : 'Regular price'}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
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
                            delay: Duration(
                              milliseconds: 240 + (order.lines.length * 35),
                            ),
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
                                if (order.couponCode != null &&
                                    order.couponDiscount != null)
                                  _InvoiceAmountRow(
                                    label: 'Coupon ${order.couponCode}',
                                    value:
                                        '-\$${order.couponDiscount!.toStringAsFixed(2)}',
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
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                    ),
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

  Future<void> _openCheckout(List<CartViewItem> selectedItems) async {
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one product before checkout.'),
        ),
      );
      return;
    }

    final selectedTotal = widget.store.cartTotalFor(selectedItems);
    final selectedItemCount = widget.store.cartItemCountFor(selectedItems);
    final selectedLines = widget.store.checkoutLinesFor(selectedItems);
    final selectedProductIds = selectedItems
        .map((item) => item.productId)
        .toSet()
        .toList(growable: false);

    final request = await Navigator.of(context).push<CheckoutRequest>(
      AppPageRoute<CheckoutRequest>(
        builder: (_) => CheckoutPage(
          apiBaseUrl: widget.store.apiBaseUrl,
          totalAmount: selectedTotal,
          itemCount: selectedItemCount,
          userFirstname: widget.store.userFirstName,
          userLastname: widget.store.userLastName,
          userEmail: widget.store.userEmail,
        ),
      ),
    );

    if (!mounted || request == null) {
      return;
    }

    if (request.paymentMethod == 'ABA Pay') {
      final authToken = widget.store.authToken;
      if (authToken == null || authToken.isEmpty) {
        await _showAnimatedNoticeDialog(
          title: 'Login required',
          message: 'Please log in again before starting an ABA payment.',
          icon: Icons.lock_outline_rounded,
          isError: true,
        );
        return;
      }

      final paymentResult = await Navigator.of(context).push<PaymentResult>(
        AppPageRoute<PaymentResult>(
          builder: (_) => PaymentScreen(
            apiBaseUrl: widget.store.apiBaseUrl,
            authToken: authToken,
            amount: selectedTotal,
            currency: 'USD',
            shippingAddress: request.shippingAddress,
            lines: selectedLines,
            couponCode: request.couponCode,
            shippingLatitude: request.shippingLatitude,
            shippingLongitude: request.shippingLongitude,
            shippingPlaceLabel: request.shippingPlaceLabel,
            firstName: widget.store.userFirstName,
            lastName: widget.store.userLastName,
            email: widget.store.userEmail,
            storeName: 'Flutter Grocery',
            onOrderCreated: () {
              widget.store.clearCartItemsByProductIds(selectedProductIds);
            },
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      if (paymentResult?.orderId != null) {
        await widget.store.refreshAll();
      }

      if (!mounted) {
        return;
      }

      if (paymentResult?.success != true) {
        final pendingOrderNotice =
            paymentResult?.orderId != null &&
            paymentResult?.message == 'Payment cancelled';
        await _showAnimatedNoticeDialog(
          title: pendingOrderNotice
              ? 'Payment still pending'
              : 'Payment not completed',
          message: pendingOrderNotice
              ? 'The order was created, but ABA payment was not completed. You can review it in Order history.'
              : paymentResult?.message ?? 'Payment was not completed.',
          icon: pendingOrderNotice
              ? Icons.access_time_rounded
              : Icons.error_outline_rounded,
          isError: !pendingOrderNotice,
        );
        return;
      }

      _selectTab(3);

      final order = paymentResult?.orderId != null
          ? widget.store.getOrderById(paymentResult!.orderId!)
          : null;
      if (order != null) {
        await _showPurchaseSignature();
        if (!mounted) {
          return;
        }
        await _showInvoiceDialog(order);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed successfully.')),
        );
      }
      return;
    }

    final processingStep = ValueNotifier<_OrderProcessingStep>(
      _orderProcessingSteps.first,
    );
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final overlayFuture = _showOrderProcessingOverlay(
      stepListenable: processingStep,
      paymentMethod: request.paymentMethod,
    );
    var currentStepIndex = 0;
    final processingTimer = Timer.periodic(_orderProcessingMessageInterval, (
      _,
    ) {
      currentStepIndex = math.min(
        currentStepIndex + 1,
        _orderProcessingSteps.length - 1,
      );
      processingStep.value = _orderProcessingSteps[currentStepIndex];
    });

    PlaceOrderResult result;
    try {
      result = await widget.store.placeOrder(
        checkoutItems: selectedItems,
        shippingAddress: request.shippingAddress,
        paymentMethod: request.paymentMethod,
        couponCode: request.couponCode,
        shippingLatitude: request.shippingLatitude,
        shippingLongitude: request.shippingLongitude,
        shippingPlaceLabel: request.shippingPlaceLabel,
      );
    } catch (_) {
      result = const PlaceOrderResult(
        success: false,
        message: 'We could not reach the server to finish the order.',
      );
    } finally {
      processingTimer.cancel();
    }

    processingStep.value = result.success
        ? _orderProcessingSuccessStep
        : _orderProcessingFailureStep;
    await Future<void>.delayed(_orderProcessingExitDelay);
    if (rootNavigator.mounted && rootNavigator.canPop()) {
      rootNavigator.pop();
    }
    await overlayFuture;
    processingStep.dispose();

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

    _selectTab(3);

    final order = result.order;
    if (order != null) {
      await _showPurchaseSignature();
      if (!mounted) {
        return;
      }
      await _showInvoiceDialog(order);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Order placed successfully.')),
      );
    }
  }

  Future<void> _showOrderProcessingOverlay({
    required ValueNotifier<_OrderProcessingStep> stepListenable,
    required String paymentMethod,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Processing order',
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
                        child: ValueListenableBuilder<_OrderProcessingStep>(
                          valueListenable: stepListenable,
                          builder: (context, step, _) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer.withValues(
                                      alpha: 0.78,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Icon(
                                    step.isTerminal
                                        ? step.icon
                                        : Icons.receipt_long_rounded,
                                    color: step.isTerminal
                                        ? (step.icon ==
                                                  Icons.error_outline_rounded
                                              ? scheme.error
                                              : scheme.primary)
                                        : scheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Processing your order',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeInOutCubic,
                                  switchOutCurve: Curves.easeInOutCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.08),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    step.headline,
                                    key: ValueKey(step.headline),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 320),
                                  switchInCurve: Curves.easeInOutCubic,
                                  switchOutCurve: Curves.easeInOutCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    step.message,
                                    key: ValueKey(step.message),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 360),
                                  switchInCurve: Curves.easeInOutCubic,
                                  switchOutCurve: Curves.easeInOutCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.92,
                                          end: 1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: step.isTerminal
                                      ? Icon(
                                          step.icon,
                                          key: ValueKey(step.icon),
                                          size: 40,
                                          color:
                                              step.icon ==
                                                  Icons.error_outline_rounded
                                              ? scheme.error
                                              : scheme.primary,
                                        )
                                      : SizedBox(
                                          key: const ValueKey('loader'),
                                          width: 38,
                                          height: 38,
                                          child:
                                              CircularProgressIndicator.adaptive(
                                                strokeWidth: 3.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(scheme.primary),
                                              ),
                                        ),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment method',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        paymentMethod,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
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
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
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
                onRefresh: _refreshCurrentData,
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
              key: ValueKey('profile-shell-$_profileMotionEpoch'),
              active: _currentTabIndex == 4,
              child: ProfilePage(
                key: ValueKey('profile-page-$_profileMotionEpoch'),
                userDisplayName: widget.store.userDisplayName,
                userEmail: widget.userEmail,
                profileImageUrl: widget.store.userProfileImageUrl,
                totalOrders: orders.length,
                onLogout: widget.onLogout,
                onUploadProfileImage: widget.store.uploadProfileImage,
                onSendSupport: widget.store.submitSupportTicket,
                onReplySupport: widget.store.sendSupportThreadMessage,
                onCloseSupport: widget.store.closeSupportTicket,
                activeCoupons: widget.store.activeCoupons,
                supportTickets: widget.store.mySupportTickets,
                isLoading: widget.store.isInitializing,
                motionEpoch: _profileMotionEpoch,
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
                onTriggerOrigin: widget.onThemeTriggerOrigin,
              ),
              IconButton(
                onPressed: _isManualRefreshing ? null : _refreshCurrentData,
                tooltip: 'Refresh',
                icon: _isManualRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              if (_currentTabIndex != 2)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: IconButton(
                    onPressed: () {
                      _selectTab(2);
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
              : _buildDesktopNavigationBar(context),
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

class _OrderProcessingStep {
  const _OrderProcessingStep({
    required this.headline,
    required this.message,
    this.icon = Icons.hourglass_top_rounded,
    this.isTerminal = false,
  });

  final String headline;
  final String message;
  final IconData icon;
  final bool isTerminal;
}

class _PurchaseSignatureOverlay extends StatelessWidget {
  const _PurchaseSignatureOverlay();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const signatureColor = Color(0xFFE2B24B);
    const signatureGlow = Color(0xFFFFE1A0);

    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1120),
        curve: Curves.easeInOutCubic,
        builder: (context, value, child) {
          final reveal = Curves.easeOutQuart.transform(value.clamp(0.0, 1.0));
          final settle = Curves.easeInOutCubic.transform(value.clamp(0.0, 1.0));
          final blur = 3 + (7 * settle);
          final penTravel = Curves.easeOutExpo.transform(
            (value * 1.04).clamp(0.0, 1.0),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.16 + (0.42 * settle)),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, 28 * (1 - settle)),
                  child: Opacity(
                    opacity: settle,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final width = (maxWidth * 0.82).clamp(300.0, 1100.0);
                        final fontSize = (width * 0.28).clamp(82.0, 220.0);
                        final leftInset = (fontSize * 0.14).clamp(12.0, 28.0);
                        final rightInset = (fontSize * 0.26).clamp(24.0, 46.0);
                        final drawingWidth = width - leftInset - rightInset;
                        final baselineWave =
                            math.sin(penTravel * math.pi * 1.95) *
                            (fontSize * 0.045);
                        final penX = leftInset + (drawingWidth * penTravel);
                        final penY = -(fontSize * 0.06) + baselineWave;

                        return SizedBox(
                          width: width,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: fontSize * 1.34,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: leftInset,
                                          right: rightInset,
                                        ),
                                        child: Text(
                                          'Signature',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.greatVibes(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.w400,
                                            color: signatureColor.withValues(
                                              alpha: 0.16,
                                            ),
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          left: leftInset,
                                          right: rightInset,
                                        ),
                                        child: ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (bounds) {
                                            final visibleWidth =
                                                bounds.width * reveal;
                                            return LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [
                                                signatureColor,
                                                signatureGlow,
                                                signatureColor,
                                                signatureColor.withValues(
                                                  alpha: 0.0,
                                                ),
                                              ],
                                              stops: [
                                                0,
                                                (visibleWidth / bounds.width)
                                                        .clamp(0.0, 1.0) *
                                                    0.62,
                                                (visibleWidth / bounds.width)
                                                    .clamp(0.0, 1.0),
                                                ((visibleWidth + 18) /
                                                        bounds.width)
                                                    .clamp(0.0, 1.0),
                                              ],
                                            ).createShader(bounds);
                                          },
                                          child: ClipRect(
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: reveal,
                                              child: Text(
                                                'Signature',
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.greatVibes(
                                                  fontSize: fontSize,
                                                  fontWeight: FontWeight.w400,
                                                  color: signatureColor,
                                                  letterSpacing: 0.2,
                                                  shadows: [
                                                    Shadow(
                                                      color: signatureGlow
                                                          .withValues(
                                                            alpha: 0.48,
                                                          ),
                                                      blurRadius: 20,
                                                      offset: const Offset(
                                                        0,
                                                        0,
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
                                    Positioned(
                                      left: penX,
                                      top: (fontSize * 0.58) + penY,
                                      child: Opacity(
                                        opacity: (reveal - 0.06).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: signatureGlow,
                                            boxShadow: [
                                              BoxShadow(
                                                color: signatureGlow.withValues(
                                                  alpha: 0.9,
                                                ),
                                                blurRadius: 22,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: signatureColor
                                                    .withValues(alpha: 0.52),
                                                blurRadius: 34,
                                                spreadRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: width * 0.6 * reveal,
                                height: 2.2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: [
                                      signatureColor.withValues(alpha: 0),
                                      signatureGlow,
                                      signatureColor.withValues(alpha: 0),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: signatureGlow.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Opacity(
                                opacity: (settle - 0.2).clamp(0.0, 1.0),
                                child: Text(
                                  'Purchase confirmed',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
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
            child: Text(label, style: textStyle?.copyWith(color: color)),
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
