import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/users_api.dart';
import '../models/backend_worker_model.dart';

class WorkersProvider extends ChangeNotifier {
  WorkersProvider(ApiClient client) : _api = UsersApi(client);

  final UsersApi _api;
  List<BackendWorker> _workers = <BackendWorker>[];
  bool _loading = false;
  String? _error;

  List<BackendWorker> get workers => _workers;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchAll({String? category, String? serviceId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _workers = await _api.getWorkers(
        category: category,
        serviceId: serviceId,
      );
    } catch (e) {
      _error = 'Failed to load technicians.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  BackendWorker? findById(String id) {
    try {
      return _workers.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }
}
