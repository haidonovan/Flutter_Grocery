// lib/client/payway_service.dart
// Drop this file into: lib/client/payway_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Response model ──────────────────────────────────────────────────────────
class PayWayPaymentResult {
  final bool success;
  final String? tranId;
  final String? checkoutUrl;
  final String? qrString;
  final String? qrImage;       // base64 PNG — use directly in Image.memory()
  final String? abaDeeplink;
  final String? playStore;
  final String? appStore;
  final String? paymentOption;
  final String? errorMessage;
  final String? errorCode;

  const PayWayPaymentResult({
    required this.success,
    this.tranId,
    this.checkoutUrl,
    this.qrString,
    this.qrImage,
    this.abaDeeplink,
    this.playStore,
    this.appStore,
    this.paymentOption,
    this.errorMessage,
    this.errorCode,
  });

  factory PayWayPaymentResult.fromJson(Map<String, dynamic> json) {
    return PayWayPaymentResult(
      success       : json['success'] == true,
      tranId        : json['tranId'],
      checkoutUrl   : json['checkoutUrl'],
      qrString      : json['qrString'],
      qrImage       : json['qrImage'],
      abaDeeplink   : json['abaDeeplink'],
      playStore     : json['playStore'],
      appStore      : json['appStore'],
      paymentOption : json['paymentOption'],
      errorMessage  : json['message'],
      errorCode     : json['code']?.toString(),
    );
  }

  factory PayWayPaymentResult.error(String message) {
    return PayWayPaymentResult(success: false, errorMessage: message);
  }

  /// Decode the base64 qrImage (strips the data:image/png;base64, prefix)
  List<int>? get qrImageBytes {
    if (qrImage == null) return null;
    final data = qrImage!.contains(',') ? qrImage!.split(',').last : qrImage!;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────
class PayWayService {
  static String _normalizeBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('baseUrl cannot be empty.');
    }
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  static Uri _buildUri(String baseUrl, String path) {
    return Uri.parse('${_normalizeBaseUrl(baseUrl)}$path');
  }

  /// Creates a PayWay payment and returns the QR / deeplink data.
  ///
  /// [orderId]       — your internal order ID (used to build tran_id)
  /// [amount]        — total in USD, e.g. 12.50
  /// [paymentOption] — 'abapay' | 'cards' | 'bakong' | 'abapay_deeplink'
  static Future<PayWayPaymentResult> createPayment({
    required String baseUrl,
    required String orderId,
    required double amount,
    String paymentOption = 'abapay',
    String currency      = 'USD',
    String? firstname,
    String? lastname,
    String? email,
    String? phone,
  }) async {
    try {
      final uri = _buildUri(baseUrl, '/api/payway/create-payment');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type'  : 'application/json',
          // Include your auth token if your route is protected
          // 'Authorization': 'Bearer ${await ApiClient.getToken()}',
        },
        body: jsonEncode({
          'orderId'       : orderId,
          'amount'        : amount.toStringAsFixed(2),
          'paymentOption' : paymentOption,
          'currency'      : currency,
          if (firstname != null) 'firstname' : firstname,
          if (lastname  != null) 'lastname'  : lastname,
          if (email     != null) 'email'     : email,
          if (phone     != null) 'phone'     : phone,
        }),
      ).timeout(const Duration(seconds: 30));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PayWayPaymentResult.fromJson(json);
    } on Exception catch (e) {
      return PayWayPaymentResult.error('Network error: $e');
    }
  }

  /// Check if a transaction was paid (poll after QR scan).
  static Future<Map<String, dynamic>> checkTransaction({
    required String baseUrl,
    required String tranId,
  }) async {
    try {
      final uri = _buildUri(baseUrl, '/api/payway/check-transaction');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tranId': tranId}),
      ).timeout(const Duration(seconds: 15));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
