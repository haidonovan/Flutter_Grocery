class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.stock,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final String imageUrl;
  final int stock;
  final bool isActive;

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    double? price,
    String? imageUrl,
    int? stock,
    bool? isActive,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }
}

class CartItem {
  CartItem({required this.productId, this.quantity = 1});

  final String productId;
  int quantity;
}

class OrderLine {
  const OrderLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get subtotal => unitPrice * quantity;
}

enum OrderStatus { pending, processing, shipped, delivered, cancelled }

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.customerEmail,
    required this.createdAt,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.lines,
    required this.total,
    required this.status,
  });

  final String id;
  final String customerEmail;
  final DateTime createdAt;
  final String shippingAddress;
  final String paymentMethod;
  final List<OrderLine> lines;
  final double total;
  final OrderStatus status;

  OrderRecord copyWith({
    String? id,
    String? customerEmail,
    DateTime? createdAt,
    String? shippingAddress,
    String? paymentMethod,
    List<OrderLine>? lines,
    double? total,
    OrderStatus? status,
  }) {
    return OrderRecord(
      id: id ?? this.id,
      customerEmail: customerEmail ?? this.customerEmail,
      createdAt: createdAt ?? this.createdAt,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      lines: lines ?? this.lines,
      total: total ?? this.total,
      status: status ?? this.status,
    );
  }
}

class RestockRecord {
  const RestockRecord({
    required this.productId,
    required this.productName,
    required this.quantityAdded,
    required this.createdAt,
  });

  final String productId;
  final String productName;
  final int quantityAdded;
  final DateTime createdAt;
}
