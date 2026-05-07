import '../models/backend_service_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class ServicesApi {
  ServicesApi(this._client);

  final ApiClient _client;

  Future<List<BackendService>> getServices({String? category}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '100',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    final data = _client.unwrapData(
      await _client.get('${ApiEndpoints.services}?$qs'),
    );
    final list = (data['services'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendService.fromJson)
        .toList();
  }

  Future<BackendService> getServiceById(String id) async {
    final data =
        _client.unwrapData(await _client.get(ApiEndpoints.serviceById(id)));
    return BackendService.fromJson(data);
  }
}
