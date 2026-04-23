import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static String get baseUrl {
    final raw = (dotenv.env['BACKEND_API_BASE_URL'] ?? '').trim();

    if (raw.isEmpty) {
      if (kIsWeb) return 'http://127.0.0.1:5500/api';
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:5500/api';
      }
      return 'http://127.0.0.1:5500/api';
    }

    final clean = raw.endsWith('/')
        ? raw.substring(0, raw.length - 1)
        : raw;

    if (clean.endsWith('/api')) return clean;
    return '$clean/api';
  }
}