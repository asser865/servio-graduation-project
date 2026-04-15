enum UserRole { customer, technician }

class UserAccount {
  const UserAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.city = 'Cairo',
    this.avatarInitials = '',
    this.status = 'active',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String city;
  final String avatarInitials;
  final String status; // active | pending

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'city': city,
        'avatarInitials': avatarInitials,
        'status': status,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        role: UserRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => UserRole.customer,
        ),
        city: (json['city'] as String?) ?? 'Cairo',
        avatarInitials: (json['avatarInitials'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'active',
      );
}
