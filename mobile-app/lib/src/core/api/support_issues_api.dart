import '../models/support_issue.dart';
import 'api_client.dart';
import 'api_endpoints.dart';

class SupportIssuesApi {
  SupportIssuesApi(this._client);

  final ApiClient _client;

  Future<List<SupportIssue>> getMySupportIssues({int limit = 50}) async {
    final data = _client.unwrapData(
      await _client.get('${ApiEndpoints.supportIssuesMy}?limit=$limit'),
    );
    final list = (data['issues'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SupportIssue.fromJson)
        .toList();
  }

  Future<SupportIssue> createSupportIssue({
    required String bookingId,
    required String type,
    required String description,
    List<String> evidence = const <String>[],
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.supportIssues, <String, dynamic>{
        'bookingId': bookingId,
        'type': type,
        'description': description,
        if (evidence.isNotEmpty) 'evidence': evidence,
      }),
    );
    return SupportIssue.fromJson(
      (data['issue'] as Map<String, dynamic>?) ?? data,
    );
  }
}
