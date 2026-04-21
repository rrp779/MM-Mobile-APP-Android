import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';

import '../invoice/order_invoice_pdf.dart';

class InvoicePreviewScreen extends StatelessWidget {
  final Map order;
  final Uint8List? pdfBytes;

  const InvoicePreviewScreen({super.key, required this.order, this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    final orderName = (order['name'] ?? 'order').toString().replaceAll('#', '');
    final rawDate = order['processedAt'] ?? order['createdAt'] ?? order['processed_at'] ?? order['created_at'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final datePart = (parsedDate ?? DateTime.now()).toIso8601String().split('T').first;
    final fileName = 'invoice-$orderName-$datePart.pdf';
    const brandColor = Color(0xFFEA0180);

    Future<Uint8List> getBytes(PdfPageFormat format) async {
      if (pdfBytes != null) return pdfBytes!;
      return OrderInvoicePdf.build(order: order, pageFormat: format);
    }

    Future<void> shareInvoice() async {
      final bytes = await getBytes(PdfPageFormat.a4);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }

    Future<void> printInvoice() async {
      final bytes = await getBytes(PdfPageFormat.a4);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: fileName);
    }

    Future<void> saveInvoiceToDevice() async {
      try {
        final bytes = await getBytes(PdfPageFormat.a4);

        if (kIsWeb) {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return;
        }

        bool savedToDownloads = false;
        Directory? targetDir;

        if (Platform.isAndroid) {
          final storageStatus = await Permission.storage.request();
          final downloadsDir = Directory('/storage/emulated/0/Download');

          if (storageStatus.isGranted && await downloadsDir.exists()) {
            targetDir = downloadsDir;
            savedToDownloads = true;
          } else {
            targetDir = await getExternalStorageDirectory();
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        targetDir ??= await getApplicationDocumentsDirectory();
        await targetDir.create(recursive: true);

        final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsBytes(bytes, flush: true);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedToDownloads ? '✅ Invoice saved to Downloads folder' : '✅ Invoice saved to ${targetDir.path}',
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice save failed: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invoice'),
            Text(
              '#$orderName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: shareInvoice,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) => getBytes(format),
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowPrinting: false,
              allowSharing: false,
              pdfFileName: fileName,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saveInvoiceToDevice,
                child: const Text('Save to Device'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: printInvoice,
                  icon: const Icon(Icons.print_outlined, color: brandColor),
                  label: const Text('Print', style: TextStyle(color: brandColor)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: shareInvoice,
                  icon: const Icon(Icons.share_outlined, color: brandColor),
                  label: const Text('Share', style: TextStyle(color: brandColor)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: saveInvoiceToDevice,
                  icon: const Icon(Icons.download_outlined, color: brandColor),
                  label: const Text('Download', style: TextStyle(color: brandColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
