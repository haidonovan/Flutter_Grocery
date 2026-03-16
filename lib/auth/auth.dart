import 'package:flutter/material.dart';

import '../admin/home.dart';
import '../client/home.dart';
import '../client/product_detail.dart';
import '../client/product_list.dart';
import '../main.dart';
import '../store/grocery_store_state.dart';
import '../widgets/app_page_route.dart';
import '../widgets/entrance_motion.dart';
import '../widgets/theme_mode_menu.dart';
import 'login.dart';
import 'register.dart';

enum _RoleTab { client, admin }

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.store,
    required this.themeMode,
    required this.themeStyle,
    required this.onThemeModeChanged,
    required this.onThemeStyleChanged,
    required this.onThemeTriggerOrigin,
  });

  final GroceryStoreState store;
  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;
  final ValueChanged<Offset> onThemeTriggerOrigin;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegister = false;
  _RoleTab _roleTab = _RoleTab.client;
  bool _showPublicShop = true;
  static const bool _showAdminTab = bool.fromEnvironment(
    'SHOW_ADMIN',
    defaultValue: true,
  );

  @override
  void initState() {
    super.initState();
    if (!_showAdminTab) {
      _roleTab = _RoleTab.client;
    }
  }

  Future<void> _handleClientLogin(String email, String password) async {
    final result = await widget.store.login(
      email: email,
      password: password,
      requireAdmin: false,
    );

    if (!mounted || result.success) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message ?? 'Login failed.')));
  }

  Future<void> _handleRegister(String email, String password) async {
    final result = await widget.store.register(
      email: email,
      password: password,
    );

    if (!mounted || result.success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Register failed.')),
    );
  }

  Future<void> _handleAdminLogin(String email, String password) async {
    final result = await widget.store.login(
      email: email,
      password: password,
      requireAdmin: true,
    );

    if (!mounted || result.success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'Admin login failed.')),
    );
  }

  void _handleLogout() {
    widget.store.logout();
    setState(() {
      _showRegister = false;
      _roleTab = _RoleTab.client;
      _showPublicShop = true;
    });
  }

  void _showLoginView({bool register = false}) {
    setState(() {
      _roleTab = _RoleTab.client;
      _showRegister = register;
      _showPublicShop = false;
    });
  }

  Widget _buildAuthTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.03, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        Widget child;
        String childKey;

        if (widget.store.isAuthenticated) {
          if (widget.store.isAdmin) {
            child = AdminHome(
              store: widget.store,
              onLogout: _handleLogout,
              themeMode: widget.themeMode,
              themeStyle: widget.themeStyle,
              onThemeModeChanged: widget.onThemeModeChanged,
              onThemeStyleChanged: widget.onThemeStyleChanged,
              onThemeTriggerOrigin: widget.onThemeTriggerOrigin,
            );
            childKey = 'admin-home';
          } else {
            child = ClientHome(
              userEmail: widget.store.userEmail,
              store: widget.store,
              onLogout: _handleLogout,
              themeMode: widget.themeMode,
              themeStyle: widget.themeStyle,
              onThemeModeChanged: widget.onThemeModeChanged,
              onThemeStyleChanged: widget.onThemeStyleChanged,
              onThemeTriggerOrigin: widget.onThemeTriggerOrigin,
            );
            childKey = 'client-home';
          }
        } else if (_roleTab == _RoleTab.client && _showPublicShop) {
          final products = widget.store.storefrontProducts;
          child = Scaffold(
            appBar: AppBar(
              title: const Text('Shop'),
              actions: [
                ThemeModeMenu(
                  themeMode: widget.themeMode,
                  themeStyle: widget.themeStyle,
                  onChanged: widget.onThemeModeChanged,
                  onStyleChanged: widget.onThemeStyleChanged,
                  onTriggerOrigin: widget.onThemeTriggerOrigin,
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _showLoginView(register: false),
                  child: const Text('Login'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                EntranceMotion(
                  delay: const Duration(milliseconds: 80),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.teal.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Browse products freely. Login to add items and checkout.',
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showLoginView(register: true),
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: EntranceMotion(
                    delay: const Duration(milliseconds: 160),
                    child: ProductListPage(
                      products: products,
                      cartQuantityForProduct: (_) => 0,
                      onOpenProduct: (productId) async {
                        final product = widget.store.getProductById(productId);
                        if (product == null) {
                          return;
                        }
                        await Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => ProductDetailPage(
                              product: product,
                              cartQuantity: 0,
                              onAddToCart: () {
                                Navigator.of(context).pop();
                                _showLoginView(register: false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Login to add items to cart.',
                                    ),
                                  ),
                                );
                              },
                              store: widget.store,
                              onRequireLogin: () {
                                _showLoginView(register: false);
                              },
                            ),
                          ),
                        );
                      },
                      onAddToCart: (_) {
                        _showLoginView(register: false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Login to add items to cart.'),
                          ),
                        );
                      },
                      isFavorite: (_) => false,
                      onToggleFavorite: (_) async {
                        _showLoginView(register: false);
                      },
                      isLoading:
                          widget.store.isInitializing ||
                          widget.store.isLoadingProducts,
                    ),
                  ),
                ),
              ],
            ),
          );
          childKey = 'public-shop';
        } else {
          child = Scaffold(
            body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: EntranceMotion(
                    delay: const Duration(milliseconds: 80),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: ThemeModeMenu(
                                themeMode: widget.themeMode,
                                themeStyle: widget.themeStyle,
                                onChanged: widget.onThemeModeChanged,
                                onStyleChanged: widget.onThemeStyleChanged,
                                onTriggerOrigin: widget.onThemeTriggerOrigin,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<_RoleTab>(
                              segments: [
                                const ButtonSegment<_RoleTab>(
                                  value: _RoleTab.client,
                                  icon: Icon(Icons.person),
                                  label: Text('Client'),
                                ),
                                if (_showAdminTab)
                                  const ButtonSegment<_RoleTab>(
                                    value: _RoleTab.admin,
                                    icon: Icon(Icons.admin_panel_settings),
                                    label: Text('Admin'),
                                  ),
                              ],
                              selected: {_roleTab},
                              onSelectionChanged: (selected) {
                                setState(() {
                                  _roleTab = selected.first;
                                  _showRegister = false;
                                  _showPublicShop = _roleTab == _RoleTab.client;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            if (widget.store.isLoading)
                              const LinearProgressIndicator(),
                            if (widget.store.isLoading)
                              const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              reverseDuration: const Duration(milliseconds: 360),
                              switchInCurve: Curves.easeInOutCubic,
                              switchOutCurve: Curves.easeInOutCubic,
                              transitionBuilder: (child, animation) =>
                                  _buildAuthTransition(child, animation),
                              child: _roleTab == _RoleTab.admin
                                  ? _AdminLoginForm(
                                      key: const ValueKey('admin-login'),
                                      onLogin: _handleAdminLogin,
                                    )
                                  : _showRegister
                                  ? RegisterPage(
                                      key: const ValueKey('register'),
                                      onRegister: _handleRegister,
                                      onSwitchToLogin: () {
                                        setState(() {
                                          _showRegister = false;
                                        });
                                      },
                                    )
                                  : LoginPage(
                                      key: const ValueKey('login'),
                                      onLogin: _handleClientLogin,
                                      onSwitchToRegister: () {
                                        setState(() {
                                          _showRegister = true;
                                        });
                                      },
                                    ),
                            ),
                            if (_roleTab == _RoleTab.client)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showPublicShop = true;
                                  });
                                },
                                child: const Text(
                                  'Browse products without login',
                                ),
                              ),
                            if (widget.store.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  widget.store.errorMessage!,
                                  style: const TextStyle(color: Colors.red),
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
          ),
          );
          childKey = _roleTab == _RoleTab.admin
              ? 'admin-auth'
              : _showRegister
                  ? 'client-register'
                  : 'client-login';
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 480),
          reverseDuration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) =>
              _buildAuthTransition(child, animation),
          child: KeyedSubtree(
            key: ValueKey(childKey),
            child: child,
          ),
        );
      },
    );
  }
}

class _AdminLoginForm extends StatefulWidget {
  const _AdminLoginForm({super.key, required this.onLogin});

  final void Function(String email, String password) onLogin;

  @override
  State<_AdminLoginForm> createState() => _AdminLoginFormState();
}

class _AdminLoginFormState extends State<_AdminLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onLogin(_emailController.text.trim(), _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Admin login', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Manage product inventory, restocking, orders, and sales.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Admin email',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return 'Enter admin email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Enter password';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _submit, child: const Text('Login as admin')),
        ],
      ),
    );
  }
}
