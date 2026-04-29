class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errors = const <Map<String, dynamic>>[],
  });

  final String message;
  final int? statusCode;
  final List<Map<String, dynamic>> errors;

  @override
  String toString() => message;
}
