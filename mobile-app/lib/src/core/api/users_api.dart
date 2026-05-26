import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/backend_worker_model.dart';
import '../models/customer_address.dart';
import '../models/user_account.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

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

  Future<List<CustomerAddress>> getSavedAddresses() async {
    final response = await _client.get(ApiEndpoints.usersMe);
    final data = _client.unwrapData(response);
    final list = (data['addresses'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerAddress.fromBackend)
        .toList();
  }

  Future<CustomerAddress> addAddress({
    String label = '',
    required String street,
    String city = '',
    String state = '',
    String zipCode = '',
    String apartment = '',
    double? lat,
    double? lng,
  }) async {
    final response = await _client.post(
      ApiEndpoints.usersMeAddresses,
      <String, dynamic>{
        'label': label.trim(),
        'street': street.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'zipCode': zipCode.trim(),
        'apartment': apartment.trim(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return CustomerAddress.fromBackend(_client.unwrapData(response));
  }

  Future<CustomerAddress> updateAddress(
    String id, {
    String label = '',
    required String street,
    String city = '',
    String state = '',
    String zipCode = '',
    String apartment = '',
    double? lat,
    double? lng,
  }) async {
    final response = await _client.patch(
      ApiEndpoints.usersMeAddress(id),
      <String, dynamic>{
        'label': label.trim(),
        'street': street.trim(),
        'city': city.trim(),
        'state': state.trim(),
        'zipCode': zipCode.trim(),
        'apartment': apartment.trim(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return CustomerAddress.fromBackend(_client.unwrapData(response));
  }

  Future<List<CustomerAddress>> setDefaultAddress(String id) async {
    final response = await _client.patch(
      '${ApiEndpoints.usersMeAddresses}/$id/default',
      <String, dynamic>{},
    );
    final data = _client.unwrapData(response);
    final list = (data as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerAddress.fromBackend)
        .toList();
  }

  Future<void> deleteAddress(String id) async {
    await _client.delete(ApiEndpoints.usersMeAddress(id));
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

  Future<void> uploadVerificationDocument({
    required String urlField,
    required String nameField,
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async {
    final uploadResp = await _client.postMultipart(
      ApiEndpoints.uploadFile,
      fields: <String, String>{'type': 'verification'},
      fileField: MultipartFilePart(
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );
    final data = _client.unwrapData(uploadResp);
    final url = (data['url'] as String?) ?? '';
    if (url.isEmpty) {
      throw const ApiException(message: 'Upload failed: server returned no URL.');
    }
    await _client.patch(ApiEndpoints.usersMe, <String, dynamic>{
      urlField: url,
      nameField: filename,
    });
  }

  Future<void> uploadPortfolioPhoto({
    required List<int> bytes,
    required String filename,
    required List<Map<String, String>> existingFiles,
    String mimeType = 'image/jpeg',
  }) async {
    final uploadResp = await _client.postMultipart(
      ApiEndpoints.uploadFile,
      fields: <String, String>{'type': 'verification'},
      fileField: MultipartFilePart(
        field: 'file',
        bytes: bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ),
    );
    final data = _client.unwrapData(uploadResp);
    final url = (data['url'] as String?) ?? '';
    if (url.isEmpty) {
      throw const ApiException(message: 'Upload failed: server returned no URL.');
    }
    final updated = <Map<String, String>>[
      ...existingFiles,
      <String, String>{'url': url, 'name': filename},
    ];
    await _client.patch(ApiEndpoints.usersMe, <String, dynamic>{
      'portfolioFiles': updated,
    });
  }

  Future<void> removePortfolioPhoto({
    required List<Map<String, String>> updatedFiles,
  }) async {
    await _client.patch(ApiEndpoints.usersMe, <String, dynamic>{
      'portfolioFiles': updatedFiles,
    });
  }

  Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    await _client.patch(ApiEndpoints.usersMeEmail, <String, dynamic>{
      'newEmail': newEmail,
      'currentPassword': currentPassword,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.patch(
      ApiEndpoints.usersMePassword,
      <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> deleteMe() async {
    await _client.delete(ApiEndpoints.usersMe);
  }
}
