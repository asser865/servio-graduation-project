import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/bookings_api.dart';
import '../models/app_notification.dart';
import '../models/backend_booking_model.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';

// ── Storage keys ─────────────────────────────────────────────────────────────
const String _kReadIdsKey = 'servio_notif_read_ids';

/// Snapshot of `{bookingId: lastKnownStatus}` used for change-detection.
/// Matches the website's `servio_booking_snapshot` localStorage pattern.
const String _kSnapshotKey = 'servio_booking_snapshot';

/// Derives a real notification feed from the user's booking history.
///
/// ## Why no dedicated backend?
/// The backend `/notify` module is an **email-subscription** system, not an
/// in-app inbox.  There is no `GET /notifications` endpoint, no server-side
/// read/unread state, and no socket events for booking changes.
///
/// ## What this provider does instead:
/// 1. Fetches the user's bookings (`GET /bookings/my` or `/bookings/worker`).
/// 2. Converts each unique (bookingId × status) pair into an [AppNotification].
/// 3. Persists read IDs in [SharedPreferences] so badge resets survive restarts.
///
/// ## What this provider CANNOT do (requires backend changes):
/// - Cross-device read sync        → needs `PATCH /notifications/:id/read`
/// - Payment-release notifications → needs booking payment events
/// - Real-time push                → needs Socket.IO emission in booking controller
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._storage, this._client);

  final StorageService _storage;
  final ApiClient _client;

  List<AppNotification> _notifications = <AppNotification>[];
  bool _loading = false;
  String? _error;

  // ── Public state ─────────────────────────────────────────────────────────────

  List<AppNotification> get notifications => _notifications;
  bool get loading => _loading;
  String? get error => _error;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  List<AppNotification> get bookingNotifications => _notifications
      .where((n) => n.type == AppNotificationType.booking)
      .toList();

  List<AppNotification> get paymentNotifications => _notifications
      .where((n) => n.type == AppNotificationType.payment)
      .toList();

  List<AppNotification> get systemNotifications => _notifications
      .where((n) => n.type == AppNotificationType.system)
      .toList();

  // ── Fetch ─────────────────────────────────────────────────────────────────────

  /// Fetches real bookings and rebuilds the notification feed.
  ///
  /// Uses a snapshot-diff strategy that matches the website behaviour:
  /// 1. Load the previous snapshot `{bookingId: lastKnownStatus}`.
  /// 2. Fetch current bookings from the API.
  /// 3. A notification is **unread** only if its status differs from the
  ///    snapshot (i.e. it represents a genuine status change).
  /// 4. On first load (empty snapshot) all notifications are marked read so
  ///    a fresh install doesn't flood the inbox with historical entries.
  /// 5. Save the current states as the new snapshot.
  ///
  /// Pass [role] to use the correct API endpoint.
  Future<void> refresh(
      {UserRole role = UserRole.customer, String? workerId}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final bookingsApi = BookingsApi(_client);
      final List<BackendBooking> bookings;

      if (role == UserRole.technician && workerId != null) {
        bookings = await bookingsApi.getWorkerBookings(workerId: workerId);
      } else {
        bookings = await bookingsApi.getMyBookings();
      }

      final readIds = _loadReadIds();
      final snapshot = _loadSnapshot();
      final isFirstLoad = snapshot.isEmpty;

      final feed = <AppNotification>[];
      for (final booking in bookings) {
        final entry = _toNotification(booking, readIds, snapshot, isFirstLoad);
        if (entry != null) feed.add(entry);
      }

      // Sort newest first (by booking scheduled date as a proxy — backend
      // does not return a notification timestamp).
      feed.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Persist the new snapshot so the next refresh can detect changes.
      _saveSnapshot({for (final b in bookings) b.id: b.status});

      _notifications = feed;
      _error = null;
      _log('Loaded ${feed.length} notifications, ${_unreadIn(feed)} unread '
          '(first-load: $isFirstLoad).');
    } catch (e) {
      _error = 'Could not load notifications. Pull down to retry.';
      _log('Error fetching notifications: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Read state ────────────────────────────────────────────────────────────────

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    _notifications = List<AppNotification>.from(_notifications)
      ..[idx] = _notifications[idx].copyWith(isRead: true);
    _persistReadId(id);
    notifyListeners();
  }

  void markAllRead() {
    final ids = <String>[];
    _notifications = _notifications.map((n) {
      if (!n.isRead) {
        ids.add(n.id);
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    if (ids.isNotEmpty) {
      _persistReadIds(ids);
      notifyListeners();
    }
  }

  // ── Persistence helpers ───────────────────────────────────────────────────────

  Set<String> _loadReadIds() {
    final raw = _storage.getString(_kReadIdsKey);
    if (raw == null || raw.isEmpty) return <String>{};
    return raw.split(',').toSet();
  }

  void _persistReadId(String id) {
    final ids = _loadReadIds()..add(id);
    _storage.setString(_kReadIdsKey, ids.join(','));
  }

  void _persistReadIds(List<String> ids) {
    final existing = _loadReadIds()..addAll(ids);
    _storage.setString(_kReadIdsKey, existing.join(','));
  }

  // ── Snapshot helpers ──────────────────────────────────────────────────────────

  Map<String, String> _loadSnapshot() {
    final raw = _storage.getString(_kSnapshotKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    // Stored as CSV: "bookingId1:status1,bookingId2:status2,..."
    final result = <String, String>{};
    for (final pair in raw.split(',')) {
      final sep = pair.indexOf(':');
      if (sep > 0) result[pair.substring(0, sep)] = pair.substring(sep + 1);
    }
    return result;
  }

  void _saveSnapshot(Map<String, String> snapshot) {
    final encoded =
        snapshot.entries.map((e) => '${e.key}:${e.value}').join(',');
    _storage.setString(_kSnapshotKey, encoded);
  }

  // ── Conversion: BackendBooking → AppNotification ──────────────────────────────

  AppNotification? _toNotification(
    BackendBooking booking,
    Set<String> readIds,
    Map<String, String> snapshot,
    bool isFirstLoad,
  ) {
    final status = booking.status.trim().toLowerCase();

    // Stable ID: bookingId_status  (prevents duplicate on re-fetch)
    final id = '${booking.id}_$status';

    // A notification is read if:
    //   • The user manually marked it read (readIds), OR
    //   • This is the first load (empty snapshot) — avoids flooding inbox with
    //     historical entries on fresh install, matching website behaviour, OR
    //   • The status has not changed since the last snapshot — the user was
    //     already aware of this state.
    final statusUnchanged = snapshot[booking.id] == status;
    final isRead = readIds.contains(id) || isFirstLoad || statusUnchanged;

    final date = booking.scheduledDate;

    switch (status) {
      case 'pending':
        return AppNotification(
          id: id,
          title: 'Booking Requested',
          body: 'Your ${booking.serviceName} booking has been submitted and '
              'is waiting for a technician to accept.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      case 'accepted':
      case 'confirmed':
      case 'scheduled':
        return AppNotification(
          id: id,
          title: 'Booking Confirmed',
          body:
              '${booking.workerName.isNotEmpty ? booking.workerName : "Your technician"} '
              'confirmed your ${booking.serviceName} visit.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      case 'in_progress':
      case 'inprogress':
      case 'active':
      case 'started':
        return AppNotification(
          id: id,
          title: 'Service In Progress',
          body: 'Your ${booking.serviceName} service has started.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      case 'completed':
      case 'done':
        return AppNotification(
          id: id,
          title: 'Service Completed',
          body: 'Your ${booking.serviceName} service is complete. '
              'Amount: ${booking.totalAmount.toStringAsFixed(0)} EGP.',
          type: AppNotificationType.payment,
          createdAt: date,
          isRead: isRead,
        );

      case 'cancelled':
      case 'canceled':
        return AppNotification(
          id: id,
          title: 'Booking Cancelled',
          body: 'Your ${booking.serviceName} booking has been cancelled.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      case 'rejected':
        return AppNotification(
          id: id,
          title: 'Booking Rejected',
          body:
              'Your ${booking.serviceName} booking was not accepted by the technician.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      default:
        return null; // Skip unknown statuses.
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  int _unreadIn(List<AppNotification> list) =>
      list.where((n) => !n.isRead).length;

  void _log(String message) {
    assert(() {
      developer.log(message, name: 'Servio.NotificationsProvider');
      return true;
    }());
  }
}
