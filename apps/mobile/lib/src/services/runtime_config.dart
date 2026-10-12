/// Compile-time endpoints for local development and production releases.
///
/// Production builds must supply `API_BASE_URL` with the HTTPS API root. The
/// realtime endpoint is derived from its host unless `REALTIME_BASE_URL` is
/// supplied separately.
class RuntimeConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const _realtimeBaseUrl = String.fromEnvironment('REALTIME_BASE_URL');

  static String get realtimeBaseUrl {
    if (_realtimeBaseUrl.isNotEmpty) return _realtimeBaseUrl;

    final apiUri = Uri.parse(apiBaseUrl);
    final scheme = apiUri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString();
  }
}
