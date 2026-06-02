import 'package:flutter/foundation.dart';

import '../api/disputes_api.dart';
import '../models/dispute.dart';

class DisputesProvider extends ChangeNotifier {
  DisputesProvider(this._api);

  final DisputesApi _api;

  List<Dispute> _disputes = <Dispute>[];
  bool _loading = false;
  String? _error;

  Dispute? _detail;
  bool _detailLoading = false;
  String? _detailError;

  List<Dispute> get disputes => List.unmodifiable(_disputes);
  bool get loading => _loading;
  String? get error => _error;

  Dispute? get detail => _detail;
  bool get detailLoading => _detailLoading;
  String? get detailError => _detailError;

  Future<void> loadDisputeDetail(String id) async {
    _detail = null;
    _detailError = null;
    _detailLoading = true;
    notifyListeners();
    try {
      _detail = await _api.getDisputeById(id);
    } catch (e) {
      _detailError = e.toString();
    } finally {
      _detailLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyDisputes({bool asWorker = false}) async {
    _setLoading(true);
    try {
      _disputes = asWorker
          ? await _api.getWorkerDisputes()
          : await _api.getMyDisputes();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<Dispute> openDispute({
    required String bookingId,
    required String paymentId,
    required String reason,
    required String category,
    String severity = 'medium',
    double estimatedDamages = 0,
  }) async {
    final dispute = await _api.openDispute(
      bookingId: bookingId,
      paymentId: paymentId,
      reason: reason,
      category: category,
      severity: severity,
      estimatedDamages: estimatedDamages,
    );
    _disputes = [dispute, ..._disputes];
    notifyListeners();
    return dispute;
  }

  Future<void> submitEvidence({
    required String disputeId,
    required String description,
    required List<List<int>> imageBytesList,
    required List<String> filenames,
  }) async {
    final updated = await _api.addEvidence(
      disputeId: disputeId,
      description: description,
      imageBytesList: imageBytesList,
      filenames: filenames,
    );
    _updateDispute(updated);
  }

  Future<void> appealDispute({
    required String disputeId,
    required String reason,
  }) async {
    final updated =
        await _api.appealDispute(disputeId: disputeId, reason: reason);
    _updateDispute(updated);
  }

  void _updateDispute(Dispute updated) {
    final idx = _disputes.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) {
      _disputes = List<Dispute>.from(_disputes)..[idx] = updated;
    } else {
      _disputes = [updated, ..._disputes];
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
