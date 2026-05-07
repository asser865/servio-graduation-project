import '../models/backend_worker_model.dart';
import '../models/user_account.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class UsersApi {
  UsersApi(this._client);

  final ApiClient _client;

  Future<List<BackendWorker>> getWorkers({
    String? category,
    String? serviceId,
  }) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (serviceId != null && serviceId.isNotEmpty) 'serviceId': serviceId,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    final data = _client.unwrapData(
      await _client.get('${ApiEndpoints.workers}?$qs'),
    );
    final list = (data['workers'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendWorker.fromJson)
        .toList();
  }

  Future<BackendWorker> getWorkerById(String id) async {
    final data =
        _client.unwrapData(await _client.get(ApiEndpoints.workerById(id)));
    final worker = data['worker'];
    if (worker is Map<String, dynamic>) return BackendWorker.fromJson(worker);
    return BackendWorker.fromJson(data);
  }

  Future<UserAccount> getMe() async {
    final response = await _client.get(ApiEndpoints.usersMe);
    return UserAccount.fromBackend(_client.unwrapData(response));
  }

  Future<UserAccount> updateAvailability(
    List<AvailabilitySlot> availability,
  ) async {
    final response = await _client.patch(
      ApiEndpoints.usersMeAvailability,
      <String, dynamic>{
        'availability': availability.map((slot) => slot.toJson()).toList(),
      },
    );
    return UserAccount.fromBackend(_client.unwrapData(response));
  }

  Future<bool> updateAvailableNow(bool isAvailable) async {
    final response = await _client.patch(
      ApiEndpoints.usersMeAvailable,
      <String, dynamic>{'isAvailable': isAvailable},
    );
    final data = _client.unwrapData(response);
    return (data['isAvailable'] as bool?) ?? isAvailable;
  }

  Future<List<String>> toggleBlockedDate(String date) async {
    final response = await _client.patch(
      ApiEndpoints.usersMeBlockedDates,
      <String, dynamic>{'date': date},
    );
    final data = _client.unwrapData(response);
    return ((data['blockedDates'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  Future<UserAccount> updateProfile(Map<String, dynamic> fields) async {
    final response = await _client.patch(ApiEndpoints.usersMe, fields);
    return UserAccount.fromBackend(_client.unwrapData(response));
  }

  Future<void> deleteMe() async {
    await _client.delete(ApiEndpoints.usersMe);
  }
}
