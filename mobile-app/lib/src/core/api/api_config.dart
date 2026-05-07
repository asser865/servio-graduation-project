class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'SERVIO_API_BASE',
      defaultValue: 'http://10.0.2.2:5000/api/v1',
    ),
  );
}
