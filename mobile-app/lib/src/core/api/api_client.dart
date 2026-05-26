import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

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

  String get baseUrl => _baseUrl;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _request('DELETE', path, body: body);

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);

  /// Multipart POST. Use for endpoints that accept binary uploads (image
  /// analysis, document verification). [fields] is serialised as plain form
  /// fields; [fileField] carries the binary part.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required MultipartFilePart fileField,
    Duration? timeoutOverride,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = await _tokenStorage.getToken();
    final didSendToken = token != null && token.isNotEmpty;
    final request = http.MultipartRequest('POST', uri);
    if (didSendToken) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileField.field,
        fileField.bytes,
        filename: fileField.filename,
        contentType: fileField.contentType,
      ),
    );

    final timeout = timeoutOverride ?? _timeout;
    late final http.Response response;
    try {
      final streamed = await (timeout == null
          ? _httpClient.send(request)
          : _httpClient.send(request).timeout(timeout));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        message: 'Upload timed out. Please try again.',
      );
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
      if (response.statusCode == 401 && didSendToken) {
        await _tokenStorage.clearToken();
      }
      final errors = decoded['errors'];
      throw ApiException(
        statusCode: response.statusCode,
        message: (decoded['message'] as String?) ??
            (decoded['error'] as String?) ??
            'Upload failed.',
        errors: errors is List
            ? errors.whereType<Map<String, dynamic>>().toList()
            : const <Map<String, dynamic>>[],
      );
    }
    return decoded;
  }

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
    final didSendToken = token != null && token.isNotEmpty;
    if (didSendToken) {
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
      // Only clear token when server explicitly rejected a token we sent.
      // If we sent no token, there's nothing to clear and we must not wipe
      // a valid token that lives in storage for other requests.
      if (response.statusCode == 401 && didSendToken) {
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

  /// Raw binary POST — used by the `/uploads` endpoint which accepts
  /// `express.raw()` body instead of multipart. Returns decoded JSON.
  Future<Map<String, dynamic>> postRaw(
    String path, {
    required List<int> bytes,
    required String contentType,
    Map<String, String>? queryParams,
    Duration? timeoutOverride,
  }) async {
    final base = Uri.parse('$_baseUrl$path');
    final uri = queryParams != null ? base.replace(queryParameters: queryParams) : base;
    final token = await _tokenStorage.getToken();
    final didSendToken = token != null && token.isNotEmpty;
    final headers = <String, String>{'Content-Type': contentType};
    if (didSendToken) {
      headers['Authorization'] = 'Bearer $token';
    }

    final timeout = timeoutOverride ?? _timeout;
    late final http.Response response;
    try {
      final req = _httpClient.post(uri, headers: headers, body: bytes);
      response = await (timeout == null ? req : req.timeout(timeout));
    } on TimeoutException {
      throw const ApiException(message: 'Upload timed out. Please try again.');
    } on http.ClientException {
      throw const ApiException(
          message: 'Unable to connect. Check your internet connection.');
    }

    late final Map<String, dynamic> decoded;
    try {
      decoded = _decode(response.body);
    } on FormatException {
      throw const ApiException(message: 'Invalid server response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && didSendToken) await _tokenStorage.clearToken();
      final errors = decoded['errors'];
      throw ApiException(
        statusCode: response.statusCode,
        message: (decoded['message'] as String?) ??
            (decoded['error'] as String?) ??
            'Upload failed.',
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

/// Describes a single binary part for [ApiClient.postMultipart]. Keeping the
/// API client free of business-specific file types means feature code owns
/// MIME-type detection and naming.
class MultipartFilePart {
  const MultipartFilePart({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final String field;
  final List<int> bytes;
  final String filename;
  final MediaType contentType;
}
