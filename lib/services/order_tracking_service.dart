import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class OrderTrackingService {
  static String _extractNumericId(String rawId) {
    String id = rawId.trim();

    // Remove GID prefix
    if (id.contains('gid://shopify/Order/')) {
      id = id.replaceAll('gid://shopify/Order/', '');
    }

    // Remove ?key=... suffix
    if (id.contains('?')) {
      id = id.split('?')[0];
    }

    return id.trim();
  }

  static Future<Map<String, dynamic>> fetchTracking(
    String orderIdOrGid, {
    bool forceRefresh = false,
    String? simulateShiprocketStatus,
  }) async {
    final cleanId = _extractNumericId(orderIdOrGid);
    final base = Uri.parse('${BackendConfig.baseUrl}/order/$cleanId/tracking');
    final qp = <String, String>{};
    if (forceRefresh) qp['force'] = '1';
    final sim = (simulateShiprocketStatus ?? '').trim();
    if (sim.isNotEmpty) qp['simulate'] = sim;
    final url = qp.isEmpty ? base : base.replace(queryParameters: qp);

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception('Invalid tracking response');
    }

    String message = 'Failed to fetch tracking (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) {
        message = decoded['error']?.toString() ?? 'Unknown error';
      }
    } catch (_) {}

    throw Exception(message);
  }
}
