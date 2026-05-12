import 'api_client.dart';
import 'api_endpoints.dart';

class EarningsSummary {
  const EarningsSummary({
    required this.totalEarnings,
    required this.pendingPayout,
    required this.completedJobs,
    required this.payoutMethod,
    required this.payoutSchedule,
    this.bankName,
    this.accountHolder,
    this.accountNumber,
    this.walletNumber,
  });

  final double totalEarnings;
  final double pendingPayout;
  final int completedJobs;
  final String payoutMethod;
  final String payoutSchedule;
  final String? bankName;
  final String? accountHolder;
  final String? accountNumber;
  final String? walletNumber;

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    final wallet = json['wallet'] as Map<String, dynamic>? ?? {};
    final details = wallet['payoutDetails'] as Map<String, dynamic>? ?? {};

    return EarningsSummary(
      totalEarnings: ((wallet['totalEarned'] as num?) ?? 0).toDouble(),
      pendingPayout: ((wallet['pendingBalance'] as num?) ?? 0).toDouble(),
      completedJobs: ((json['completedJobs'] as num?) ?? 0).toInt(),
      payoutMethod: wallet['payoutMethod'] as String? ?? 'bank',
      payoutSchedule: wallet['payoutSchedule'] as String? ?? 'weekly',
      bankName: details['bankName'] as String?,
      accountHolder: details['accountHolder'] as String?,
      accountNumber: details['accountNumber'] as String?,
      walletNumber: details['walletNumber'] as String?,
    );
  }
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

  Future<void> updateSettings({
    required String payoutMethod,
    required String payoutSchedule,
    required Map<String, dynamic> payoutDetails,
  }) async {
    await _client.patch(
      ApiEndpoints.paymentSettings,
      {
        'payoutMethod': payoutMethod,
        'payoutSchedule': payoutSchedule,
        'payoutDetails': payoutDetails,
      },
    );
  }
}
