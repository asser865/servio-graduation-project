enum AuthRole {
  customer,
  technician,
}

extension AuthRoleX on AuthRole {
  String get title {
    return switch (this) {
      AuthRole.customer => 'I Need Services',
      AuthRole.technician => "I'm a Technician",
    };
  }

  String get subtitle {
    return switch (this) {
      AuthRole.customer => 'Browse and book verified home service professionals.',
      AuthRole.technician => 'Manage jobs, earn money, grow your reputation.',
    };
  }
}
