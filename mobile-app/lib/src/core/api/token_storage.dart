import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/storage_service.dart';

abstract class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clearToken();
}

class FlutterSecureTokenStorage implements TokenStorage {
  FlutterSecureTokenStorage({
    FlutterSecureStorage? secureStorage,
    StorageService? legacyStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _legacyStorage = legacyStorage;

  static const String _tokenKey = StorageService.keyAuthToken;

  final FlutterSecureStorage _secureStorage;
  final StorageService? _legacyStorage;

  @override
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
    await _legacyStorage?.removeSecureString(_tokenKey);
  }

  @override
  Future<String?> getToken() async {
    final secureToken = await _secureStorage.read(key: _tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) return secureToken;

    final legacyToken = await _legacyStorage?.getSecureString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await saveToken(legacyToken);
      return legacyToken;
    }
    return null;
  }

  @override
  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
    await _legacyStorage?.removeSecureString(_tokenKey);
  }
}

class StorageBackedTokenStorage implements TokenStorage {
  StorageBackedTokenStorage(this._storage);

  static const String _tokenKey = StorageService.keyAuthToken;

  final StorageService _storage;

  @override
  Future<void> saveToken(String token) =>
      _storage.setSecureString(_tokenKey, token);

  @override
  Future<String?> getToken() => _storage.getSecureString(_tokenKey);

  @override
  Future<void> clearToken() => _storage.removeSecureString(_tokenKey);
}
