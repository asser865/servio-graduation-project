import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/storage_service.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({
    StorageService? storage,
    TokenStorage? tokenStorage,
    http.Client? httpClient,
    String? baseUrl,
    Duration? timeout = const Duration(seconds: 20),
  })  : assert(
          storage != null || tokenStorage != null,
          'Provide either storage or tokenStorage.',
        ),
        _tokenStorage = tokenStorage ?? StorageBackedTokenStorage(storage!),
        _httpClient = httpClient ?? http.Client(),
        _baseUrl =
            (baseUrl ?? ApiConfig.baseUrl).replaceFirst(RegExp(r'/$'), ''),
        _timeout = timeout;

  final TokenStorage _tokenStorage;
  final http.Client _httpClient;
  final String _baseUrl;
  final Duration? _timeout;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request('DELETE', path, body: body);

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
    final token = await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final requestBody = body == null ? null : jsonEncode(body);
    late final http.Response response;
    try {
      final request = switch (method) {
        'GET' => _httpClient.get(uri, headers: headers),
        'POST' => _httpClient.post(uri, headers: headers, body: requestBody),
        'PATCH' => _httpClient.patch(uri, headers: headers, body: requestBody),
        'PUT' => _httpClient.put(uri, headers: headers, body: requestBody),
        'DELETE' =>
          _httpClient.delete(uri, headers: headers, body: requestBody),
        _ => throw StateError('Unsupported HTTP method: $method'),
      };
      final timeout = _timeout;
      response = await (timeout == null ? request : request.timeout(timeout));
    } on TimeoutException {
      throw const ApiException(message: 'Request timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect. Check your internet connection.',
      );
    }

    late final Map<String, dynamic> decoded;
    try {
      decoded = _decode(response.body);
    } on FormatException {
      throw const ApiException(message: 'Invalid server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        await _tokenStorage.clearToken();
      }
      final errors = decoded['errors'];
      throw ApiException(
        statusCode: response.statusCode,
        message: (decoded['message'] as String?) ??
            (decoded['error'] as String?) ??
            'Request failed.',
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
