import 'dart:convert';

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
  ApiClient({required String baseUrl})
    : _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

  final String _baseUrl;
  String? _token;

  String get baseUrl => _baseUrl;

  set token(String? value) => _token = value;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final response = await http.get(uri, headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.put(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.delete(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractMessage(response.body),
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.delete(uri, headers: _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> uploadImage(String path, XFile file) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null && _token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'upload.jpg',
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
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
