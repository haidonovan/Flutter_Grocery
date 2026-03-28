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

  double get discountedPrice => price * (1 - (effectiveDiscountPercent / 100));
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
    required this.customerFirstName,
    required this.customerLastName,
    required this.customerProfileImageUrl,
    required this.createdAt,
    required this.shippingAddress,
    required this.shippingLatitude,
    required this.shippingLongitude,
    required this.shippingPlaceLabel,
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
  final String? customerFirstName;
  final String? customerLastName;
  final String? customerProfileImageUrl;
  final DateTime createdAt;
  final String shippingAddress;
  final double? shippingLatitude;
  final double? shippingLongitude;
  final String? shippingPlaceLabel;
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

  bool get hasShippingLocation =>
      shippingLatitude != null && shippingLongitude != null;

  String get customerDisplayName {
    final parts = [customerFirstName?.trim(), customerLastName?.trim()]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return customerEmail;
  }

  String get customerSearchText {
    return [
      customerDisplayName,
      customerEmail,
      customerFirstName ?? '',
      customerLastName ?? '',
    ].join(' ').trim();
  }

  String get customerInitials {
    final source = customerDisplayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
  }

  String get shippingLocationLabel {
    final trimmed = shippingPlaceLabel?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return shippingAddress;
  }

  OrderRecord copyWith({
    String? id,
    String? customerEmail,
    String? customerFirstName,
    String? customerLastName,
    String? customerProfileImageUrl,
    DateTime? createdAt,
    String? shippingAddress,
    double? shippingLatitude,
    double? shippingLongitude,
    String? shippingPlaceLabel,
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
      customerFirstName: customerFirstName ?? this.customerFirstName,
      customerLastName: customerLastName ?? this.customerLastName,
      customerProfileImageUrl:
          customerProfileImageUrl ?? this.customerProfileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingLatitude: shippingLatitude ?? this.shippingLatitude,
      shippingLongitude: shippingLongitude ?? this.shippingLongitude,
      shippingPlaceLabel: shippingPlaceLabel ?? this.shippingPlaceLabel,
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

class AppUserSummary {
  const AppUserSummary({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.profileImageUrl,
    this.role,
  });

  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profileImageUrl;
  final String? role;

  String get displayName {
    final parts = [firstName?.trim(), lastName?.trim()]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return email;
  }

  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
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
    this.targetUser,
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
  final AppUserSummary? targetUser;

  bool get isForEveryone => (audience ?? 'all') != 'user';

  String get audienceLabel => isForEveryone ? 'Everyone' : 'Specific user';

  String get targetDisplayName {
    if (isForEveryone) {
      return 'Everyone';
    }
    return targetUser?.displayName ?? (userEmail?.trim().isNotEmpty == true
        ? userEmail!.trim()
        : 'Specific user');
  }

  String get targetSearchText {
    return [
      code,
      description ?? '',
      targetDisplayName,
      userEmail ?? '',
      targetUser?.firstName ?? '',
      targetUser?.lastName ?? '',
    ].join(' ').trim();
  }
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userProfileImageUrl,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.adminReply,
    required this.repliedAt,
    required this.closedAt,
    this.messages = const [],
  });

  final int id;
  final String userEmail;
  final String? userFirstName;
  final String? userLastName;
  final String? userProfileImageUrl;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? closedAt;
  final List<SupportTicketMessage> messages;

  String get userDisplayName {
    final parts = [userFirstName?.trim(), userLastName?.trim()]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return userEmail;
  }

  String get userInitials {
    final source = userDisplayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.id,
    required this.userId,
    required this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userProfileImageUrl,
    required this.userRole,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userEmail;
  final String? userFirstName;
  final String? userLastName;
  final String? userProfileImageUrl;
  final String userRole;
  final String message;
  final DateTime createdAt;

  String get userDisplayName {
    final parts = [userFirstName?.trim(), userLastName?.trim()]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    if (userRole == 'admin') {
      return 'Support team';
    }
    return userEmail;
  }

  String get userInitials {
    final source = userDisplayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
  }
}

class ProductComment {
  const ProductComment({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userEmail,
    this.userFirstName,
    this.userLastName,
    this.userProfileImageUrl,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String productId;
  final int userId;
  final String userEmail;
  final String? userFirstName;
  final String? userLastName;
  final String? userProfileImageUrl;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEdited => updatedAt.isAfter(createdAt);

  String get userDisplayName {
    final parts = [userFirstName?.trim(), userLastName?.trim()]
        .where((value) => value != null && value.isNotEmpty)
        .cast<String>()
        .toList(growable: false);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return userEmail;
  }

  String get userInitials {
    final source = userDisplayName.trim();
    if (source.isEmpty) {
      return '?';
    }
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return source.substring(0, 1).toUpperCase();
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
