import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../client/models.dart';

class CartViewItem {
  const CartViewItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.discountedPrice * quantity;
}

class PlaceOrderResult {
  const PlaceOrderResult({required this.success, this.message, this.order});

  final bool success;
  final String? message;
  final OrderRecord? order;
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
  static const String _userFirstNameKey = 'api_user_first_name';
  static const String _userLastNameKey = 'api_user_last_name';
  static const String _userProfileImageUrlKey = 'api_user_profile_image_url';
  static const String _userRoleKey = 'api_user_role';

  static Future<GroceryStoreState> create({
    String baseUrl = 'https://grocerystore-production-eea3.up.railway.app',
    String? fallbackBaseUrl,
  }) async {
    final client = ApiClient(
      baseUrl: baseUrl,
      fallbackBaseUrl: fallbackBaseUrl,
    );
    final store = GroceryStoreState._(client);
    await store._restoreSession();
    await store._validateRestoredSession();
    await store.refreshAll();
    store._isInitializing = false;
    store.notifyListeners();
    return store;
  }

  final ApiClient _apiClient;

  final List<Product> _products = [];
  final List<String> _categories = [];
  final List<CartItem> _cart = [];
  final List<OrderRecord> _orders = [];
  final List<RestockRecord> _restockHistory = [];
  final List<Coupon> _coupons = [];
  final List<Coupon> _activeCoupons = [];
  final List<SupportTicket> _supportTickets = [];
  final List<SupportTicket> _mySupportTickets = [];
  final Set<String> _favoriteProductIds = {};
  final Map<String, List<ProductComment>> _commentsByProduct = {};

  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isLoadingProducts = false;
  bool _isLoadingOrders = false;
  bool _isLoadingCategories = false;
  bool _hasReceivedProductsResponse = false;
  DateTime? _lastProductsLoadAttemptAt;
  String? _errorMessage;

  String? _token;
  int? _userId;
  String? _userEmail;
  String? _userFirstName;
  String? _userLastName;
  String? _userProfileImageUrl;
  String? _role;

  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isLoadingOrders => _isLoadingOrders;
  bool get isLoadingCategories => _isLoadingCategories;
  String? get errorMessage => _errorMessage;
  String get apiBaseUrl => _apiClient.baseUrl;

  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _role == 'admin';
  String get userEmail => _userEmail ?? '';
  String get userFirstName => _userFirstName?.trim() ?? '';
  String get userLastName => _userLastName?.trim() ?? '';
  String? get userProfileImageUrl => _userProfileImageUrl;
  String get userDisplayName {
    final parts = [userFirstName, userLastName]
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    if (userEmail.isNotEmpty) {
      return userEmail;
    }
    return 'Client';
  }
  int? get userId => _userId;

  List<Product> get allProducts => List.unmodifiable(_products);
  List<String> get categories => List.unmodifiable(_categories);

  List<Product> get storefrontProducts =>
      _products.where((item) => item.isActive).toList(growable: false);

  List<OrderRecord> get allOrders => List.unmodifiable(_orders);

  List<RestockRecord> get restockHistory => List.unmodifiable(_restockHistory);
  List<Coupon> get coupons => List.unmodifiable(_coupons);
  List<Coupon> get activeCoupons => List.unmodifiable(_activeCoupons);
  List<SupportTicket> get supportTickets => List.unmodifiable(_supportTickets);
  List<SupportTicket> get mySupportTickets =>
      List.unmodifiable(_mySupportTickets);
  bool isFavorite(String productId) => _favoriteProductIds.contains(productId);
  List<ProductComment> commentsFor(String productId) =>
      List.unmodifiable(_commentsByProduct[productId] ?? []);

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
        firstName: user['firstName']?.toString(),
        lastName: user['lastName']?.toString(),
        profileImageUrl: user['profileImageUrl']?.toString(),
        role: role,
      );

      await refreshAll();
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return AuthResult(
        success: false,
        message: 'Unable to reach server at ${_apiClient.baseUrl}.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.postJson('/api/auth/register', {
        'firstName': firstName,
        'lastName': lastName,
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
        firstName: user['firstName']?.toString(),
        lastName: user['lastName']?.toString(),
        profileImageUrl: user['profileImageUrl']?.toString(),
        role: user['role']?.toString() ?? 'client',
      );

      await refreshAll();
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return AuthResult(
        success: false,
        message: 'Unable to reach server at ${_apiClient.baseUrl}.',
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _resetSession();
    await refreshStorefront();
    notifyListeners();
  }

  Future<void> _resetSession() async {
    _token = null;
    _userId = null;
    _userEmail = null;
    _userFirstName = null;
    _userLastName = null;
    _userProfileImageUrl = null;
    _role = null;
    _apiClient.token = null;
    _cart.clear();
    _orders.clear();
    _restockHistory.clear();
    _coupons.clear();
    _activeCoupons.clear();
    _supportTickets.clear();
    _mySupportTickets.clear();
    _favoriteProductIds.clear();
    _commentsByProduct.clear();
    _hasReceivedProductsResponse = false;
    _lastProductsLoadAttemptAt = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userFirstNameKey);
    await prefs.remove(_userLastNameKey);
    await prefs.remove(_userProfileImageUrlKey);
    await prefs.remove(_userRoleKey);
  }

  Future<void> refreshAll() async {
    if (!isAuthenticated) {
      _orders.clear();
      _restockHistory.clear();
      _coupons.clear();
      _activeCoupons.clear();
      _supportTickets.clear();
      _mySupportTickets.clear();
      _favoriteProductIds.clear();
      await _loadProducts(includeInactive: false);
      await _loadCategories();
      return;
    }

    await _loadProducts(includeInactive: isAdmin);
    await _loadCategories();
    await _loadOrders();
    if (isAdmin) {
      await _loadRestocks();
      await _loadCoupons();
      await _loadSupportTickets();
    } else {
      await _loadFavorites();
      await _loadActiveCoupons();
      await _loadMySupportTickets();
    }
  }

  Future<void> refreshStorefront() async {
    await _loadProducts(includeInactive: isAuthenticated && isAdmin);
    await _loadCategories();
  }

  Future<void> retryStorefrontIfStale({
    Duration retryAfter = const Duration(seconds: 15),
  }) async {
    if (_isInitializing || _isLoadingProducts || _isLoadingCategories) {
      return;
    }
    if (_hasReceivedProductsResponse) {
      return;
    }

    final lastAttempt = _lastProductsLoadAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < retryAfter) {
      return;
    }

    await refreshStorefront();
  }

  Future<void> _loadProducts({required bool includeInactive}) async {
    _lastProductsLoadAttemptAt = DateTime.now();
    _isLoadingProducts = true;
    notifyListeners();
    try {
      final response = await _apiClient.getJson(
        '/api/products',
        query: includeInactive ? {'active': 'false'} : null,
      );
      final data = response['data'] as List<dynamic>?;
      if (data != null) {
        _hasReceivedProductsResponse = true;
        _errorMessage = null;
        _products
          ..clear()
          ..addAll(data.map(_productFromApi));
        notifyListeners();
      }
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to reach server at ${_apiClient.baseUrl}.');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> _loadOrders() async {
    if (!isAuthenticated) {
      _orders.clear();
      return;
    }

    _isLoadingOrders = true;
    notifyListeners();
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
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
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
          discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
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

  Future<void> _loadCoupons() async {
    try {
      final response = await _apiClient.getJson('/api/coupons');
      final data = response['data'] as List<dynamic>? ?? [];
      _coupons
        ..clear()
        ..addAll(
          data.map((raw) {
            final map = raw as Map<String, dynamic>;
            return Coupon(
              id: (map['id'] as num?)?.toInt() ?? 0,
              code: map['code']?.toString() ?? '',
              type: map['type']?.toString() ?? 'percent',
              value: (map['value'] as num?)?.toDouble() ?? 0,
              isActive: map['isActive'] == true,
              description: map['description']?.toString(),
              startsAt: DateTime.tryParse(map['startsAt']?.toString() ?? ''),
              endsAt: DateTime.tryParse(map['endsAt']?.toString() ?? ''),
              audience: map['audience']?.toString(),
              userEmail: map['userEmail']?.toString(),
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // ignore coupon load failures for now
    }
  }

  Future<void> _loadActiveCoupons() async {
    try {
      final response = await _apiClient.getJson('/api/coupons/active');
      final data = response['data'] as List<dynamic>? ?? [];
      _activeCoupons
        ..clear()
        ..addAll(
          data.map((raw) {
            final map = raw as Map<String, dynamic>;
            return Coupon(
              id: (map['id'] as num?)?.toInt() ?? 0,
              code: map['code']?.toString() ?? '',
              type: map['type']?.toString() ?? 'percent',
              value: (map['value'] as num?)?.toDouble() ?? 0,
              isActive: map['isActive'] == true,
              description: map['description']?.toString(),
              startsAt: DateTime.tryParse(map['startsAt']?.toString() ?? ''),
              endsAt: DateTime.tryParse(map['endsAt']?.toString() ?? ''),
              audience: map['audience']?.toString(),
              userEmail: map['userEmail']?.toString(),
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // ignore active coupons load failures
    }
  }

  Future<void> _loadCategories() async {
    _isLoadingCategories = true;
    notifyListeners();
    try {
      final response = await _apiClient.getJson('/api/categories');
      final data = response['data'] as List<dynamic>? ?? [];
      _categories
        ..clear()
        ..addAll(
          data
              .map((value) => value?.toString() ?? '')
              .where((value) => value.isNotEmpty),
        );
      notifyListeners();
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to reach server.');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final response = await _apiClient.getJson('/api/favorites');
      final data = response['data'] as List<dynamic>? ?? [];
      _favoriteProductIds
        ..clear()
        ..addAll(data.map((value) => value.toString()));
      notifyListeners();
    } catch (_) {
      // ignore favorites load failures
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final response = await _apiClient.postJson('/api/favorites/$productId', {});
    final isFavorite = response['isFavorite'] == true;
    if (isFavorite) {
      _favoriteProductIds.add(productId);
    } else {
      _favoriteProductIds.remove(productId);
    }
    notifyListeners();
  }

  Future<void> submitRating(String productId, int rating) async {
    final response = await _apiClient.postJson('/api/ratings/$productId', {
      'rating': rating,
    });
    final avg = (response['ratingAvg'] as num?)?.toDouble();
    final count = (response['ratingCount'] as num?)?.toInt();
    if (avg != null && count != null) {
      final index = _products.indexWhere((item) => item.id == productId);
      if (index != -1) {
        final updated = _products[index].copyWith(
          ratingAvg: avg,
          ratingCount: count,
        );
        _products[index] = updated;
        notifyListeners();
      }
    }
  }

  Future<void> submitSupportTicket(String subject, String message) async {
    await _apiClient.postJson('/api/support', {
      'subject': subject,
      'message': message,
    });
    await _loadMySupportTickets();
  }

  Future<void> sendSupportThreadMessage(int ticketId, String message) async {
    await _apiClient.postJson('/api/support/$ticketId/messages', {
      'message': message,
    });
    if (isAdmin) {
      await _loadSupportTickets();
    } else {
      await _loadMySupportTickets();
    }
  }

  Future<void> _loadSupportTickets() async {
    try {
      final response = await _apiClient.getJson('/api/support');
      final data = response['data'] as List<dynamic>? ?? [];
      _supportTickets
        ..clear()
        ..addAll(
          data.map((raw) {
            final map = raw as Map<String, dynamic>;
            return SupportTicket(
              id: (map['id'] as num?)?.toInt() ?? 0,
              subject: map['subject']?.toString() ?? '',
              message: map['message']?.toString() ?? '',
              status: map['status']?.toString() ?? 'open',
              createdAt:
                  DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
              adminReply: map['adminReply']?.toString(),
              repliedAt: DateTime.tryParse(map['repliedAt']?.toString() ?? ''),
              closedAt: DateTime.tryParse(map['closedAt']?.toString() ?? ''),
              userEmail:
                  (map['user'] as Map<String, dynamic>?)?['email']
                      ?.toString() ??
                  '',
              messages: _supportMessagesFromApi(map['messages']),
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // ignore support load failures
    }
  }

  Future<void> _loadMySupportTickets() async {
    if (!isAuthenticated) {
      _mySupportTickets.clear();
      return;
    }
    try {
      final response = await _apiClient.getJson('/api/support/me');
      final data = response['data'] as List<dynamic>? ?? [];
      _mySupportTickets
        ..clear()
        ..addAll(
          data.map((raw) {
            final map = raw as Map<String, dynamic>;
            return SupportTicket(
              id: (map['id'] as num?)?.toInt() ?? 0,
              subject: map['subject']?.toString() ?? '',
              message: map['message']?.toString() ?? '',
              status: map['status']?.toString() ?? 'open',
              createdAt:
                  DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
              adminReply: map['adminReply']?.toString(),
              repliedAt: DateTime.tryParse(map['repliedAt']?.toString() ?? ''),
              closedAt: DateTime.tryParse(map['closedAt']?.toString() ?? ''),
              userEmail: _userEmail ?? '',
              messages: _supportMessagesFromApi(map['messages']),
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // ignore support load failures
    }
  }

  Future<void> replySupportTicket(int id, String reply) async {
    await _apiClient.patchJson('/api/support/$id/reply', {'reply': reply});
    await _loadSupportTickets();
  }

  Future<void> closeSupportTicket(int id) async {
    await _apiClient.patchJson('/api/support/$id/close', {});
    if (isAdmin) {
      await _loadSupportTickets();
    } else {
      await _loadMySupportTickets();
    }
  }

  Future<PlaceOrderResult> placeOrder({
    required String shippingAddress,
    required String paymentMethod,
    String? couponCode,
    double? shippingLatitude,
    double? shippingLongitude,
    String? shippingPlaceLabel,
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
      final response = await _apiClient.postJson('/api/orders', {
        'shippingAddress': shippingAddress,
        'paymentMethod': paymentMethod,
        'lines': lines,
        'couponCode': couponCode,
        'shippingLatitude': shippingLatitude,
        'shippingLongitude': shippingLongitude,
        'shippingPlaceLabel': shippingPlaceLabel,
      });

      final createdOrder = _orderFromApi(response);
      final createdLines = await _loadOrderLines(createdOrder.id);
      final completedOrder = createdOrder.copyWith(lines: createdLines);

      _cart.clear();
      await refreshAll();
      return PlaceOrderResult(
        success: true,
        message: 'Order placed successfully.',
        order: _orders.firstWhere(
          (order) => order.id == completedOrder.id,
          orElse: () => completedOrder,
        ),
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
    required double discountPercent,
    DateTime? discountStart,
    DateTime? discountEnd,
    required int stock,
    required String imageUrl,
  }) async {
    await _apiClient.postJson('/api/products', {
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'discountPercent': discountPercent,
      'discountStart': discountStart?.toIso8601String(),
      'discountEnd': discountEnd?.toIso8601String(),
      'stock': stock,
      'imageUrl': imageUrl,
    });
    await refreshAll();
  }

  Future<AuthResult> importInventoryCsv(String csv) async {
    if (!isAdmin) {
      return const AuthResult(
        success: false,
        message: 'Admin access required.',
      );
    }

    try {
      final response = await _apiClient.postJson(
        '/api/products/restock/import',
        {'csv': csv},
      );
      await refreshAll();
      final importedCount = (response['importedCount'] as num?)?.toInt() ?? 0;
      return AuthResult(
        success: true,
        message:
            'Imported $importedCount inventory row${importedCount == 1 ? '' : 's'}.',
      );
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to import inventory.',
      );
    }
  }

  Future<AuthResult> importProductsCsv(String csv) async {
    if (!isAdmin) {
      return const AuthResult(
        success: false,
        message: 'Admin access required.',
      );
    }

    try {
      final response = await _apiClient.postJson('/api/products/import', {
        'csv': csv,
      });
      await refreshAll();
      final importedCount = (response['importedCount'] as num?)?.toInt() ?? 0;
      return AuthResult(
        success: true,
        message: 'Imported $importedCount products.',
      );
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to import products.',
      );
    }
  }

  Future<void> updateProduct(Product updated) async {
    final response = await _apiClient.putJson('/api/products/${updated.id}', {
      'name': updated.name,
      'category': updated.category,
      'description': updated.description,
      'price': updated.price,
      'discountPercent': updated.discountPercent,
      'discountStart': updated.discountStart?.toIso8601String(),
      'discountEnd': updated.discountEnd?.toIso8601String(),
      'imageUrl': updated.imageUrl,
      'stock': updated.stock,
      'isActive': updated.isActive,
    });
    _mergeProductFromApi(response);
    await _loadCategories();
  }

  Future<void> toggleProductStatus(String productId, bool isActive) async {
    final product = getProductById(productId);
    if (product == null) {
      return;
    }
    final index = _products.indexWhere((item) => item.id == productId);
    if (index == -1) {
      return;
    }

    final previous = _products[index];
    _products[index] = previous.copyWith(isActive: isActive);
    notifyListeners();

    try {
      await updateProduct(previous.copyWith(isActive: isActive));
    } catch (_) {
      _products[index] = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    final index = _products.indexWhere((item) => item.id == productId);
    if (index == -1) {
      await _apiClient.delete('/api/products/$productId');
      await _loadCategories();
      return;
    }

    final existing = _products[index];
    _products.removeAt(index);
    notifyListeners();

    try {
      final response = await _apiClient.deleteJson('/api/products/$productId');
      final archived = response['archived'] == true;
      final archivedProduct = response['product'];

      if (archived && archivedProduct is Map<String, dynamic>) {
        _products.insert(index, _productFromApi(archivedProduct));
        notifyListeners();
      }

      await _loadCategories();
    } catch (_) {
      _products.insert(index, existing);
      notifyListeners();
      rethrow;
    }
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
    final response = await _apiClient.patchJson('/api/orders/$orderId/status', {
      'status': nextStatus.name,
    });
    _mergeOrderFromApi(response);
  }

  Future<void> loadComments(String productId) async {
    try {
      final response = await _apiClient.getJson(
        '/api/comments',
        query: {'productId': productId},
      );
      final data = response['data'] as List<dynamic>? ?? [];
      _commentsByProduct[productId] = data
          .map(_commentFromApi)
          .toList(growable: false);
      notifyListeners();
    } on ApiException catch (err) {
      _setError(err.message);
    } catch (_) {
      _setError('Unable to load comments.');
    }
  }

  Future<AuthResult> addComment(String productId, String message) async {
    if (!isAuthenticated) {
      return const AuthResult(
        success: false,
        message: 'Login required to comment.',
      );
    }
    try {
      await _apiClient.postJson('/api/comments', {
        'productId': productId,
        'message': message,
      });
      await loadComments(productId);
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to add comment.',
      );
    }
  }

  Future<AuthResult> updateComment(
    String productId,
    int commentId,
    String message,
  ) async {
    if (!isAuthenticated) {
      return const AuthResult(
        success: false,
        message: 'Login required to edit comments.',
      );
    }
    try {
      await _apiClient.patchJson('/api/comments/$commentId', {
        'message': message,
      });
      await loadComments(productId);
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to update comment.',
      );
    }
  }

  Future<AuthResult> deleteComment(String productId, int commentId) async {
    if (!isAuthenticated) {
      return const AuthResult(
        success: false,
        message: 'Login required to delete comments.',
      );
    }
    try {
      await _apiClient.delete('/api/comments/$commentId');
      await loadComments(productId);
      return const AuthResult(success: true);
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to delete comment.',
      );
    }
  }

  Future<void> updateOrderTracking({
    required String orderId,
    String? trackingNumber,
    String? trackingCarrier,
    String? trackingStatus,
  }) async {
    final response = await _apiClient
        .patchJson('/api/orders/$orderId/tracking', {
          'trackingNumber': trackingNumber,
          'trackingCarrier': trackingCarrier,
          'trackingStatus': trackingStatus,
        });
    _mergeOrderFromApi(response);
  }

  Future<void> createCoupon({
    required String code,
    required String type,
    required double value,
    required String audience,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? userEmail,
  }) async {
    await _apiClient.postJson('/api/coupons', {
      'code': code,
      'type': type,
      'value': value,
      'audience': audience,
      'description': description,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'userEmail': userEmail,
    });
    await _loadCoupons();
  }

  Future<void> updateCoupon({
    required int id,
    required bool isActive,
    required String type,
    required double value,
    required String audience,
    String? description,
    DateTime? startsAt,
    DateTime? endsAt,
    String? userEmail,
  }) async {
    await _apiClient.patchJson('/api/coupons/$id', {
      'isActive': isActive,
      'type': type,
      'value': value,
      'audience': audience,
      'description': description,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'userEmail': userEmail,
    });
    await _loadCoupons();
  }

  Future<AuthResult> deleteCoupon(int id) async {
    try {
      final response = await _apiClient.deleteJson('/api/coupons/$id');
      await _loadCoupons();
      return AuthResult(
        success: true,
        message:
            response['message']?.toString() ??
            (response['archived'] == true
                ? 'Coupon deactivated because it already has redemption history.'
                : 'Coupon deleted.'),
      );
    } on ApiException catch (err) {
      return AuthResult(success: false, message: err.message);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Failed to delete coupon.',
      );
    }
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

  Future<String?> uploadProfileImage(XFile file) async {
    if (!isAuthenticated || _token == null || _userId == null) {
      _setError('Login is required before uploading a profile image.');
      return null;
    }

    _setLoading(true);
    try {
      final response = await _apiClient.uploadImage('/api/uploads/profile', file);
      final url = response['url']?.toString();
      final user = response['user'] as Map<String, dynamic>?;
      if (user != null) {
        await _saveSession(
          token: _token!,
          userId: (user['id'] as num?)?.toInt() ?? _userId!,
          email: user['email']?.toString() ?? userEmail,
          firstName: user['firstName']?.toString() ?? userFirstName,
          lastName: user['lastName']?.toString() ?? userLastName,
          profileImageUrl:
              user['profileImageUrl']?.toString() ?? _userProfileImageUrl,
          role: user['role']?.toString() ?? _role ?? 'client',
        );
      } else if (url != null && url.isNotEmpty) {
        await _saveSession(
          token: _token!,
          userId: _userId!,
          email: userEmail,
          firstName: userFirstName,
          lastName: userLastName,
          profileImageUrl: url,
          role: _role ?? 'client',
        );
      }

      final finalUrl = user?['profileImageUrl']?.toString() ?? url;
      notifyListeners();
      return finalUrl;
    } on ApiException catch (err) {
      _setError(err.message);
      return null;
    } catch (_) {
      _setError('Profile image upload failed.');
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
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      discountStart: DateTime.tryParse(data['discountStart']?.toString() ?? ''),
      discountEnd: DateTime.tryParse(data['discountEnd']?.toString() ?? ''),
      ratingAvg: (data['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
      imageUrl: data['imageUrl']?.toString() ?? '',
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] == null ? true : data['isActive'] == true,
    );
  }

  void _mergeProductFromApi(Map<String, dynamic> raw) {
    final product = _productFromApi(raw);
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      _products.insert(0, product);
    } else {
      _products[index] = product;
    }
    notifyListeners();
  }

  void _mergeOrderFromApi(Map<String, dynamic> raw) {
    final order = _orderFromApi(raw);
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index == -1) {
      _orders.insert(0, order);
    } else {
      _orders[index] = order.copyWith(lines: _orders[index].lines);
    }
    notifyListeners();
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
      shippingLatitude: (data['shippingLatitude'] as num?)?.toDouble(),
      shippingLongitude: (data['shippingLongitude'] as num?)?.toDouble(),
      shippingPlaceLabel: data['shippingPlaceLabel']?.toString(),
      paymentMethod: data['paymentMethod']?.toString() ?? '',
      lines: [],
      total: (data['total'] as num?)?.toDouble() ?? 0,
      status: status,
      trackingNumber: data['trackingNumber']?.toString(),
      trackingCarrier: data['trackingCarrier']?.toString(),
      trackingStatus: data['trackingStatus']?.toString(),
      trackingUpdatedAt: DateTime.tryParse(
        data['trackingUpdatedAt']?.toString() ?? '',
      ),
      couponCode: data['couponCode']?.toString(),
      couponType: data['couponType']?.toString(),
      couponValue: (data['couponValue'] as num?)?.toDouble(),
      couponDiscount: (data['couponDiscount'] as num?)?.toDouble(),
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

  ProductComment _commentFromApi(dynamic raw) {
    final data = raw as Map<String, dynamic>;
    return ProductComment(
      id: (data['id'] as num?)?.toInt() ?? 0,
      productId: data['productId']?.toString() ?? '',
      userId: (data['userId'] as num?)?.toInt() ?? 0,
      userEmail: data['userEmail']?.toString() ?? '',
      userFirstName: data['userFirstName']?.toString(),
      userLastName: data['userLastName']?.toString(),
      userProfileImageUrl: data['userProfileImageUrl']?.toString(),
      message: data['message']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(data['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  List<SupportTicketMessage> _supportMessagesFromApi(dynamic raw) {
    final list = raw as List<dynamic>?;
    if (list == null) {
      return const [];
    }
    return list
        .map((entry) {
          final data = entry as Map<String, dynamic>;
          final user = data['user'] as Map<String, dynamic>?;
          return SupportTicketMessage(
            id: (data['id'] as num?)?.toInt() ?? 0,
            userId: (data['userId'] as num?)?.toInt() ?? 0,
            userEmail: user?['email']?.toString() ?? '',
            userRole: user?['role']?.toString() ?? 'client',
            message: data['message']?.toString() ?? '',
            createdAt:
                DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
                DateTime.now(),
          );
        })
        .toList(growable: false);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getInt(_userIdKey);
    _userEmail = prefs.getString(_userEmailKey);
    _userFirstName = prefs.getString(_userFirstNameKey);
    _userLastName = prefs.getString(_userLastNameKey);
    _userProfileImageUrl = prefs.getString(_userProfileImageUrlKey);
    _role = prefs.getString(_userRoleKey);
    _apiClient.token = _token;
  }

  Future<void> _validateRestoredSession() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      final response = await _apiClient.getJson('/api/auth/me');
      final user = response['user'] as Map<String, dynamic>?;
      if (user == null) {
        await _resetSession();
        return;
      }

      _userId = (user['id'] as num?)?.toInt() ?? _userId;
      _userEmail = user['email']?.toString() ?? _userEmail;
      _userFirstName = user['firstName']?.toString() ?? _userFirstName;
      _userLastName = user['lastName']?.toString() ?? _userLastName;
      _userProfileImageUrl =
          user['profileImageUrl']?.toString() ?? _userProfileImageUrl;
      _role = user['role']?.toString() ?? _role;
      await _saveSession(
        token: _token!,
        userId: _userId ?? 0,
        email: _userEmail ?? '',
        firstName: _userFirstName,
        lastName: _userLastName,
        profileImageUrl: _userProfileImageUrl,
        role: _role ?? 'client',
      );
    } on ApiException catch (err) {
      if (err.statusCode == 401 || err.statusCode == 404) {
        await _resetSession();
      }
    } catch (_) {
      // Keep the stored session on transient network failures.
    }
  }

  Future<void> _saveSession({
    required String token,
    required int userId,
    required String email,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    required String role,
  }) async {
    _token = token;
    _userId = userId;
    _userEmail = email;
    _userFirstName = firstName?.trim().isNotEmpty == true
        ? firstName!.trim()
        : null;
    _userLastName = lastName?.trim().isNotEmpty == true
        ? lastName!.trim()
        : null;
    _userProfileImageUrl = profileImageUrl?.trim().isNotEmpty == true
        ? profileImageUrl!.trim()
        : null;
    _role = role;
    _apiClient.token = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setInt(_userIdKey, userId);
    await prefs.setString(_userEmailKey, email);
    if (_userFirstName != null) {
      await prefs.setString(_userFirstNameKey, _userFirstName!);
    } else {
      await prefs.remove(_userFirstNameKey);
    }
    if (_userLastName != null) {
      await prefs.setString(_userLastNameKey, _userLastName!);
    } else {
      await prefs.remove(_userLastNameKey);
    }
    if (_userProfileImageUrl != null) {
      await prefs.setString(_userProfileImageUrlKey, _userProfileImageUrl!);
    } else {
      await prefs.remove(_userProfileImageUrlKey);
    }
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
