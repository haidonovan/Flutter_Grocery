import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../client/models.dart';

class CartViewItem {
  const CartViewItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
}

class PlaceOrderResult {
  const PlaceOrderResult({required this.success, this.message, this.order});

  final bool success;
  final String? message;
  final OrderRecord? order;
}

class GroceryStoreState extends ChangeNotifier {
  GroceryStoreState._();

  static const String _storageKey = 'grocery_store_state_v1';

  static Future<GroceryStoreState> create() async {
    final store = GroceryStoreState._();
    await store._loadState();
    return store;
  }

  static List<Product> _defaultProducts() {
    return const [
      Product(
        id: 'p1',
        name: 'Fresh Apples',
        category: 'Fruits',
        description: 'Crisp and sweet red apples, sold per kg.',
        price: 3.25,
        imageUrl: 'https://picsum.photos/seed/apples/900/500',
        stock: 40,
      ),
      Product(
        id: 'p2',
        name: 'Whole Milk',
        category: 'Dairy',
        description: '1L whole milk from local farms.',
        price: 1.99,
        imageUrl: 'https://picsum.photos/seed/milk/900/500',
        stock: 30,
      ),
      Product(
        id: 'p3',
        name: 'Basmati Rice',
        category: 'Grains',
        description: 'Premium long-grain basmati rice, 5kg bag.',
        price: 12.50,
        imageUrl: 'https://picsum.photos/seed/rice/900/500',
        stock: 18,
      ),
      Product(
        id: 'p4',
        name: 'Chicken Breast',
        category: 'Meat',
        description: 'Boneless chicken breast, approx. 500g tray.',
        price: 5.40,
        imageUrl: 'https://picsum.photos/seed/chicken/900/500',
        stock: 22,
      ),
      Product(
        id: 'p5',
        name: 'Orange Juice',
        category: 'Beverages',
        description: 'No-added-sugar orange juice, 1L bottle.',
        price: 2.80,
        imageUrl: 'https://picsum.photos/seed/orange-juice/900/500',
        stock: 26,
      ),
    ];
  }

  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  final List<OrderRecord> _orders = [];
  final List<RestockRecord> _restockHistory = [];

  int _productSeq = 1;

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
      _commitState();
      return true;
    }

    final updatedQuantity = _cart[index].quantity + quantity;
    if (updatedQuantity > product.stock) {
      return false;
    }

    _cart[index].quantity = updatedQuantity;
    _commitState();
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
    _commitState();
  }

  void removeFromCart(String productId) {
    _cart.removeWhere((item) => item.productId == productId);
    _commitState();
  }

  List<OrderRecord> ordersForUser(String email) {
    return _orders
        .where(
          (order) => order.customerEmail.toLowerCase() == email.toLowerCase(),
        )
        .toList(growable: false);
  }

  PlaceOrderResult placeOrder({
    required String customerEmail,
    required String shippingAddress,
    required String paymentMethod,
  }) {
    if (_cart.isEmpty) {
      return const PlaceOrderResult(success: false, message: 'Cart is empty.');
    }

    for (final item in _cart) {
      final product = getProductById(item.productId);
      if (product == null ||
          !product.isActive ||
          product.stock < item.quantity) {
        return const PlaceOrderResult(
          success: false,
          message: 'Some items are out of stock. Please review your cart.',
        );
      }
    }

    final lines = <OrderLine>[];
    var total = 0.0;

    for (final item in _cart) {
      final product = getProductById(item.productId)!;
      lines.add(
        OrderLine(
          productId: product.id,
          productName: product.name,
          quantity: item.quantity,
          unitPrice: product.price,
        ),
      );
      total += product.price * item.quantity;

      final productIndex = _products.indexWhere(
        (element) => element.id == product.id,
      );
      _products[productIndex] = product.copyWith(
        stock: product.stock - item.quantity,
      );
    }

    final order = OrderRecord(
      id: '#ORD-${DateTime.now().millisecondsSinceEpoch}',
      customerEmail: customerEmail,
      createdAt: DateTime.now(),
      shippingAddress: shippingAddress,
      paymentMethod: paymentMethod,
      lines: lines,
      total: total,
      status: OrderStatus.pending,
    );

    _orders.insert(0, order);
    _cart.clear();
    _commitState();

    return const PlaceOrderResult(
      success: true,
      message: 'Order placed successfully.',
    );
  }

  String addProduct({
    required String name,
    required String category,
    required String description,
    required double price,
    required int stock,
    required String imageUrl,
  }) {
    final id = 'p$_productSeq';
    _productSeq += 1;

    _products.add(
      Product(
        id: id,
        name: name,
        category: category,
        description: description,
        price: price,
        stock: stock,
        imageUrl: imageUrl,
      ),
    );
    _commitState();
    return id;
  }

  void updateProduct(Product updated) {
    final index = _products.indexWhere((product) => product.id == updated.id);
    if (index == -1) {
      return;
    }
    _products[index] = updated;

    final cartIndex = _cart.indexWhere((item) => item.productId == updated.id);
    if (cartIndex != -1 && _cart[cartIndex].quantity > updated.stock) {
      _cart[cartIndex].quantity = updated.stock;
      if (_cart[cartIndex].quantity <= 0 || !updated.isActive) {
        _cart.removeAt(cartIndex);
      }
    }

    _commitState();
  }

  void toggleProductStatus(String productId, bool isActive) {
    final product = getProductById(productId);
    if (product == null) {
      return;
    }
    updateProduct(product.copyWith(isActive: isActive));
  }

  void deleteProduct(String productId) {
    _products.removeWhere((product) => product.id == productId);
    _cart.removeWhere((item) => item.productId == productId);
    _commitState();
  }

  void restockProduct(String productId, int quantityAdded) {
    if (quantityAdded <= 0) {
      return;
    }
    final product = getProductById(productId);
    if (product == null) {
      return;
    }

    final updated = product.copyWith(stock: product.stock + quantityAdded);
    final index = _products.indexWhere((item) => item.id == productId);
    _products[index] = updated;

    _restockHistory.insert(
      0,
      RestockRecord(
        productId: updated.id,
        productName: updated.name,
        quantityAdded: quantityAdded,
        createdAt: DateTime.now(),
      ),
    );

    _commitState();
  }

  void updateOrderStatus(String orderId, OrderStatus nextStatus) {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index == -1) {
      return;
    }

    _orders[index] = _orders[index].copyWith(status: nextStatus);
    _commitState();
  }

  void _commitState() {
    notifyListeners();
    _persistState();
  }

  Future<void> _loadState() async {
    _products
      ..clear()
      ..addAll(_defaultProducts());
    _cart.clear();
    _orders.clear();
    _restockHistory.clear();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _deriveProductSeq();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _deriveProductSeq();
        return;
      }

      final products = decoded['products'];
      if (products is List) {
        _products
          ..clear()
          ..addAll(
            products.whereType<Map<String, dynamic>>().map(_productFromJson),
          );
      }

      final cart = decoded['cart'];
      if (cart is List) {
        _cart
          ..clear()
          ..addAll(
            cart.whereType<Map<String, dynamic>>().map(_cartItemFromJson),
          );
      }

      final orders = decoded['orders'];
      if (orders is List) {
        _orders
          ..clear()
          ..addAll(
            orders.whereType<Map<String, dynamic>>().map(_orderFromJson),
          );
      }

      final restocks = decoded['restockHistory'];
      if (restocks is List) {
        _restockHistory
          ..clear()
          ..addAll(
            restocks.whereType<Map<String, dynamic>>().map(_restockFromJson),
          );
      }

      _deriveProductSeq();
    } catch (_) {
      _products
        ..clear()
        ..addAll(_defaultProducts());
      _cart.clear();
      _orders.clear();
      _restockHistory.clear();
      _deriveProductSeq();
    }
  }

  Future<void> _persistState() async {
    final payload = <String, dynamic>{
      'products': _products.map(_productToJson).toList(growable: false),
      'cart': _cart.map(_cartItemToJson).toList(growable: false),
      'orders': _orders.map(_orderToJson).toList(growable: false),
      'restockHistory': _restockHistory
          .map(_restockToJson)
          .toList(growable: false),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  void _deriveProductSeq() {
    var maxSeq = 0;
    for (final product in _products) {
      if (product.id.startsWith('p')) {
        final parsed = int.tryParse(product.id.substring(1));
        if (parsed != null && parsed > maxSeq) {
          maxSeq = parsed;
        }
      }
    }
    _productSeq = maxSeq + 1;
  }

  Map<String, dynamic> _productToJson(Product product) {
    return {
      'id': product.id,
      'name': product.name,
      'category': product.category,
      'description': product.description,
      'price': product.price,
      'imageUrl': product.imageUrl,
      'stock': product.stock,
      'isActive': product.isActive,
    };
  }

  Product _productFromJson(Map<String, dynamic> json) {
    return Product(
      id: _readString(json, 'id'),
      name: _readString(json, 'name'),
      category: _readString(json, 'category'),
      description: _readString(json, 'description'),
      price: _readDouble(json, 'price'),
      imageUrl: _readString(json, 'imageUrl'),
      stock: _readInt(json, 'stock'),
      isActive: _readBool(json, 'isActive', fallback: true),
    );
  }

  Map<String, dynamic> _cartItemToJson(CartItem item) {
    return {'productId': item.productId, 'quantity': item.quantity};
  }

  CartItem _cartItemFromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: _readString(json, 'productId'),
      quantity: _readInt(json, 'quantity', fallback: 1),
    );
  }

  Map<String, dynamic> _orderToJson(OrderRecord order) {
    return {
      'id': order.id,
      'customerEmail': order.customerEmail,
      'createdAt': order.createdAt.toIso8601String(),
      'shippingAddress': order.shippingAddress,
      'paymentMethod': order.paymentMethod,
      'total': order.total,
      'status': order.status.name,
      'lines': order.lines
          .map(
            (line) => {
              'productId': line.productId,
              'productName': line.productName,
              'quantity': line.quantity,
              'unitPrice': line.unitPrice,
            },
          )
          .toList(growable: false),
    };
  }

  OrderRecord _orderFromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    final lines = <OrderLine>[];
    if (linesRaw is List) {
      for (final lineRaw in linesRaw.whereType<Map<String, dynamic>>()) {
        lines.add(
          OrderLine(
            productId: _readString(lineRaw, 'productId'),
            productName: _readString(lineRaw, 'productName'),
            quantity: _readInt(lineRaw, 'quantity', fallback: 1),
            unitPrice: _readDouble(lineRaw, 'unitPrice'),
          ),
        );
      }
    }

    final statusName = _readString(json, 'status', fallback: 'pending');
    final status = OrderStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => OrderStatus.pending,
    );

    return OrderRecord(
      id: _readString(json, 'id'),
      customerEmail: _readString(json, 'customerEmail'),
      createdAt:
          DateTime.tryParse(_readString(json, 'createdAt')) ?? DateTime.now(),
      shippingAddress: _readString(json, 'shippingAddress'),
      paymentMethod: _readString(json, 'paymentMethod'),
      lines: lines,
      total: _readDouble(json, 'total'),
      status: status,
    );
  }

  Map<String, dynamic> _restockToJson(RestockRecord record) {
    return {
      'productId': record.productId,
      'productName': record.productName,
      'quantityAdded': record.quantityAdded,
      'createdAt': record.createdAt.toIso8601String(),
    };
  }

  RestockRecord _restockFromJson(Map<String, dynamic> json) {
    return RestockRecord(
      productId: _readString(json, 'productId'),
      productName: _readString(json, 'productName'),
      quantityAdded: _readInt(json, 'quantityAdded', fallback: 0),
      createdAt:
          DateTime.tryParse(_readString(json, 'createdAt')) ?? DateTime.now(),
    );
  }

  String _readString(
    Map<String, dynamic> json,
    String key, {
    String fallback = '',
  }) {
    final value = json[key];
    if (value is String) {
      return value;
    }
    return fallback;
  }

  int _readInt(Map<String, dynamic> json, String key, {int fallback = 0}) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  double _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _readBool(
    Map<String, dynamic> json,
    String key, {
    bool fallback = false,
  }) {
    final value = json[key];
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return fallback;
  }
}
