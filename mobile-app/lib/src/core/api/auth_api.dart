import '../models/user_account.dart';
import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post('/auth/login', <String, dynamic>{
      'email': email,
      'password': password,
    });
    return AuthSession.fromApi(_client.unwrapData(response));
  }

  Future<AuthSession> registerCustomer({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String city,
  }) async {
    final response = await _client.post('/auth/register', <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': 'user',
      'address': <String, dynamic>{'city': city},
    });
    return AuthSession.fromApi(_client.unwrapData(response));
  }

  Future<AuthSession> registerTechnician({
    required String name,
    required String email,
    required String password,
    required String phone,
    required List<String> skills,
    required String serviceArea,
    required int hourlyRate,
    required String availabilityType,
  }) async {
    final response = await _client.post('/auth/register', <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
      'role': 'worker',
      'skills': skills,
      'locationLabel': serviceArea,
      'hourlyRate': hourlyRate,
      'availabilityType': availabilityType.toLowerCase(),
    });
    return AuthSession.fromApi(_client.unwrapData(response));
  }

  Future<UserAccount> getMe() async {
    final response = await _client.get('/users/me');
    return UserAccount.fromBackend(_client.unwrapData(response));
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final UserAccount user;

  factory AuthSession.fromApi(Map<String, dynamic> json) {
    return AuthSession(
      token: (json['token'] as String?) ?? '',
      user: UserAccount.fromBackend(json['user'] as Map<String, dynamic>),
    );
  }
}
