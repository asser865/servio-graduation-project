import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

import '../api/ai_api.dart';
import '../api/api_exception.dart';
import '../knowledge/finishing_knowledge_graph.dart';
import 'ai_performance_tracker.dart';

/// Lifecycle phases of an AI finishing run. The view picks a UI per phase;
/// no business logic lives in widgets.
enum RoomFinishingPhase {
  idle,
  uploading,
  analyzing,
  success,
  error,
}

/// Owns all state for the AI finishing model flow: the selected image,
/// the form inputs, the in-flight request, the latest response, and the
/// derived knowledge graph. Registered globally so a result survives
/// navigation away from the screen.
class RoomFinishingProvider extends ChangeNotifier {
  RoomFinishingProvider(this._api);

  final AiApi _api;

  RoomFinishingPhase _phase = RoomFinishingPhase.idle;
  RoomAnalysisResponse? _response;
  FinishingKnowledgeGraph? _graph;
  String? _errorMessage;
  int? _errorStatusCode;
  String _selectedImageName = '';
  List<int>? _selectedImageBytes;

  // ── Cancellation ────────────────────────────────────────────────────────────
  // Incremented on every new analyze() call and on cancel(). The in-flight
  // future checks this value before committing results — a mismatch means
  // the operation was superseded and its result should be discarded.
  int _operationId = 0;

  // ── Elapsed-time tracking ────────────────────────────────────────────────
  Timer? _elapsedTimer;
  DateTime? _analysisStartTime;
  int _elapsedSeconds = 0;

  // ── Last recorded timing (for callers who want raw metrics) ─────────────
  AiGenerationTiming? _lastTiming;

  // ── Public getters ───────────────────────────────────────────────────────
  RoomFinishingPhase get phase => _phase;
  RoomAnalysisResponse? get response => _response;
  FinishingKnowledgeGraph? get graph => _graph;
  String? get errorMessage => _errorMessage;
  int? get errorStatusCode => _errorStatusCode;
  String get selectedImageName => _selectedImageName;
  List<int>? get selectedImageBytes => _selectedImageBytes;
  bool get hasImage =>
      _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty;
  bool get isBusy =>
      _phase == RoomFinishingPhase.uploading ||
      _phase == RoomFinishingPhase.analyzing;
  int get elapsedSeconds => _elapsedSeconds;
  AiGenerationTiming? get lastTiming => _lastTiming;

  // ── Image helpers ────────────────────────────────────────────────────────
  void setImage({
    required List<int> bytes,
    required String filename,
  }) {
    _selectedImageBytes = bytes;
    _selectedImageName = filename;
    if (_phase == RoomFinishingPhase.error) {
      _phase = RoomFinishingPhase.idle;
      _errorMessage = null;
      _errorStatusCode = null;
    }
    notifyListeners();
  }

  void clearImage() {
    _selectedImageBytes = null;
    _selectedImageName = '';
    notifyListeners();
  }

  void reset() {
    _stopElapsedTimer();
    _phase = RoomFinishingPhase.idle;
    _response = null;
    _graph = null;
    _errorMessage = null;
    _errorStatusCode = null;
    _selectedImageBytes = null;
    _selectedImageName = '';
    _elapsedSeconds = 0;
    notifyListeners();
  }

  /// Cancels any in-flight analysis and returns to idle. The HTTP request
  /// continues in the background (the http package has no abort API), but
  /// its result will be discarded once it arrives.
  void cancel() {
    if (!isBusy) return;
    _operationId++;
    _stopElapsedTimer();
    _phase = RoomFinishingPhase.idle;
    _errorMessage = null;
    _elapsedSeconds = 0;
    notifyListeners();
  }

  // ── Main analysis flow ───────────────────────────────────────────────────
  Future<void> analyze({
    required double lengthM,
    required double widthM,
    required double heightM,
    required int budgetEgp,
    required String style,
    bool includeRender = true,
  }) async {
    final bytes = _selectedImageBytes;
    if (bytes == null || bytes.isEmpty) {
      _phase = RoomFinishingPhase.error;
      _errorMessage = 'Please pick a room photo first.';
      _errorStatusCode = null;
      notifyListeners();
      return;
    }

    // Invalidate any previous in-flight request.
    final opId = ++_operationId;

    _phase = RoomFinishingPhase.uploading;
    _errorMessage = null;
    _errorStatusCode = null;
    _response = null;
    _graph = null;
    _elapsedSeconds = 0;
    _startElapsedTimer();
    notifyListeners();

    final ext = _selectedImageName.toLowerCase().split('.').last;
    final mediaType = switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };

    final requestStartTime = DateTime.now();

    try {
      _phase = RoomFinishingPhase.analyzing;
      notifyListeners();

      final result = await _api.analyzeRoom(
        imageBytes: bytes,
        filename: _selectedImageName.isEmpty
            ? 'room.${ext.isEmpty ? 'jpg' : ext}'
            : _selectedImageName,
        contentType: mediaType,
        lengthM: lengthM,
        widthM: widthM,
        heightM: heightM,
        budgetEgp: budgetEgp,
        style: style,
        includeRender: includeRender,
      );

      // Discard stale result if user cancelled or started a new request.
      if (_operationId != opId) return;

      _stopElapsedTimer();

      final totalMs =
          DateTime.now().difference(requestStartTime).inMilliseconds;

      if (result.plans.isEmpty) {
        _recordTiming(
          startedAt: requestStartTime,
          totalMs: totalMs,
          success: false,
          errorMessage: 'empty_plans',
          payloadBytes: bytes.length,
          includeRender: includeRender,
        );
        _phase = RoomFinishingPhase.error;
        _errorMessage =
            'The AI did not return a finishing plan. Try a clearer photo.';
        notifyListeners();
        return;
      }

      _recordTiming(
        startedAt: requestStartTime,
        totalMs: totalMs,
        success: true,
        payloadBytes: bytes.length,
        includeRender: includeRender,
      );

      _response = result;
      _graph = FinishingKnowledgeGraph.fromAnalysis(result);
      _phase = RoomFinishingPhase.success;
      notifyListeners();
    } on ApiException catch (e) {
      if (_operationId != opId) return;
      _stopElapsedTimer();
      _recordTiming(
        startedAt: requestStartTime,
        totalMs: DateTime.now().difference(requestStartTime).inMilliseconds,
        success: false,
        errorMessage: e.message,
        payloadBytes: bytes.length,
        includeRender: includeRender,
      );
      _phase = RoomFinishingPhase.error;
      _errorStatusCode = e.statusCode;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      if (_operationId != opId) return;
      _stopElapsedTimer();
      _recordTiming(
        startedAt: requestStartTime,
        totalMs: DateTime.now().difference(requestStartTime).inMilliseconds,
        success: false,
        errorMessage: e.toString(),
        payloadBytes: bytes.length,
        includeRender: includeRender,
      );
      _phase = RoomFinishingPhase.error;
      _errorMessage = 'Unexpected error: $e';
      notifyListeners();
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────
  void _startElapsedTimer() {
    _analysisStartTime = DateTime.now();
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds =
          DateTime.now().difference(_analysisStartTime!).inSeconds;
      notifyListeners();
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  void _recordTiming({
    required DateTime startedAt,
    required int totalMs,
    required bool success,
    String? errorMessage,
    int? payloadBytes,
    bool includeRender = true,
  }) {
    final timing = AiGenerationTiming(
      startedAt: startedAt,
      totalMs: totalMs,
      success: success,
      errorMessage: errorMessage,
      payloadBytes: payloadBytes,
      includeRender: includeRender,
    );
    _lastTiming = timing;
    AiPerformanceTracker.instance.record(timing);
  }

  @override
  void dispose() {
    _stopElapsedTimer();
    super.dispose();
  }
}
