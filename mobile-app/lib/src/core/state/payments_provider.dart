import 'package:flutter/foundation.dart';

import '../api/payments_api.dart';
import '../models/cash_debt.dart';
import '../models/customer_credit.dart';
import '../models/invoice.dart';
import '../models/payout_request.dart';

class PaymentsProvider extends ChangeNotifier {
  PaymentsProvider(this._api);

  final PaymentsApi _api;

  PaymentsApi get api => _api;

  // ── Worker state ─────────────────────────────────────────────────────────

  EarningsSummary? _earnings;
  CashDebtSummary? _debtSummary;
  List<PayoutRequest> _payouts = <PayoutRequest>[];

  EarningsSummary? get earnings => _earnings;
  CashDebtSummary? get debtSummary => _debtSummary;
  List<PayoutRequest> get payouts => List.unmodifiable(_payouts);

  bool get cashBookingsBlocked => _debtSummary?.isBlocked ?? false;

  // ── Customer state ────────────────────────────────────────────────────────

  List<CustomerCredit> _credits = <CustomerCredit>[];
  List<Invoice> _invoices = <Invoice>[];

  List<CustomerCredit> get credits => List.unmodifiable(_credits);
  List<Invoice> get invoices => List.unmodifiable(_invoices);

  double get totalCreditBalance => _api.totalCreditBalance(_credits);

  // ── Loading / error ────────────────────────────────────────────────────────

  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  // ── Worker actions ────────────────────────────────────────────────────────

  Future<void> loadEarnings({String period = 'all'}) async {
    _setLoading(true);
    try {
      _earnings = await _api.getEarnings(period: period);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDebtSummary() async {
    _setLoading(true);
    try {
      _debtSummary = await _api.getMyDebts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPayouts() async {
    _setLoading(true);
    try {
      _payouts = await _api.getMyPayouts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> settleDebtsWithWallet(List<String> debtIds) async {
    await _api.settleDebtsWithWallet(debtIds);
    await loadDebtSummary();
  }

  Future<PayoutRequest> requestPayout({
    required double amount,
    required String payoutMethod,
    required Map<String, dynamic> payoutDetails,
  }) async {
    final req = await _api.requestPayout(
      amount: amount,
      payoutMethod: payoutMethod,
      payoutDetails: payoutDetails,
    );
    _payouts = [req, ..._payouts];
    notifyListeners();
    return req;
  }

  // ── Customer actions ──────────────────────────────────────────────────────

  Future<void> loadCredits() async {
    _setLoading(true);
    try {
      _credits = await _api.getMyCredits();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadInvoices() async {
    _setLoading(true);
    try {
      _invoices = await _api.getMyInvoices();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  String receiptUrl(String paymentId) => _api.receiptUrl(paymentId);

  // ── Internal ──────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
