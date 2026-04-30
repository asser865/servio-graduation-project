import '../models/backend_booking_model.dart';
import 'api_client.dart';

class BookingsApi {
  BookingsApi(this._client);

  final ApiClient _client;

  Future<List<BackendBooking>> getMyBookings({String? status}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/bookings/my?$qs'));
    final list = (data['bookings'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(BackendBooking.fromJson).toList();
  }

  Future<List<BackendBooking>> getWorkerBookings({String? status}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final data = _client.unwrapData(await _client.get('/bookings/worker?$qs'));
    final list = (data['bookings'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list.whereType<Map<String, dynamic>>().map(BackendBooking.fromJson).toList();
  }

  Future<BackendBooking> createBooking({
    required String workerId,
    required String serviceId,
    required DateTime scheduledDate,
    required String addressCity,
    required String addressStreet,
    String notes = '',
  }) async {
    final data = _client.unwrapData(
      await _client.post('/bookings', <String, dynamic>{
        'workerId': workerId,
        'serviceId': serviceId,
        'scheduledDate': scheduledDate.toIso8601String(),
        'address': <String, dynamic>{
          'city': addressCity,
          'street': addressStreet,
        },
        if (notes.isNotEmpty) 'notes': notes,
      }),
    );
    return BackendBooking.fromJson(data);
  }

  Future<void> updateStatus(String bookingId, String status) async {
    await _client.patch('/bookings/$bookingId/status', <String, dynamic>{
      'status': status,
    });
  }

  Future<BackendBooking> getBooking(String id) async {
    final data = _client.unwrapData(await _client.get('/bookings/$id'));
    return BackendBooking.fromJson(data);
  }
}
