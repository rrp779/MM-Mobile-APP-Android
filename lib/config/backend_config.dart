import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  static const String fallbackBaseUrl =
      "https://mm-backend-production-d3a3.up.railway.app/api";

  static String get baseUrl {
    var value = (dotenv.env['BACKEND_BASE_URL'] ?? fallbackBaseUrl).trim();

    if (value.endsWith(';')) {
      value = value.substring(0, value.length - 1).trim();
    }

    final wrappedInSingleQuotes = value.startsWith("'") && value.endsWith("'");
    final wrappedInDoubleQuotes = value.startsWith('"') && value.endsWith('"');
    if (wrappedInSingleQuotes || wrappedInDoubleQuotes) {
      value = value.substring(1, value.length - 1).trim();
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    return value.isEmpty ? fallbackBaseUrl : value;
  }
} 
