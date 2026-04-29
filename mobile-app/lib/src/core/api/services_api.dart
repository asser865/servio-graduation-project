import 'api_client.dart';

class ServicesApi {
  ServicesApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getServices({
    String? category,
    int page = 1,
    int limit = 100,
  }) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (category != null && category.isNotEmpty) 'category': category,
      },
    ).query;
    return _client.unwrapData(await _client.get('/services?$qs'));
  }
}
