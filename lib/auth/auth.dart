import 'package:flutter/material.dart';

import '../admin/home.dart';
import '../client/home.dart';
import '../client/product_detail.dart';
import '../client/product_list.dart';
import '../store/grocery_store_state.dart';
import 'login.dart';
import 'register.dart';

enum _RoleTab { client, admin }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.store});

  final GroceryStoreState store;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegister = false;
  _RoleTab _roleTab = _RoleTab.client;
  bool _showPublicShop = true;

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        if (widget.store.isAuthenticated) {
          if (widget.store.isAdmin) {
            return AdminHome(store: widget.store, onLogout: _handleLogout);
          }
          return ClientHome(
            userEmail: widget.store.userEmail,
            store: widget.store,
            onLogout: _handleLogout,
          );
        }

        if (_roleTab == _RoleTab.client && _showPublicShop) {
          final products = widget.store.storefrontProducts;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Shop'),
              actions: [
                TextButton(
                  onPressed: () => _showLoginView(register: false),
                  child: const Text('Login'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                Container(
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
                Expanded(
                  child: ProductListPage(
                    products: products,
                    cartQuantityForProduct: (_) => 0,
                    onOpenProduct: (productId) async {
                      final product = widget.store.getProductById(productId);
                      if (product == null) {
                        return;
                      }
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProductDetailPage(
                            product: product,
                            cartQuantity: 0,
                            onAddToCart: () {
                              Navigator.of(context).pop();
                              _showLoginView(register: false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Login to add items to cart.'),
                                ),
                              );
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
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<_RoleTab>(
                            segments: const [
                              ButtonSegment<_RoleTab>(
                                value: _RoleTab.client,
                                icon: Icon(Icons.person),
                                label: Text('Client'),
                              ),
                              ButtonSegment<_RoleTab>(
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
                            duration: const Duration(milliseconds: 250),
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
  final _emailController = TextEditingController(text: 'admin@grocery.com');
  final _passwordController = TextEditingController(text: 'admin123');

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
