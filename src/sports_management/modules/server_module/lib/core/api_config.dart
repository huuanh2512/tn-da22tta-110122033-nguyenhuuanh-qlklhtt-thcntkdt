class ApiConfig {
  const ApiConfig._();

  // Compile-time constant được truyền qua --dart-define=API_BASE_URL=...
  // Fallback: URL production thật (Render backend)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://doantotnghiep-f3bh.onrender.com/api/v1',
  );

  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;
}
