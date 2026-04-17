import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class InvoiceService {
  static Future<Uint8List> fetchInvoicePdf(String orderIdOrGid) async {
    final encoded = Uri.encodeComponent(orderIdOrGid);
    final url = Uri.parse('${BackendConfig.baseUrl}/order/$encoded/invoice');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }

    throw Exception('Failed to fetch invoice (${response.statusCode})');
  }
}

