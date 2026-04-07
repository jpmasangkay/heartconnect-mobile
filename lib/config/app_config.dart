/// Build-time API and Socket.IO URLs for dev / staging / prod.
///
/// Pass values with `--dart-define=KEY=value` (or your CI). **Production must use
/// `https://` origins** (TLS); avoid committing machine-specific LAN IPs.
///
/// **Parity with a Vite web client:** use the same logical names so one CI matrix
/// can inject both:
/// - [VITE_API_URL] — REST base URL including `/api` path (e.g. `https://api.example.com/api`)
/// - [VITE_SOCKET_URL] — Socket.IO origin (e.g. `https://api.example.com`)
/// - `CLIENT_URL` is for **server** CORS / redirects (browser origin), not read here.
///
/// **Alternates:** `API_BASE_URL` and `SOCKET_URL` if you prefer non-Vite names.
///
/// **Dev fallback:** if none of the above are set, `API_HOST` (host:port, no scheme)
/// builds `http://$API_HOST/api` and a matching socket origin. Defaults to
/// `heartconnect.onrender.com` (production backend).
abstract final class AppConfig {
  static String get apiBaseUrl {
    const vite = String.fromEnvironment('VITE_API_URL');
    if (vite.isNotEmpty) return _trimTrailingSlashes(vite);
    const api = String.fromEnvironment('API_BASE_URL');
    if (api.isNotEmpty) return _trimTrailingSlashes(api);
    const host = String.fromEnvironment('API_HOST', defaultValue: 'heartconnect.onrender.com');
    if (host == 'heartconnect.onrender.com') return 'https://heartconnect.onrender.com/api';
    return 'http://$host/api';
  }

  /// Socket.IO server origin (no path, or path ignored by client).
  static String get socketUrl {
    const vite = String.fromEnvironment('VITE_SOCKET_URL');
    if (vite.isNotEmpty) return _trimTrailingSlashes(vite);
    const socket = String.fromEnvironment('SOCKET_URL');
    if (socket.isNotEmpty) return _trimTrailingSlashes(socket);
    final base = apiBaseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    if (base.endsWith('/api/')) {
      return base.substring(0, base.length - 5);
    }
    return base;
  }

  static String _trimTrailingSlashes(String s) {
    var out = s.trim();
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}
