/// A unified in-app notification entry derived from the user's booking history.
///
/// The backend has no dedicated notification inbox or read-state storage, so:
/// - The feed is synthesised client-side from [BackendBooking] objects.
/// - Each unique (bookingId + status) pair becomes one notification.
/// - Read state is tracked in [StorageService] (SharedPreferences), keyed by
///   [AppNotification.id], so it survives app restarts without a backend call.
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
  });

  /// Stable composite key: `<bookingId>_<status>` — guarantees idempotency when
  /// re-fetching so the same event is never duplicated.
  final String id;

  final String title;
  final String body;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

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
    );
  }
}
