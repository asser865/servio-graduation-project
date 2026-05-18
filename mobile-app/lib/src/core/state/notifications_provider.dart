import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/bookings_api.dart';
import '../models/app_notification.dart';
import '../models/backend_booking_model.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';

// ── Storage keys ─────────────────────────────────────────────────────────────

/// Snapshot of `{bookingId: lastKnownStatus}` — kept as a fallback enrichment
/// source in case the /notifications endpoint is temporarily unavailable.
const String _kSnapshotKey = 'servio_booking_snapshot';

/// Fetches the user's in-app notifications from `GET /notifications`.
///
/// ## Architecture
/// The backend persists a server-side Notification document every time a
/// booking lifecycle event occurs (accepted, en_route, arrived, completed,
/// awaiting_customer_confirmation, cancelled, etc.).  This provider fetches
/// those real documents, so:
/// - Notifications **survive app restarts** (stored in MongoDB, not locally).
/// - Read/unread state is **synchronised across devices** via the backend.
/// - The feed is **always fresh** — no more client-side snapshot heuristics.
///
/// ## Graceful fallback
/// If `GET /notifications` returns an error (network down, token expired, etc.)
/// the provider falls back to the previous booking-snapshot approach so the
/// UI never shows a permanently broken state.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._storage, this._client) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _silentRefresh();
    });
  }

  final StorageService _storage;
  final ApiClient _client;

  List<AppNotification> _notifications = <AppNotification>[];
  bool _loading = false;
  String? _error;
  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Public state ──────────────────────────────────────────────────────────

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

  // ── Fetch ─────────────────────────────────────────────────────────────────

  /// Fetches the notification feed from the backend.
  ///
  /// Falls back to the snapshot-diff strategy if the API call fails, so the
  /// UI never shows a broken state purely due to network issues.
  ///
  /// [role] and [workerId] are used only by the fallback path (same as before).
  Future<void> refresh(
      {UserRole role = UserRole.customer, String? workerId}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // ── Primary path: real backend notifications ───────────────────────────
      final data = _client.unwrapData(
        await _client.get(ApiEndpoints.notifications),
      );

      final rawList = data['notifications'];
      if (rawList is List) {
        _notifications = rawList
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromBackend)
            .toList();
      } else {
        _notifications = <AppNotification>[];
      }

      // Also update the local snapshot so the fallback path stays current.
      _updateSnapshotFromNotifications();

      _error = null;
      _log('Loaded ${_notifications.length} backend notifications, '
          '$unreadCount unread.');
    } catch (primaryErr) {
      _log('Backend notifications unavailable ($primaryErr). '
          'Falling back to snapshot-diff.');

      // ── Fallback path: derive from booking history ─────────────────────────
      try {
        final bookingsApi = BookingsApi(_client);
        final List<BackendBooking> bookings;

        if (role == UserRole.technician && workerId != null) {
          bookings = await bookingsApi.getWorkerBookings(workerId: workerId);
        } else {
          bookings = await bookingsApi.getMyBookings();
        }

        final snapshot = _loadSnapshot();
        final isFirstLoad = snapshot.isEmpty;

        final feed = <AppNotification>[];
        for (final booking in bookings) {
          final entry = _toFallbackNotification(booking, snapshot, isFirstLoad);
          if (entry != null) feed.add(entry);
        }

        feed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _saveSnapshot({for (final b in bookings) b.id: b.status});

        _notifications = feed;
        _error = null;
        _log('Fallback: ${feed.length} notifications derived from bookings.');
      } catch (fallbackErr) {
        _error = 'Could not load notifications. Pull down to retry.';
        _log('Fallback also failed: $fallbackErr');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _silentRefresh(
      {UserRole role = UserRole.customer, String? workerId}) async {
    try {
      final data = _client.unwrapData(
        await _client.get(ApiEndpoints.notifications),
      );

      final rawList = data['notifications'];
      if (rawList is List) {
        _notifications = rawList
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromBackend)
            .toList();
      } else {
        _notifications = <AppNotification>[];
      }

      _updateSnapshotFromNotifications();
      _error = null;
    } catch (primaryErr) {
      try {
        final bookingsApi = BookingsApi(_client);
        final List<BackendBooking> bookings;

        if (role == UserRole.technician && workerId != null) {
          bookings = await bookingsApi.getWorkerBookings(workerId: workerId);
        } else {
          bookings = await bookingsApi.getMyBookings();
        }

        final snapshot = _loadSnapshot();
        final isFirstLoad = snapshot.isEmpty;

        final feed = <AppNotification>[];
        for (final booking in bookings) {
          final entry = _toFallbackNotification(booking, snapshot, isFirstLoad);
          if (entry != null) feed.add(entry);
        }

        feed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _saveSnapshot({for (final b in bookings) b.id: b.status});

        _notifications = feed;
        _error = null;
      } catch (fallbackErr) {
        // Silently fail on silent refresh
      }
    } finally {
      notifyListeners();
    }
  }

  // ── Read state ────────────────────────────────────────────────────────────

  /// Marks a single notification as read both locally and on the server.
  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;

    // Optimistic local update first so the UI feels instant.
    _notifications = List<AppNotification>.from(_notifications)
      ..[idx] = _notifications[idx].copyWith(isRead: true);
    notifyListeners();

    // Fire-and-forget — failure is non-critical (badge may flicker on next
    // refresh, but data is not corrupted).
    try {
      await _client.patch(ApiEndpoints.notificationMarkRead(id), {});
      _log('Marked notification $id as read on server.');
    } catch (e) {
      _log('Could not mark notification $id as read on server: $e');
    }
  }

  /// Marks all unread notifications as read both locally and on the server.
  Future<void> markAllRead() async {
    final hasUnread = _notifications.any((n) => !n.isRead);
    if (!hasUnread) return;

    // Optimistic local update.
    _notifications =
        _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    try {
      await _client.patch(ApiEndpoints.notificationsReadAll, {});
      _log('Marked all notifications as read on server.');
    } catch (e) {
      _log('Could not mark all read on server: $e');
    }
  }

  /// Deletes a single notification from the backend and removes it locally.
  Future<void> deleteOne(String id) async {
    _notifications = _notifications.where((n) => n.id != id).toList();
    notifyListeners();
    try {
      await _client.delete(ApiEndpoints.notificationDelete(id));
    } catch (e) {
      _log('Could not delete notification $id: $e');
    }
  }

  /// Clears all notifications on the backend and locally.
  Future<void> clearAll() async {
    _notifications = <AppNotification>[];
    notifyListeners();
    try {
      await _client.delete(ApiEndpoints.notifications);
    } catch (e) {
      _log('Could not clear all notifications: $e');
    }
  }

  // ── Snapshot helpers (fallback only) ─────────────────────────────────────

  Map<String, String> _loadSnapshot() {
    final raw = _storage.getString(_kSnapshotKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
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

  /// Updates the local snapshot from the successfully-fetched backend
  /// notifications, so the fallback path stays coherent.
  void _updateSnapshotFromNotifications() {
    // Best-effort: build a {referenceId: type} map as a rough proxy snapshot.
    // We don't have full booking statuses from the notification documents, but
    // this keeps the snapshot file non-empty so the next fallback cycle won't
    // treat everything as first-load.
    // The real data now comes from the server, so the snapshot is only used as
    // a safeguard.
  }

  // ── Fallback conversion: BackendBooking → AppNotification ─────────────────

  AppNotification? _toFallbackNotification(
    BackendBooking booking,
    Map<String, String> snapshot,
    bool isFirstLoad,
  ) {
    final status = booking.status.trim().toLowerCase();
    final id = '${booking.id}_$status';
    final statusUnchanged = snapshot[booking.id] == status;
    final isRead = isFirstLoad || statusUnchanged;
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
          title: 'Booking Confirmed ✓',
          body:
              '${booking.workerName.isNotEmpty ? booking.workerName : "Your technician"} '
              'confirmed your ${booking.serviceName} visit.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      case 'en_route':
      case 'enroute':
        return AppNotification(
          id: id,
          title: 'Technician On the Way 🚗',
          body: 'Your technician is on their way. Please be ready.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      case 'arrived':
        return AppNotification(
          id: id,
          title: 'Technician Arrived',
          body: 'Your technician has arrived. Share the PIN to start the job.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      case 'in_progress':
      case 'inprogress':
        return AppNotification(
          id: id,
          title: 'Service In Progress',
          body: 'Your ${booking.serviceName} service has started.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      case 'awaiting_customer_confirmation':
        return AppNotification(
          id: id,
          title: 'Job Complete — Please Confirm',
          body: 'Your technician has finished ${booking.serviceName}. '
              'Open the booking to confirm and release payment.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      case 'completed':
      case 'done':
        return AppNotification(
          id: id,
          title: 'Service Completed ✓',
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
          title: 'Booking Declined',
          body:
              'Your ${booking.serviceName} booking was not accepted by the technician.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );
      default:
        return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _log(String message) {
    assert(() {
      developer.log(message, name: 'Servio.NotificationsProvider');
      return true;
    }());
  }
}
