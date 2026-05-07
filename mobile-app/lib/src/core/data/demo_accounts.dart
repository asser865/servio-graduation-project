import '../models/user_account.dart';

/// Demo accounts matching the web frontend's login.js credentials.
const Map<String, _DemoCredential> _kDemoCredentials =
    <String, _DemoCredential>{
  'ahmed@test.com': _DemoCredential(
    password: 'test1234',
    account: UserAccount(
      id: 'user_ahmed',
      name: 'Ahmed Yasser',
      email: 'ahmed@test.com',
      phone: '+20 100 000 1234',
      role: UserRole.customer,
      city: 'Cairo',
      avatarInitials: 'AY',
    ),
  ),
  'khaled@test.com': _DemoCredential(
    password: 'test1234',
    account: UserAccount(
      id: 'user_khaled',
      name: 'Khaled Mohamed',
      email: 'khaled@test.com',
      phone: '+20 100 000 5678',
      role: UserRole.technician,
      city: 'Cairo',
      avatarInitials: 'KM',
    ),
  ),
};

class _DemoCredential {
  const _DemoCredential({required this.password, required this.account});

  final String password;
  final UserAccount account;
}

/// Returns a [UserAccount] if [email]/[password] match a demo credential.
UserAccount? validateDemoLogin(String email, String password) {
  final cred = _kDemoCredentials[email.toLowerCase().trim()];
  if (cred == null) return null;
  if (cred.password != password) return null;
  return cred.account;
}
