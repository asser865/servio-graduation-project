import 'package:http_parser/http_parser.dart' show MediaType;

import '../models/cash_debt.dart';
import '../models/customer_credit.dart';
import '../models/debt_settlement.dart';
import '../models/invoice.dart';
import '../models/payout_request.dart';
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

  // ── Existing ──────────────────────────────────────────────────────────────

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

  // ── Cash Debts ────────────────────────────────────────────────────────────

  Future<CashDebtSummary> getMyDebts() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentMyDebts),
    );
    return CashDebtSummary.fromJson(data);
  }

  Future<void> settleDebtsWithWallet(List<String> debtIds) async {
    await _client.post(ApiEndpoints.paymentSettleDebts, {
      'method': 'wallet',
      'debtIds': debtIds,
    });
  }

  Future<DebtSettlement> settleDebtsManually({
    required List<String> debtIds,
    required String method,
    required String reference,
    required List<int> proofBytes,
    required String proofFilename,
  }) async {
    final data = _client.unwrapData(
      await _client.postMultipart(
        ApiEndpoints.paymentSettleDebts,
        fields: {
          'method': method,
          'reference': reference,
          'debtIds': debtIds.join(','),
        },
        fileField: MultipartFilePart(
          field: 'proof',
          bytes: proofBytes,
          filename: proofFilename,
          contentType: MediaType('image', 'jpeg'),
        ),
      ),
    );
    return DebtSettlement.fromJson(
        (data['settlement'] as Map<String, dynamic>?) ?? data);
  }

  Future<List<DebtSettlement>> getMySettlements() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentMySettlements),
    );
    final list = (data['settlements'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DebtSettlement.fromJson)
        .toList();
  }

  // ── Payouts ───────────────────────────────────────────────────────────────

  Future<PayoutRequest> requestPayout({
    required double amount,
    required String payoutMethod,
    required Map<String, dynamic> payoutDetails,
  }) async {
    final data = _client.unwrapData(
      await _client.post(ApiEndpoints.paymentPayoutRequest, {
        'amount': amount,
        'payoutMethod': payoutMethod,
        'payoutDetails': payoutDetails,
      }),
    );
    return PayoutRequest.fromJson(
        (data['payoutRequest'] as Map<String, dynamic>?) ?? data);
  }

  Future<List<PayoutRequest>> getMyPayouts() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentMyPayouts),
    );
    final list = (data['payouts'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PayoutRequest.fromJson)
        .toList();
  }

  // ── Credits ───────────────────────────────────────────────────────────────

  Future<List<CustomerCredit>> getMyCredits() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentMeCredits),
    );
    final list = (data['credits'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CustomerCredit.fromJson)
        .toList();
  }

  double totalCreditBalance(List<CustomerCredit> credits) =>
      credits.where((c) => c.isValid).fold(0, (s, c) => s + c.balanceRemaining);

  // ── Invoices ──────────────────────────────────────────────────────────────

  Future<List<Invoice>> getMyInvoices() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.paymentMeInvoices),
    );
    final list = (data['invoices'] as List<dynamic>?) ?? <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Invoice.fromJson)
        .toList();
  }

  String receiptUrl(String paymentId) =>
      '${_client.baseUrl}${ApiEndpoints.paymentReceipt(paymentId)}';
}
