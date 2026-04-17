import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../invoice/order_invoice_pdf.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Map order;
  final Uint8List? pdfBytes;

  const InvoicePreviewScreen({super.key, required this.order, this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    final orderName = (order['name'] ?? 'order').toString().replaceAll('#', '');
    final fileName = 'invoice-$orderName.pdf';

    Future<Uint8List> getBytes(PdfPageFormat format) async {
      if (pdfBytes != null) return pdfBytes!;
      return OrderInvoicePdf.build(order: order, pageFormat: format);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () async {
              final bytes = await getBytes(PdfPageFormat.a4);
              await Printing.sharePdf(bytes: bytes, filename: fileName);
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => getBytes(format),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: fileName,
      ),
    );
  }
}
