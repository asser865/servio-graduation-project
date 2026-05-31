import 'api_client.dart';
import 'api_endpoints.dart';

class ContactApi {
  ContactApi(this._client);

  final ApiClient _client;

  Future<void> sendMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    await _client.post(ApiEndpoints.contact, <String, dynamic>{
      'name': name,
      'email': email,
      'subject': subject,
      'message': message,
    });
  }
}
