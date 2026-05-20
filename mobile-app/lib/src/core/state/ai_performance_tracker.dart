import 'dart:collection';

/// Timing sample for a single AI generation run.
/// Stores only numeric metrics — no prompt text, no response content.
class AiGenerationTiming {
  const AiGenerationTiming({
    required this.startedAt,
    required this.totalMs,
    required this.success,
    this.errorMessage,
    this.payloadBytes,
    this.includeRender = true,
  });

  final DateTime startedAt;
  final int totalMs;
  final bool success;
  final String? errorMessage;
  final int? payloadBytes;
  final bool includeRender;
}

/// Lightweight in-memory store for AI generation performance metrics.
/// Singleton — no Flutter dependency; safe to call from provider layer.
/// Keeps the last [maxSamples] timings. Nothing is persisted to disk.
class AiPerformanceTracker {
  AiPerformanceTracker._();
  static final AiPerformanceTracker instance = AiPerformanceTracker._();

  static const int maxSamples = 20;

  final Queue<AiGenerationTiming> _timings = Queue<AiGenerationTiming>();

  List<AiGenerationTiming> get timings =>
      List<AiGenerationTiming>.unmodifiable(_timings);

  int get totalRequests => _timings.length;
  int get successCount => _timings.where((t) => t.success).length;
  int get failureCount => _timings.where((t) => !t.success).length;

  double get averageMs {
    if (_timings.isEmpty) return 0;
    return _timings.map((t) => t.totalMs).reduce((a, b) => a + b) /
        _timings.length;
  }

  int get fastestMs {
    if (_timings.isEmpty) return 0;
    return _timings.map((t) => t.totalMs).reduce((a, b) => a < b ? a : b);
  }

  int get slowestMs {
    if (_timings.isEmpty) return 0;
    return _timings.map((t) => t.totalMs).reduce((a, b) => a > b ? a : b);
  }

  void record(AiGenerationTiming timing) {
    _timings.addLast(timing);
    if (_timings.length > maxSamples) _timings.removeFirst();
  }

  void clear() => _timings.clear();
}
