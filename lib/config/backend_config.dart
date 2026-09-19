import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static const String railwayDomain =
      "https://mm-backend-production-d3a3.up.railway.app/api";
  static const String customDomain =
      "https://mmapp.makeupmystery.in/api";

  static String _activeBaseUrl = railwayDomain;
  static bool _initialized = false;

  static String get baseUrl {
    if (!_initialized) {
      _initFromEnv();
    }
    return _activeBaseUrl;
  }

  static void _initFromEnv() {
    _initialized = true;
    final envVal = dotenv.env['BACKEND_BASE_URL']?.trim();
    if (envVal != null && envVal.isNotEmpty) {
      var v = envVal;
      if (v.endsWith(';')) v = v.substring(0, v.length - 1).trim();
      if ((v.startsWith("'") && v.endsWith("'")) || (v.startsWith('"') && v.endsWith('"'))) {
        v = v.substring(1, v.length - 1).trim();
      }
      while (v.endsWith('/')) {
        v = v.substring(0, v.length - 1);
      }
      if (v.isNotEmpty) {
        _activeBaseUrl = v;
      }
    }
  }

  static void setActiveDomain(String host) {
    if (host.contains("makeupmystery.in")) {
      _activeBaseUrl = customDomain;
    } else if (host.contains("railway.app")) {
      _activeBaseUrl = railwayDomain;
    }
  }

  static void setActiveBaseUrl(String url) {
    if (url.isNotEmpty) {
      _activeBaseUrl = url;
    }
  }
}
