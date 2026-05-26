import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/backend_booking_model.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class BookingsApi {
  BookingsApi(this._client);

  final ApiClient _client;

  Future<List<BackendBooking>> getMyBookings({String? status}) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '200',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final data = _client.unwrapData(
      await _client.get('${ApiEndpoints.myBookings}?$qs'),
    );
    final list = (data['bookings'] as List<dynamic>?) ??
        (data['data'] as List<dynamic>?) ??
        <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(BackendBooking.fromJson)
        .toList();
  }

  Future<List<BackendBooking>> getWorkerBookings({
    String? status,
    String? workerId,
  }) async {
    final qs = Uri(
      queryParameters: <String, String>{
        'limit': '50',
        if (status != null && status.isNotEmpty) 'status': status,
        if (workerId != null && workerId.trim().isNotEmpty)
          'workerId': workerId.trim(),
      },
    ).query;
    final path = '${ApiEndpoints.workerBookings}?$qs';
    final data = _client.unwrapData(
      await _client.get(path),
    );
    final list = _bookingListFrom(data);
    final bookings = list
        .whereType<Map<String, dynamic>>()
        .map(BackendBooking.fromJson)
        .toList();
    return bookings;
  }

  Future<BackendBooking> createBooking({
    required String workerId,
    String serviceId = '',
    String serviceCategory = '',
    String serviceName = '',
    required DateTime scheduledDate,
    required String scheduledTime,
    String address = '',
    String addressCity = '',
    String addressStreet = '',
    String notes = '',
    String paymentMethod = 'cash',
    String? savedCardId,
  }) async {
    final resolvedAddress = address.trim().isNotEmpty
        ? address.trim()
        : <String>[addressStreet, addressCity]
            .where((part) => part.trim().isNotEmpty)
            .join(', ');

    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.bookings, <String, dynamic>{
        'workerId': workerId,
        if (serviceId.trim().isNotEmpty) 'serviceId': serviceId.trim(),
        if (serviceId.trim().isEmpty && serviceCategory.trim().isNotEmpty)
          'serviceCategory': serviceCategory.trim(),
        if (serviceName.trim().isNotEmpty) 'serviceName': serviceName.trim(),
        'scheduledDate': _dateOnly(scheduledDate),
        'scheduledTime': _normalizeScheduledTime(scheduledTime),
        'address': resolvedAddress,
        'paymentMethod': paymentMethod,
        if (savedCardId != null && savedCardId.trim().isNotEmpty)
          'savedCardId': savedCardId.trim(),
        if (notes.trim().isNotEmpty) 'description': notes.trim(),
      }),
    );
    return BackendBooking.fromJson(data);
  }

  Future<void> updateStatus(
    String bookingId,
    String status, {
    String? notes,
    String? reason,
  }) async {
    await _client
        .patch(ApiEndpoints.bookingStatus(bookingId), <String, dynamic>{
      'status': status,
      if (notes != null && notes.isNotEmpty) 'workerNotes': notes,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  Future<void> confirmCompletion(String bookingId) async {
    await _client.patch(
      ApiEndpoints.bookingStatus(bookingId),
      <String, dynamic>{'status': 'completed'},
    );
  }

  /// Start a job using the customer's verification PIN.
  /// Backend: POST /bookings/:id/start  { pin: "..." }
  Future<void> startJob(String bookingId, String pin) async {
    await _client.post(
      ApiEndpoints.bookingStart(bookingId),
      <String, dynamic>{'pin': pin},
    );
  }

  /// Report that a customer was absent. Requires a photo as proof.
  /// Backend: POST /bookings/:id/no-show/customer (multipart)
  Future<void> reportCustomerNoShow({
    required String bookingId,
    required String details,
    required List<int> photoBytes,
    required String photoFilename,
  }) async {
    await _client.postMultipart(
      ApiEndpoints.bookingNoShowCustomer(bookingId),
      fields: {'details': details},
      fileField: MultipartFilePart(
        field: 'evidence',
        bytes: photoBytes,
        filename: photoFilename,
        contentType: MediaType('image', 'jpeg'),
      ),
    );
  }

  Future<BackendBooking> getBooking(String id) async {
    final data =
        _client.unwrapData(await _client.get(ApiEndpoints.bookingById(id)));
    return BackendBooking.fromJson(data);
  }

  Future<List<String>> getWorkerBookedSlots({
    required String workerId,
    required String date,
  }) async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.workerBookedSlots(workerId, date)),
    );
    final slots = (data['bookedSlots'] as List<dynamic>?) ?? <dynamic>[];
    return slots.whereType<String>().toList();
  }

  /// Accepts a pending booking. Optionally sets estimated duration in minutes (15–480).
  Future<void> acceptBooking(String bookingId, {int? estimatedDurationMin}) async {
    final body = <String, dynamic>{};
    if (estimatedDurationMin != null) {
      body['estimatedDurationMin'] = estimatedDurationMin;
    }
    await _client.post(ApiEndpoints.bookingAccept(bookingId), body);
  }

  /// Marks job complete (in_progress → awaiting_customer_confirmation).
  /// If [imageBytes] provided, uploads image first to get URL.
  /// [workerNotes] max 400 chars.
  Future<void> completeJobWithImage({
    required String bookingId,
    String? workerNotes,
    List<int>? imageBytes,
    String? imageFilename,
  }) async {
    String? imageUrl;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uploadResp = await _client.postMultipart(
        ApiEndpoints.uploadFile,
        fields: {'type': 'completion'},
        fileField: MultipartFilePart(
          field: 'file',
          bytes: imageBytes,
          filename: imageFilename ?? 'completion.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        timeoutOverride: const Duration(seconds: 60),
      );
      imageUrl = (uploadResp['url'] as String?) ??
          (_client.unwrapData(uploadResp)['url'] as String?);
    }

    final body = <String, dynamic>{
      'status': 'awaiting_customer_confirmation',
      if (workerNotes != null && workerNotes.isNotEmpty)
        'workerNotes': workerNotes,
      if (imageUrl != null) 'workerCompletionImages': [imageUrl],
    };
    await _client.patch(ApiEndpoints.bookingStatus(bookingId), body);
  }

  /// Updates the estimated duration while a job is in-progress (no status change).
  /// [estimatedDurationMin] must be between 15 and 480.
  Future<void> updateEstimate(String bookingId, int estimatedDurationMin) async {
    await _client.patch(ApiEndpoints.bookingStatus(bookingId), <String, dynamic>{
      'status': 'in_progress',
      'estimatedDurationMin': estimatedDurationMin,
    });
  }
}

String _dateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _normalizeScheduledTime(String value) {
  final trimmed = value.trim();
  final hourMatch =
      RegExp(r'(\d{1,2})(?::\d{2})?\s*(AM|PM)?', caseSensitive: false)
          .firstMatch(trimmed);
  if (hourMatch == null) return '10:00';

  var hour = int.tryParse(hourMatch.group(1) ?? '') ?? 10;
  final meridiem = hourMatch.group(2)?.toUpperCase();
  if (meridiem == 'PM' && hour < 12) hour += 12;
  if (meridiem == 'AM' && hour == 12) hour = 0;
  hour = hour.clamp(0, 23).toInt();
  return '${hour.toString().padLeft(2, '0')}:00';
}

List<dynamic> _bookingListFrom(Map<String, dynamic> data) {
  for (final key in <String>['bookings', 'data', 'items', 'results']) {
    final value = data[key];
    if (value is List<dynamic>) return value;
    if (value is Map<String, dynamic>) {
      final nested = _bookingListFrom(value);
      if (nested.isNotEmpty) return nested;
    }
  }
  return const <dynamic>[];
}
