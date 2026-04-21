import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class InvoiceService {
  static String _extractNumericId(String rawId) {
    String id = rawId.trim();
    if (id.contains('gid://shopify/Order/')) {
      id = id.replaceAll('gid://shopify/Order/', '');
    }
    if (id.contains('?')) {
      id = id.split('?')[0];
    }
    return id.trim();
  }

  static Future<Uint8List> fetchInvoicePdf(String orderIdOrGid) async {
    final cleanId = _extractNumericId(orderIdOrGid);
    final encoded = Uri.encodeComponent(cleanId);
    final url = Uri.parse('${BackendConfig.baseUrl}/order/$encoded/invoice');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Failed to fetch invoice (${response.statusCode})');
  }
}
