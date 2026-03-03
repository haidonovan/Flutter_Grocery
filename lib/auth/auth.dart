import 'package:flutter/material.dart';

import '../admin/home.dart';
import '../client/home.dart';
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
  String? _activeUserEmail;
  bool _isAdminSession = false;
  _RoleTab _roleTab = _RoleTab.client;

  void _handleClientLogin(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return;
    }
    setState(() {
      _activeUserEmail = email;
      _isAdminSession = false;
    });
  }

  void _handleRegister(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      return;
    }
    setState(() {
      _activeUserEmail = email;
      _isAdminSession = false;
      _showRegister = false;
    });
  }

  void _handleAdminLogin(String email, String password) {
    if (email.trim().toLowerCase() == 'admin@grocery.com' &&
        password == 'admin123') {
      setState(() {
        _activeUserEmail = email.trim();
        _isAdminSession = true;
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invalid admin credentials. Use admin@grocery.com / admin123',
        ),
      ),
    );
  }

  void _handleLogout() {
    setState(() {
      _activeUserEmail = null;
      _isAdminSession = false;
      _showRegister = false;
      _roleTab = _RoleTab.client;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeUserEmail != null) {
      if (_isAdminSession) {
        return AdminHome(store: widget.store, onLogout: _handleLogout);
      }
      return ClientHome(
        userEmail: _activeUserEmail!,
        store: widget.store,
        onLogout: _handleLogout,
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
                          });
                        },
                      ),
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
