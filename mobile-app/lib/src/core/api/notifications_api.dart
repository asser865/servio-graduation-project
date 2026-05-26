import 'api_client.dart';
import 'api_endpoints.dart';

class NotificationPreference {
  const NotificationPreference({
    this.email = true,
    this.inApp = true,
    this.push = true,
    this.sms = false,
  });

  final bool email;
  final bool inApp;
  final bool push;
  final bool sms;

  NotificationPreference copyWith({
    bool? email,
    bool? inApp,
    bool? push,
    bool? sms,
  }) =>
      NotificationPreference(
        email: email ?? this.email,
        inApp: inApp ?? this.inApp,
        push: push ?? this.push,
        sms: sms ?? this.sms,
      );

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    final channels = json['channels'] as Map<String, dynamic>? ?? json;
    return NotificationPreference(
      email: (channels['email'] as bool?) ?? true,
      inApp: (channels['inApp'] as bool?) ?? true,
      push: (channels['push'] as bool?) ?? true,
      sms: (channels['sms'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'channels': {
          'email': email,
          'inApp': inApp,
          'push': push,
          'sms': sms,
        },
      };
}

class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<NotificationPreference> getPreferences() async {
    final data = _client.unwrapData(
      await _client.get(ApiEndpoints.notificationPreferences),
    );
    return NotificationPreference.fromJson(data);
  }

  Future<void> updatePreferences(NotificationPreference prefs) async {
    await _client.patch(
      ApiEndpoints.notificationPreferences,
      prefs.toJson(),
    );
  }
}
