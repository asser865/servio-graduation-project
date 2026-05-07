import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;

  static const String keyAuthToken = 'servio_auth_token';

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // ── String ────────────────────────────────────────────────
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  // ── Bool ──────────────────────────────────────────────────
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  // ── JSON map ──────────────────────────────────────────────
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  // ── JSON list ─────────────────────────────────────────────
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  // ── Legacy token helpers.
  // Runtime JWT storage now goes through TokenStorage/flutter_secure_storage.
  Future<String?> getSecureString(String key) async => _prefs.getString(key);
  Future<void> setSecureString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> removeSecureString(String key) => _prefs.remove(key);

  // ── Remove ────────────────────────────────────────────────
  Future<void> remove(String key) => _prefs.remove(key);
}
