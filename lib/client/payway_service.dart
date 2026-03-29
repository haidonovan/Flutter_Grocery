import 'dart:convert';

import 'package:http/http.dart' as http;

class PayWayPaymentResult {
  const PayWayPaymentResult({
    required this.success,
    this.orderId,
    this.tranId,
    this.qrString,
    this.qrImage,
    this.deeplink,
    this.amount,
    this.currency,
    this.expiresAt,
    this.errorMessage,
    this.errorCode,
  });

  final bool success;
  final String? orderId;
  final String? tranId;
  final String? qrString;
  final String? qrImage;
  final String? deeplink;
  final String? amount;
  final String? currency;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String? errorCode;

  factory PayWayPaymentResult.fromJson(Map<String, dynamic> json) {
    return PayWayPaymentResult(
      success:
          (json['tran_id']?.toString().isNotEmpty == true) &&
          (json['qrImage'] != null ||
              json['qrString'] != null ||
              json['deeplink'] != null),
      orderId: json['orderId']?.toString(),
      tranId: json['tran_id']?.toString() ?? json['tranId']?.toString(),
      qrString: json['qrString']?.toString(),
      qrImage: json['qrImage']?.toString(),
      deeplink: json['deeplink']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      errorMessage: json['error']?.toString(),
      errorCode: json['code']?.toString(),
    );
  }

  factory PayWayPaymentResult.error(String message, {String? code}) {
    return PayWayPaymentResult(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }

  List<int>? get qrImageBytes {
    if (qrImage == null || qrImage!.trim().isEmpty) {
      return null;
    }

    final data = qrImage!.contains(',') ? qrImage!.split(',').last : qrImage!;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

  int get secondsUntilExpiry {
    if (expiresAt == null) {
      return 180;
    }

    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}

class PayWayStatusResult {
  const PayWayStatusResult({
    required this.status,
    this.orderId,
    this.tranId,
    this.paymentStatus,
    this.failureReason,
    this.expiresAt,
    this.paidAt,
    this.errorMessage,
  });

  final String status;
  final String? orderId;
  final String? tranId;
  final String? paymentStatus;
  final String? failureReason;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final String? errorMessage;

  bool get isPaid => status == 'PAID';
  bool get isFailed => status == 'FAILED';
  bool get isPending => status == 'PENDING';

  factory PayWayStatusResult.fromJson(Map<String, dynamic> json) {
    return PayWayStatusResult(
      status: json['status']?.toString().toUpperCase() ?? 'PENDING',
      orderId: json['orderId']?.toString(),
      tranId: json['tran_id']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      failureReason: json['failureReason']?.toString(),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
      errorMessage: json['error']?.toString(),
    );
  }
}

class PayWayService {
  static Future<PayWayPaymentResult> createPayment({
    required String baseUrl,
    required String authToken,
    required double amount,
    required String shippingAddress,
    required List<Map<String, dynamic>> lines,
    String currency = 'USD',
    String? orderId,
    String? couponCode,
    double? shippingLatitude,
    double? shippingLongitude,
    String? shippingPlaceLabel,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await http
          .post(
            _buildUri(baseUrl, '/api/payments/create'),
            headers: _headers(authToken),
            body: jsonEncode({
              'orderId': orderId,
              'amount': amount.toStringAsFixed(2),
              'currency': currency,
              'shippingAddress': shippingAddress,
              'lines': lines,
              'couponCode': couponCode,
              'shippingLatitude': shippingLatitude,
              'shippingLongitude': shippingLongitude,
              'shippingPlaceLabel': shippingPlaceLabel,
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'phone': phone,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final json = _decodeBody(response.body);
      if (response.statusCode >= 400) {
        return PayWayPaymentResult.error(
          json['error']?.toString() ?? 'Unable to create ABA payment.',
          code: json['code']?.toString(),
        );
      }

      return PayWayPaymentResult.fromJson(json);
    } on Exception catch (error) {
      return PayWayPaymentResult.error('Network error: $error');
    }
  }

  static Future<PayWayStatusResult> getPaymentStatus({
    required String baseUrl,
    required String authToken,
    required String tranId,
  }) async {
    try {
      final response = await http
          .get(
            _buildUri(baseUrl, '/api/payments/status/$tranId'),
            headers: _headers(authToken),
          )
          .timeout(const Duration(seconds: 15));

      final json = _decodeBody(response.body);
      if (response.statusCode >= 400) {
        return PayWayStatusResult(
          status: 'PENDING',
          errorMessage:
              json['error']?.toString() ?? 'Unable to fetch payment status.',
          orderId: json['orderId']?.toString(),
          tranId: tranId,
        );
      }

      return PayWayStatusResult.fromJson(json);
    } on Exception catch (error) {
      return PayWayStatusResult(
        status: 'PENDING',
        tranId: tranId,
        errorMessage: 'Network error: $error',
      );
    }
  }

  static Uri _buildUri(String baseUrl, String path) {
    final normalized = baseUrl.trim().endsWith('/')
        ? baseUrl.trim().substring(0, baseUrl.trim().length - 1)
        : baseUrl.trim();
    return Uri.parse('$normalized$path');
  }

  static Map<String, String> _headers(String authToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}
