import 'package:shared_preferences/shared_preferences.dart';

/// Local UI states for the technician job workflow.
///
/// [enRoute] and [arrived] are mirrored to backend statuses, while
/// [pending], [done], and [cancelled] are derived from the backend status and
/// are never written to SharedPreferences.
enum JobSection {
  /// Awaiting technician decision (backend: pending).
  pending,

  /// Job confirmed by technician; waiting to depart (backend: accepted).
  accepted,

  /// Technician is travelling to the customer (backend: en_route).
  enRoute,

  /// Technician has arrived; waiting for customer PIN (backend: arrived).
  arrived,

  /// Job active (backend: in_progress). Timer running.
  inProgress,

  /// Technician tapped "Finish Job"; showing confirmation + notes.
  completeConfirm,

  /// Worker submitted completion or job completed (backend:
  /// awaiting_customer_confirmation, pending_admin_review, completed).
  done,

  /// Job cancelled or rejected.
  cancelled,
}

/// Persists per-booking job section state and timer start time across app
/// restarts using [SharedPreferences].
///
/// Keys are scoped by booking ID so multiple concurrent jobs stay isolated.
class JobSessionService {
  JobSessionService._();

  static const String _sectionPrefix = 'servio_job_section_';
  static const String _timerPrefix = 'servio_job_timer_';

  // ── Section ───────────────────────────────────────────────────────────────

  static Future<JobSection?> getSection(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('$_sectionPrefix$bookingId');
    if (value == null) return null;
    return JobSection.values.firstWhere(
      (s) => s.name == value,
      orElse: () => JobSection.accepted,
    );
  }

  static Future<void> setSection(String bookingId, JobSection section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_sectionPrefix$bookingId', section.name);
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  /// Returns the wall-clock start time in milliseconds since epoch, or null
  /// if no timer has been started for this booking.
  static Future<int?> getTimerStart(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_timerPrefix$bookingId');
  }

  static Future<void> setTimerStart(String bookingId, int t0) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_timerPrefix$bookingId', t0);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Removes all persisted state for the given booking (called on completion).
  static Future<void> clearSession(String bookingId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sectionPrefix$bookingId');
    await prefs.remove('$_timerPrefix$bookingId');
  }
}
