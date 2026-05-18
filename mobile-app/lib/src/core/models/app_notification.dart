/// A unified in-app notification entry backed by the server's `/notifications` API.
///
/// The backend persists one notification object per booking lifecycle event
/// (accepted, en_route, arrived, completed, etc.).  This model maps that
/// server document to the fields the UI needs.
library;

enum AppNotificationType { booking, payment, system }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.referenceId,
  });

  /// The backend Mongo `_id` of the Notification document.  Used to call
  /// `PATCH /notifications/:id/read` when the user taps the notification.
  final String id;

  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  /// The booking / review / payment ID this notification relates to.
  /// May be null for system notifications.
  final String? referenceId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      referenceId: referenceId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        if (referenceId != null) 'referenceId': referenceId,
      };

  /// Creates an [AppNotification] from a backend Notification document.
  factory AppNotification.fromBackend(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String? ?? '').toLowerCase();
    final type = _mapBackendType(typeStr);
    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '') as String,
      title: (json['title'] as String?) ?? 'Notification',
      body: (json['body'] as String?) ?? '',
      type: type,
      createdAt: DateTime.tryParse(
              (json['createdAt'] ?? json['updatedAt'] ?? '') as String) ??
          DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
      referenceId: json['referenceId'] as String?,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: AppNotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AppNotificationType.system,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
      referenceId: json['referenceId'] as String?,
    );
  }
}

/// Maps the backend `type` enum values to the app's [AppNotificationType].
AppNotificationType _mapBackendType(String type) {
  if (type.startsWith('payment')) return AppNotificationType.payment;
  if (type.startsWith('booking') || type == 'review_received') {
    return AppNotificationType.booking;
  }
  return AppNotificationType.system;
}
