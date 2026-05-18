class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment(
      'SERVIO_API_BASE',
      defaultValue: 'http://10.0.2.2:5000/api/v1',
    ),
  );

  static String normalizeBackendUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return trimmed;
    if (uri.host != '127.0.0.1' && uri.host != 'localhost') return trimmed;

    final backendUri = Uri.tryParse(baseUrl);
    if (backendUri == null || !backendUri.hasScheme || !backendUri.hasAuthority) {
      return trimmed;
    }

    return backendUri
        .replace(path: uri.path, query: uri.hasQuery ? uri.query : null)
        .toString();
  }
}
