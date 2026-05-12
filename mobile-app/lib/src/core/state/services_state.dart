import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/services_api.dart';
import '../models/backend_service_model.dart';
import '../models/service_category.dart';

class ServicesProvider extends ChangeNotifier {
  ServicesProvider(ApiClient client) : _api = ServicesApi(client);

  final ServicesApi _api;
  List<BackendService> _services = <BackendService>[];
  bool _loading = false;
  String? _error;

  List<BackendService> get services => _services;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchAll({String? category}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _services = await _api.getServices(category: category);
    } catch (e) {
      _error = 'Failed to load services.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  BackendService? findById(String id) {
    try {
      return _services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  BackendService? findFirstByCategory(String category) {
    final normalized = normalizeServiceCategory(category);
    if (normalized.isEmpty) return null;
    try {
      return _services.firstWhere(
        (s) => normalizeServiceCategory(s.category) == normalized,
      );
    } catch (_) {
      return null;
    }
  }
}
