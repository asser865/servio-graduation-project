import 'api_client.dart';
import 'api_endpoints.dart';

class ProblemReportApi {
  ProblemReportApi(this._client);

  final ApiClient _client;

  Future<void> submitReport({
    required String category,
    required String description,
    String screenshotUrl = '',
  }) async {
    await _client.post(ApiEndpoints.problemReports, <String, dynamic>{
      'category': category,
      'description': description,
      if (screenshotUrl.isNotEmpty) 'screenshotUrl': screenshotUrl,
    });
  }
}
