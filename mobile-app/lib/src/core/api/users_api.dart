import '../models/backend_worker_model.dart';
import '../models/user_account.dart';
import 'api_client.dart';

class UsersApi {
  UsersApi(this._client);

  final ApiClient _client;

  Future<List<BackendWorker>> getWorkers({String? category}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/users/workers?$qs'));
    final list = (data['workers'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendWorker.fromJson)
        .toList();
  }

  Future<BackendWorker> getWorkerById(String id) async {
    final data = _client.unwrapData(await _client.get('/users/workers/$id'));
    final worker = data['worker'];
    if (worker is Map<String, dynamic>) return BackendWorker.fromJson(worker);
    return BackendWorker.fromJson(data);
  }

  Future<void> updateAvailability(Map<String, dynamic> availability) async {
    await _client.patch('/users/me/availability', availability);
  }

  Future<UserAccount> updateProfile(Map<String, dynamic> fields) async {
    final response = await _client.patch('/users/me', fields);
    return UserAccount.fromBackend(_client.unwrapData(response));
  }

  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    await _client.patch('/users/me/email', <String, dynamic>{
      'newEmail': newEmail,
      'currentPassword': currentPassword,
    });
  }
}
