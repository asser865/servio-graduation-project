import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for one-time feature tutorials.
///
/// Decoupled from [StorageService] (which is constructor-injected into
/// providers) so first-run UI can read/write the flag directly without
/// extra provider plumbing. `shared_preferences` is a process singleton.
class TutorialPrefs {
  TutorialPrefs._();

  static const String smartMatchKey = 'servio_tutorial_smart_match_done_v1';

  static Future<bool> isDone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> markDone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  /// Manual reset hook — lets the tutorial be shown again (e.g. from a debug
  /// menu or "replay tutorial" action).
  static Future<void> reset(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
