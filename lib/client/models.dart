class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.discountPercent,
    required this.discountStart,
    required this.discountEnd,
    required this.ratingAvg,
    required this.ratingCount,
    required this.imageUrl,
    required this.stock,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double price;
  final double discountPercent;
  final DateTime? discountStart;
  final DateTime? discountEnd;
  final double ratingAvg;
  final int ratingCount;
  final String imageUrl;
  final int stock;
  final bool isActive;

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    double? price,
    double? discountPercent,
    DateTime? discountStart,
    DateTime? discountEnd,
    double? ratingAvg,
    int? ratingCount,
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
      discountPercent: discountPercent ?? this.discountPercent,
      discountStart: discountStart ?? this.discountStart,
      discountEnd: discountEnd ?? this.discountEnd,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      ratingCount: ratingCount ?? this.ratingCount,
      imageUrl: imageUrl ?? this.imageUrl,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isDiscountActive {
    if (discountPercent <= 0) {
      return false;
    }
    final now = DateTime.now();
    if (discountStart != null && now.isBefore(discountStart!)) {
      return false;
    }
    if (discountEnd != null && now.isAfter(discountEnd!)) {
      return false;
    }
    return true;
  }

  double get effectiveDiscountPercent =>
      isDiscountActive ? discountPercent.clamp(0, 100) : 0;

  double get discountedPrice =>
      price * (1 - (effectiveDiscountPercent / 100));
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
    required this.discountPercent,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discountPercent;

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
    required this.trackingNumber,
    required this.trackingCarrier,
    required this.trackingStatus,
    required this.trackingUpdatedAt,
    required this.couponCode,
    required this.couponType,
    required this.couponValue,
    required this.couponDiscount,
  });

  final String id;
  final String customerEmail;
  final DateTime createdAt;
  final String shippingAddress;
  final String paymentMethod;
  final List<OrderLine> lines;
  final double total;
  final OrderStatus status;
  final String? trackingNumber;
  final String? trackingCarrier;
  final String? trackingStatus;
  final DateTime? trackingUpdatedAt;
  final String? couponCode;
  final String? couponType;
  final double? couponValue;
  final double? couponDiscount;

  OrderRecord copyWith({
    String? id,
    String? customerEmail,
    DateTime? createdAt,
    String? shippingAddress,
    String? paymentMethod,
    List<OrderLine>? lines,
    double? total,
    OrderStatus? status,
    String? trackingNumber,
    String? trackingCarrier,
    String? trackingStatus,
    DateTime? trackingUpdatedAt,
    String? couponCode,
    String? couponType,
    double? couponValue,
    double? couponDiscount,
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
      trackingNumber: trackingNumber ?? this.trackingNumber,
      trackingCarrier: trackingCarrier ?? this.trackingCarrier,
      trackingStatus: trackingStatus ?? this.trackingStatus,
      trackingUpdatedAt: trackingUpdatedAt ?? this.trackingUpdatedAt,
      couponCode: couponCode ?? this.couponCode,
      couponType: couponType ?? this.couponType,
      couponValue: couponValue ?? this.couponValue,
      couponDiscount: couponDiscount ?? this.couponDiscount,
    );
  }
}

class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.isActive,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.userEmail,
  });

  final int id;
  final String code;
  final String type;
  final double value;
  final bool isActive;
  final String? description;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? audience;
  final String? userEmail;
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.userEmail,
    required this.message,
    required this.isResolved,
    required this.createdAt,
  });

  final int id;
  final String userEmail;
  final String message;
  final bool isResolved;
  final DateTime createdAt;
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
