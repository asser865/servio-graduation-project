import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/storage_service.dart';
import 'api_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required StorageService storage,
    http.Client? httpClient,
    String? baseUrl,
  })  : _storage = storage,
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/$'), '');

  final StorageService _storage;
  final http.Client _httpClient;
  final String _baseUrl;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _storage.getSecureString(StorageService.keyAuthToken);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final requestBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => _httpClient.get(uri, headers: headers),
      'POST' => _httpClient.post(uri, headers: headers, body: requestBody),
      'PATCH' => _httpClient.patch(uri, headers: headers, body: requestBody),
      'PUT' => _httpClient.put(uri, headers: headers, body: requestBody),
      'DELETE' => _httpClient.delete(uri, headers: headers),
      _ => throw StateError('Unsupported HTTP method: $method'),
    };

    final decoded = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errors = decoded['errors'];
      throw ApiException(
        statusCode: response.statusCode,
        message: (decoded['message'] as String?) ?? 'Request failed.',
        errors: errors is List
            ? errors.whereType<Map<String, dynamic>>().toList()
            : const <Map<String, dynamic>>[],
      );
    }

    return decoded;
  }

  Map<String, dynamic> unwrapData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return response;
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
