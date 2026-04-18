import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static const String _defaultApiBaseUrl =
      "https://mm-backend-production-f67e.up.railway.app/api";

  /// Dashboard / project URLs are not API hosts and return 404 for `/api/review`.
  static bool _isNonApiRailwayUrl(String value) {
    final v = value.toLowerCase();
    return v.contains('railway.com/project') ||
        v.contains('railway.app/project');
  }

  /// When `.env` omits the backend URL, debug builds default to a local Node server.
  static String get _debugLocalApiOrigin {
    if (kIsWeb) return 'http://127.0.0.1:5500';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5500';
    }
    return 'http://127.0.0.1:5500';
  }

  /// Base API URL used by the app. Override via Flutter `.env`, e.g.
  /// `BACKEND_API_BASE_URL=http://10.0.2.2:5500` (emulator → host machine).
  static String get baseUrl {
    var fromEnv = (dotenv.env['BACKEND_API_BASE_URL'] ?? '').trim();
    if (fromEnv.isEmpty && kDebugMode) {
      fromEnv = _debugLocalApiOrigin;
    }

    final raw = (fromEnv.isEmpty || _isNonApiRailwayUrl(fromEnv))
        ? _defaultApiBaseUrl
        : fromEnv;

    if (raw.isEmpty) return _defaultApiBaseUrl;

    // Normalize to always end with `/api`.
    if (raw.endsWith('/api')) return raw;
    if (raw.endsWith('/api/')) return raw.substring(0, raw.length - 1);

    if (raw.endsWith('/')) return '${raw}api';
    return '$raw/api';
  }
}
