import 'package:flutter/foundation.dart';

import '../api/disputes_api.dart';
import '../api/support_issues_api.dart';
import '../models/dispute.dart';
import '../models/support_issue.dart';

enum SupportTab { active, disputes, resolved }

class SupportStats {
  const SupportStats({
    required this.openIssues,
    required this.openDisputes,
    required this.resolvedCases,
  });

  final int openIssues;
  final int openDisputes;
  final int resolvedCases;
}

class SupportProvider extends ChangeNotifier {
  SupportProvider({
    required SupportIssuesApi issuesApi,
    required DisputesApi disputesApi,
  })  : _issuesApi = issuesApi,
        _disputesApi = disputesApi;

  final SupportIssuesApi _issuesApi;
  final DisputesApi _disputesApi;

  List<SupportIssue> _issues = <SupportIssue>[];
  List<Dispute> _disputes = <Dispute>[];

  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  bool _loaded = false;

  SupportTab _activeTab = SupportTab.active;

  // ── Getters ──────────────────────────────────────────────────────────────

  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  bool get loaded => _loaded;
  SupportTab get activeTab => _activeTab;
  List<Dispute> get disputes => _disputes;

  // Filtering exactly mirrors website renderSupportCases() logic:
  // active  → open issues (status NOT in [resolved, closed])
  // disputes→ ALL disputes
  // resolved→ resolved issues + resolved disputes

  List<SupportIssue> get openIssues =>
      _issues.where((i) => i.isOpen).toList();

  List<Dispute> get openDisputes => _disputes.where((d) {
        const activeStatuses = <String>{
          'open',
          'reviewing',
          'awaiting_evidence',
          'appealed',
          'escalated',
        };
        return activeStatuses.contains(d.status);
      }).toList();

  List<SupportIssue> get resolvedIssues =>
      _issues.where((i) => i.isResolved).toList();

  List<Dispute> get resolvedDisputes =>
      _disputes.where((d) => (d.status).startsWith('resolved_')).toList();

  SupportStats get stats => SupportStats(
        openIssues: openIssues.length,
        openDisputes: openDisputes.length,
        resolvedCases: resolvedIssues.length + resolvedDisputes.length,
      );

  int get badgeCount => openIssues.length + openDisputes.length;

  /// Items to display for the currently active tab.
  ({List<SupportIssue> issues, List<Dispute> disputes}) get tabItems {
    return switch (_activeTab) {
      SupportTab.active => (issues: openIssues, disputes: <Dispute>[]),
      SupportTab.disputes => (issues: <SupportIssue>[], disputes: _disputes),
      SupportTab.resolved => (issues: resolvedIssues, disputes: resolvedDisputes),
    };
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void setTab(SupportTab tab) {
    if (_activeTab == tab) return;
    _activeTab = tab;
    notifyListeners();
  }

  Future<void> load({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    if (_loading) return;

    if (_loaded && forceRefresh) {
      _refreshing = true;
      notifyListeners();
    } else {
      _loading = true;
      notifyListeners();
    }

    try {
      final results = await Future.wait(<Future<dynamic>>[
        _issuesApi.getMySupportIssues(limit: 50),
        _disputesApi.getMyDisputes(),
      ]);
      _issues = results[0] as List<SupportIssue>;
      _disputes = results[1] as List<Dispute>;
      _error = null;
      _loaded = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  /// Prepend a newly created issue (optimistic UI).
  void addIssue(SupportIssue issue) {
    _issues = <SupportIssue>[issue, ..._issues];
    notifyListeners();
  }

  Future<SupportIssue> createIssue({
    required String bookingId,
    required String type,
    required String description,
    List<String> evidence = const <String>[],
  }) async {
    final issue = await _issuesApi.createSupportIssue(
      bookingId: bookingId,
      type: type,
      description: description,
      evidence: evidence,
    );
    addIssue(issue);
    return issue;
  }
}
