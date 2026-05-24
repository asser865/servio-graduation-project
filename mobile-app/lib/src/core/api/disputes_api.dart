import '../models/dispute.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

class DisputesApi {
  DisputesApi(this._client);

  final ApiClient _client;

  Future<Dispute> openDispute({
    required String bookingId,
    required String paymentId,
    required String reason,
    required String category,
    String severity = 'medium',
    double estimatedDamages = 0,
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.disputes, <String, dynamic>{
        'bookingId': bookingId,
        'paymentId': paymentId,
        'reason': reason,
        'category': category,
        'severity': severity,
        if (estimatedDamages > 0) 'estimatedDamages': estimatedDamages,
      }),
    );
    return Dispute.fromJson(
        (data['dispute'] as Map<String, dynamic>?) ?? data);
  }

  Future<List<Dispute>> getMyDisputes() async {
    final data =
        _client.unwrapData(await _client.get(ApiEndpoints.disputesMy));
    final list = (data['disputes'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Dispute.fromJson)
        .toList();
  }

  Future<List<Dispute>> getWorkerDisputes() async {
    final data = _client
        .unwrapData(await _client.get(ApiEndpoints.disputesWorkerMine));
    final list = (data['disputes'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Dispute.fromJson)
        .toList();
  }

  Future<Dispute> addEvidence({
    required String disputeId,
    required String description,
    required List<List<int>> imageBytesList,
    required List<String> filenames,
  }) async {
    // Step 1: upload each file as raw binary to /uploads?kind=dispute
    final uploaded = <Map<String, dynamic>>[];
    for (var i = 0; i < imageBytesList.length; i++) {
      final mime = _mimeFromFilename(filenames[i]);
      final res = _client.unwrapData(
        await _client.postRaw(
          '/uploads',
          bytes: imageBytesList[i],
          contentType: mime,
          queryParams: {'kind': 'dispute', 'filename': filenames[i]},
          timeoutOverride: const Duration(seconds: 60),
        ),
      );
      final url = (res['url'] as String?) ?? '';
      if (url.isNotEmpty) {
        uploaded.add(<String, dynamic>{
          'url': url,
          'name': filenames[i],
          'mime': mime,
          'size': imageBytesList[i].length,
        });
      }
    }

    if (uploaded.isEmpty) {
      throw const ApiException(message: 'No files were uploaded successfully.');
    }

    // Step 2: register URLs with the dispute
    final data = _client.unwrapData(
      await _client.post(
        ApiEndpoints.disputeEvidence(disputeId),
        <String, dynamic>{'files': uploaded},
      ),
    );
    return Dispute.fromJson(
        (data['dispute'] as Map<String, dynamic>?) ?? data);
  }

  static String _mimeFromFilename(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<Dispute> getDisputeById(String id) async {
    final data = _client
        .unwrapData(await _client.get(ApiEndpoints.disputePartyById(id)));
    return Dispute.fromJson(
        (data['dispute'] as Map<String, dynamic>?) ?? data);
  }

  Future<Dispute> appealDispute({
    required String disputeId,
    required String reason,
  }) async {
    final data = _client.unwrapData(
      await _client.post(
        ApiEndpoints.disputeAppeal(disputeId),
        <String, dynamic>{'appealReason': reason},
      ),
    );
    return Dispute.fromJson(
        (data['dispute'] as Map<String, dynamic>?) ?? data);
  }
}
