import 'api_client.dart';
import 'api_endpoints.dart';

class EarningsSummary {
  const EarningsSummary({
    required this.totalEarnings,
    required this.pendingPayout,
    required this.completedJobs,
  });

  final double totalEarnings;
  final double pendingPayout;
  final int completedJobs;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      EarningsSummary(
        totalEarnings: ((json['totalEarnings'] as num?) ?? 0).toDouble(),
        pendingPayout: ((json['pendingPayout'] as num?) ?? 0).toDouble(),
        completedJobs: ((json['completedJobs'] as num?) ?? 0).toInt(),
      );
}

class PaymentsApi {
  PaymentsApi(this._client);

  final ApiClient _client;

  Future<EarningsSummary> getEarnings({String period = 'all'}) async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentEarnings(period)),
    );
    return EarningsSummary.fromJson(data);
  }
}
