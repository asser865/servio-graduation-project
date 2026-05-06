enum AuthRole {
  customer,
  technician,
}

extension AuthRoleX on AuthRole {
  String get title {
    return switch (this) {
      AuthRole.customer => 'I need a service',
      AuthRole.technician => "I'm a technician",
    };
  }

  String get subtitle {
    return switch (this) {
      AuthRole.customer => 'Book trusted home professionals',
      AuthRole.technician => 'Offer your skills and earn',
    };
  }
}
