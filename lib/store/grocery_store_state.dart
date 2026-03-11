import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../client/models.dart';

class CartViewItem {
  const CartViewItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
}

class PlaceOrderResult {
  const PlaceOrderResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class AuthResult {
  const AuthResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class GroceryStoreState extends ChangeNotifier {
  GroceryStoreState._(this._apiClient);

  static const String _tokenKey = 'api_token';
  static const String _userIdKey = 'api_user_id';
  static const String _userEmailKey = 'api_user_email';
  static const String _userRoleKey = 'api_user_role';

  static Future<GroceryStoreState> create({
    String baseUrl = 'http://localhost:4000',
  }) async {
    final client = ApiClient(baseUrl: baseUrl);
    final store = GroceryStoreState._(client);
    await store._restoreSession();
    await store.refreshAll();
    return store;
  }

  final ApiClient _apiClient;

  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  final List<OrderRecord> _orders = [];
  final List<RestockRecord> _restockHistory = [];

  bool _isLoading = false;
  String? _errorMessage;

  String? _token;
  int? _userId;
  String? _userEmail;
  String? _role;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  String get userEmail => _userEmail ?? '';
  int? get userId => _userId;

  List<Product> get allProducts => List.unmodifiable(_products);

  List<Product> get storefrontProducts =>
      _products.where((item) => item.isActive).toList(growable: false);

  List<OrderRecord> get allOrders => List.unmodifiable(_orders);

  List<RestockRecord> get restockHistory => List.unmodifiable(_restockHistory);

  List<CartViewItem> get cartItems {
    final result = <CartViewItem>[];
    for (final cart in _cart) {
      final product = getProductById(cart.productId);
      if (product != null && product.isActive) {
        result.add(CartViewItem(product: product, quantity: cart.quantity));
      }
    }
    return result;
  }

  int get cartItemCount =>
      _cart.fold<int>(0, (sum, item) => sum + item.quantity);

  double get cartTotal {
    var total = 0.0;
    for (final item in cartItems) {
      total += item.subtotal;
    }
    return total;
  }

  int get totalStockCount =>
      _products.fold<int>(0, (sum, item) => sum + item.stock);

  int get lowStockCount => _products.where((item) => item.stock <= 5).length;

  double get revenueTotal => _orders
      .where((order) => order.status != OrderStatus.cancelled)
      .fold<double>(0, (sum, order) => sum + order.total);

  double get cancelledValue => _orders
      .where((order) => order.status == OrderStatus.cancelled)
      .fold<double>(0, (sum, order) => sum + order.total);

  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((item) => item.id == productId);
    } catch (_) {
      return null;
    }
  }

  int cartQuantityForProduct(String productId) {
    for (final item in _cart) {
      if (item.productId == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  bool addToCart(String productId, {int quantity = 1}) {
    final product = getProductById(productId);
    if (product == null || !product.isActive || quantity <= 0) {
      return false;
    }

    final index = _cart.indexWhere((item) => item.productId == productId);
    if (index == -1) {
      if (quantity > product.stock) {
        return false;
      }
      _cart.add(CartItem(productId: productId, quantity: quantity));
      notifyListeners();
      return true;
    }

    final updatedQuantity = _cart[index].quantity + quantity;
    if (updatedQuantity > product.stock) {
      return false;
    }

    _cart[index].quantity = updatedQuantity;
    notifyListeners();
    return true;
  }

  bool increaseCartQuantity(String productId) {
    return addToCart(productId, quantity: 1);
  }

  void decreaseCartQuantity(String productId) {
    final index = _cart.indexWhere((item) => item.productId == productId);
    if (index == -1) {
      return;
    }
    if (_cart[index].quantity > 1) {
      _cart[index].quantity -= 1;
    } else {
      _cart.removeAt(index);
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    bool requireAdmin = false,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.postJson('/api/auth/login', {
        'email': email,
        'password': password,
      });

      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        return const AuthResult(
          success: false,
          message: 'Invalid login response.',
        );
      }

      final role = user['role']?.toString() ?? 'client';
      if (requireAdmin && role != 'admin') {
        return const AuthResult(
          success: false,
          message: 'Admin access required.',
        );
      }

      await _saveSession(
        token: token,
        userId: (user['id'] as num).toInt(),
        email: user['email']?.toString() ?? email,
        role: role,
      );

      await refreshAll();
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.postJson('/api/auth/register', {
        'email': email,
        'password': password,
      });

      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        return const AuthResult(
          success: false,
          message: 'Invalid register response.',
        );
      }

      await _saveSession(
        token: token,
        userId: (user['id'] as num).toInt(),
        email: user['email']?.toString() ?? email,
        role: user['role']?.toString() ?? 'client',
      );

      await refreshAll();
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userEmail = null;
    _role = null;
    _apiClient.token = null;
    _cart.clear();
    _products.clear();
    _orders.clear();
    _restockHistory.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);

    notifyListeners();
  }

  Future<void> refreshAll() async {
    if (!isAuthenticated) {
      await _loadProducts(includeInactive: false);
      return;
    }

    await _loadProducts(includeInactive: isAdmin);
    await _loadOrders();
    if (isAdmin) {
      await _loadRestocks();
    }
  }

  Future<void> _loadProducts({required bool includeInactive}) async {
    try {
      final response = await _apiClient.getJson(
        '/api/products',
        query: includeInactive ? {'active': 'false'} : null,
      );
      final data = response['data'] as List<dynamic>?;
      if (data != null) {
        _products
          ..clear()
          ..addAll(data.map(_productFromApi));
        notifyListeners();
      }
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to reach server.');
    }
  }

  Future<void> _loadOrders() async {
    if (!isAuthenticated) {
      _orders.clear();
      return;
    }

    try {
      final endpoint = isAdmin ? '/api/orders' : '/api/orders/me';
      final response = await _apiClient.getJson(endpoint);
      final data = response['data'] as List<dynamic>?;
      if (data == null) {
        return;
      }

      final orders = data.map(_orderFromApi).toList();
      for (final order in orders) {
        final lines = await _loadOrderLines(order.id);
        order.lines
          ..clear()
          ..addAll(lines);
      }

      _orders
        ..clear()
        ..addAll(orders);
      notifyListeners();
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to reach server.');
    }
  }

  Future<List<OrderLine>> _loadOrderLines(String orderId) async {
    try {
      final response = await _apiClient.getJson('/api/orders/$orderId/lines');
      final data = response['data'] as List<dynamic>?;
      if (data == null) {
        return [];
      }
      return data.map((line) {
        final map = line as Map<String, dynamic>;
        return OrderLine(
          productId: map['productId']?.toString() ?? '',
          productName: map['productName']?.toString() ?? '',
          quantity: (map['quantity'] as num?)?.toInt() ?? 0,
          unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRestocks() async {
    try {
      final response = await _apiClient.getJson('/api/restocks');
      final data = response['data'] as List<dynamic>?;
      if (data == null) {
        return;
      }
      _restockHistory
        ..clear()
        ..addAll(data.map(_restockFromApi));
      notifyListeners();
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to reach server.');
    }
  }

  Future<PlaceOrderResult> placeOrder({
    required String shippingAddress,
    required String paymentMethod,
  }) async {
    if (_cart.isEmpty) {
      return const PlaceOrderResult(success: false, message: 'Cart is empty.');
    }

    if (!isAuthenticated) {
      return const PlaceOrderResult(
        success: false,
        message: 'You must login to place an order.',
      );
    }

    final lines = _cart
        .map((item) => {'productId': item.productId, 'quantity': item.quantity})
        .toList(growable: false);

    _setLoading(true);
    try {
      await _apiClient.postJson('/api/orders', {
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'lines': lines,
      });

      _cart.clear();
      await refreshAll();
      return const PlaceOrderResult(
        success: true,
        message: 'Order placed successfully.',
      );
    } on ApiException catch (err) {
      return PlaceOrderResult(success: false, message: err.message);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) async {
    await _apiClient.postJson('/api/products', {
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'stock': stock,
      'imageUrl': imageUrl,
    });
    await refreshAll();
  }

  Future<void> updateProduct(Product updated) async {
    await _apiClient.putJson('/api/products/${updated.id}', {
      'name': updated.name,
      'category': updated.category,
      'description': updated.description,
      'price': updated.price,
      'imageUrl': updated.imageUrl,
      'stock': updated.stock,
      'isActive': updated.isActive,
    });
    await refreshAll();
  }

  Future<void> toggleProductStatus(String productId, bool isActive) async {
    final product = getProductById(productId);
    if (product == null) {
      return;
    }
    await updateProduct(product.copyWith(isActive: isActive));
  }

  Future<void> deleteProduct(String productId) async {
    await _apiClient.delete('/api/products/$productId');
    await refreshAll();
  }

  Future<void> restockProduct(String productId, int quantityAdded) async {
    if (quantityAdded <= 0) {
      return;
    }
    await _apiClient.postJson('/api/products/$productId/restock', {
      'quantity': quantityAdded,
    });
    await refreshAll();
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus nextStatus) async {
    await _apiClient.patchJson('/api/orders/$orderId/status', {
      'status': nextStatus.name,
    });
    await refreshAll();
  }

  Future<String?> uploadImage(XFile file) async {
    _setLoading(true);
    try {
      final response = await _apiClient.uploadImage('/api/uploads', file);
      final url = response['url']?.toString();
      if (url == null || url.isEmpty) {
        return null;
      }
      if (url.startsWith('http')) {
        return url;
      }
      return '${_apiClient.baseUrl}$url';
    } on ApiException catch (err) {
      _setError(err.message);
      return null;
    } catch (_) {
      _setError('Upload failed.');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Product _productFromApi(dynamic raw) {
    final data = raw as Map<String, dynamic>;
    return Product(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl']?.toString() ?? '',
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] == null ? true : data['isActive'] == true,
    );
  }

  OrderRecord _orderFromApi(dynamic raw) {
    final data = raw as Map<String, dynamic>;
    final statusName = data['status']?.toString() ?? 'pending';
    final status = OrderStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => OrderStatus.pending,
    );

    return OrderRecord(
      id: data['id']?.toString() ?? '',
      customerEmail: data['customerEmail']?.toString() ?? _userEmail ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      shippingAddress: data['shippingAddress']?.toString() ?? '',
      paymentMethod: data['paymentMethod']?.toString() ?? '',
      lines: [],
      total: (data['total'] as num?)?.toDouble() ?? 0,
      status: status,
    );
  }

  RestockRecord _restockFromApi(dynamic raw) {
    final data = raw as Map<String, dynamic>;
    return RestockRecord(
      productId: data['productId']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      quantityAdded: (data['quantityAdded'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getInt(_userIdKey);
    _userEmail = prefs.getString(_userEmailKey);
    _role = prefs.getString(_userRoleKey);
    _apiClient.token = _token;
  }

  Future<void> _saveSession({
    required String token,
    required int userId,
    required String email,
    required String role,
  }) async {
    _token = token;
    _userId = userId;
    _userEmail = email;
    _role = role;
    _apiClient.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_userRoleKey, role);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }
}
