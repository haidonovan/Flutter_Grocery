import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    String? fallbackBaseUrl,
    Duration timeout = const Duration(seconds: 5),
  }) : _baseUrl = _normalizeBaseUrl(baseUrl),
       _fallbackBaseUrl = _normalizeOptionalBaseUrl(fallbackBaseUrl, baseUrl),
       _timeout = timeout;

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String? _normalizeOptionalBaseUrl(String? value, String primary) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = _normalizeBaseUrl(value);
    return normalized == _normalizeBaseUrl(primary) ? null : normalized;
  }

  String _baseUrl;
  final String? _fallbackBaseUrl;
  final Duration _timeout;
  String? _token;

  String get baseUrl => _baseUrl;

  set token(String? value) => _token = value;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .get(
            Uri.parse('$baseUrl$path').replace(queryParameters: query),
            headers: _headers(),
          )
          .timeout(_timeout),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers())
          .timeout(_timeout),
    );
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractMessage(response.body),
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _sendWithFallback(
      (baseUrl) => http
          .delete(Uri.parse('$baseUrl$path'), headers: _headers())
          .timeout(_timeout),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadImage(String path, XFile file) async {
    final bytes = await file.readAsBytes();
    final response = await _sendWithFallback((baseUrl) async {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (_token != null && _token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name.isNotEmpty ? file.name : 'upload.jpg',
        ),
      );
      final streamed = await request.send().timeout(_timeout);
      return http.Response.fromStream(streamed);
    });
    return _decode(response);
  }

  Future<http.Response> _sendWithFallback(
    Future<http.Response> Function(String baseUrl) send,
  ) async {
    try {
      return await send(_baseUrl);
    } catch (error) {
      if (!_shouldFallback(error)) {
        rethrow;
      }
    }

    _baseUrl = _fallbackBaseUrl!;
    return send(_baseUrl);
  }

  bool _shouldFallback(Object error) {
    if (_fallbackBaseUrl == null || _baseUrl == _fallbackBaseUrl) {
      return false;
    }
    return error is TimeoutException || error is http.ClientException;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body;
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractMessage(body),
        statusCode: response.statusCode,
      );
    }

    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return {'data': decoded};
    }
    return <String, dynamic>{};
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // ignore decode failures
    }
    return 'Request failed.';
  }
}
