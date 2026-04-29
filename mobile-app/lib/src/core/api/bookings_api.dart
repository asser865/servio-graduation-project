import 'api_client.dart';

class BookingsApi {
  BookingsApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getMyBookings({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'page': '$page',
        'limit': '$limit',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    return _client.unwrapData(await _client.get('/bookings/my?$qs'));
  }
}
