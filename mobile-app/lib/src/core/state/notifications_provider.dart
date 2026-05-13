import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/bookings_api.dart';
import '../models/app_notification.dart';
import '../models/backend_booking_model.dart';
import '../models/user_account.dart';
import '../services/storage_service.dart';

// ── Storage key ───────────────────────────────────────────────────────────────
const String _kReadIdsKey = 'servio_notif_read_ids';

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
  /// Pass [role] to use the correct API endpoint.
  Future<void> refresh({UserRole role = UserRole.customer, String? workerId}) async {
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
      final feed = <AppNotification>[];

      for (final booking in bookings) {
        final entry = _toNotification(booking, readIds);
        if (entry != null) feed.add(entry);
      }

      // Sort newest first (by booking scheduled date as a proxy — backend
      // does not return a notification timestamp).
      feed.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _notifications = feed;
      _error = null;
      _log('Loaded ${feed.length} notifications, ${_unreadIn(feed)} unread.');
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

  // ── Conversion: BackendBooking → AppNotification ──────────────────────────────

  AppNotification? _toNotification(BackendBooking booking, Set<String> readIds) {
    final status = booking.status.trim().toLowerCase();

    // Stable ID: bookingId_status  (prevents duplicate on re-fetch)
    final id = '${booking.id}_$status';
    final isRead = readIds.contains(id);
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
          body: '${booking.workerName.isNotEmpty ? booking.workerName : "Your technician"} '
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
          body: 'Your ${booking.serviceName} booking was not accepted by the technician.',
          type: AppNotificationType.booking,
          createdAt: date,
          isRead: isRead,
        );

      default:
        return null; // Skip unknown statuses.
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  int _unreadIn(List<AppNotification> list) => list.where((n) => !n.isRead).length;

  void _log(String message) {
    assert(() {
      developer.log(message, name: 'Servio.NotificationsProvider');
      return true;
    }());
  }
}
