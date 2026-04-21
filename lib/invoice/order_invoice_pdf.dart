import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrderInvoicePdf {
  static Future<Uint8List> build({
    required Map order,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final brandColor = PdfColor.fromInt(0xFFEA0180);

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final orderName = (order['name'] ?? 'Order').toString();
    final orderId = (order['id'] ?? '').toString();
    final processedAt = _formatDate(order['processedAt']?.toString());
    final payment = (order['financialStatus'] ?? '').toString();
    final fulfillment = (order['fulfillmentStatus'] ?? '').toString();
    final customerUrl = (order['customerUrl'] ?? '').toString();

    final shippingAddress = (order['shippingAddress'] as Map?) ?? <String, dynamic>{};
    final items = ((order['lineItems']?['edges'] as List?) ?? const []);

    final subtotal = _parseAmount(order['subtotalPriceV2']?['amount']);
    final shipping = _parseAmount(order['totalShippingPriceV2']?['amount']);
    final total = _parseAmount(order['totalPriceV2']?['amount']);

    final calculatedDiscount = (subtotal + shipping) - total;
    final discount = calculatedDiscount > 0 ? calculatedDiscount : 0.0;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
        ),
        build: (context) => [
          _header(brandColor: brandColor, logo: logo),
          pw.SizedBox(height: 14),
          _metaGrid(
            orderName: orderName,
            orderId: orderId,
            processedAt: processedAt,
            payment: payment,
            fulfillment: fulfillment,
            customerUrl: customerUrl,
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _addressBlock(shippingAddress)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: _supportBlock()),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Items',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _itemsTable(items),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _totalsBox(
              subtotal: subtotal,
              shipping: shipping,
              discount: discount,
              total: total,
            ),
          ),
          pw.SizedBox(height: 20),
          _footerNote(),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header({required PdfColor brandColor, required pw.MemoryImage? logo}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        color: brandColor,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              if (logo != null)
                pw.Container(
                  width: 34,
                  height: 34,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              if (logo != null) pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'MakeupMysteryIndia',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Invoice',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'OFFICIAL',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: brandColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaGrid({
    required String orderName,
    required String orderId,
    required String processedAt,
    required String payment,
    required String fulfillment,
    required String customerUrl,
  }) {
    pw.Widget card(String label, String value) {
      final v = value.trim().isEmpty ? '-' : value.trim();
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );
    }

    final rows = <pw.Widget>[
      pw.Row(
        children: [
          pw.Expanded(child: card('Order', orderName)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: card('Date', processedAt)),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Row(
        children: [
          pw.Expanded(child: card('Payment', payment)),
          pw.SizedBox(width: 10),
          pw.Expanded(child: card('Fulfillment', fulfillment)),
        ],
      ),
    ];

    if (orderId.trim().isNotEmpty) {
      rows.add(pw.SizedBox(height: 10));
    }

    if (customerUrl.trim().isNotEmpty) {
      rows.add(pw.SizedBox(height: 10));
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _supportBlock() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Need help?',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('You can contact support from the app profile section.', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text('Thank you for shopping with us!', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _footerNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Text(
        'This invoice is generated from order details. Amounts are inclusive of applicable taxes unless stated otherwise.',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _addressBlock(Map address) {
    final name = (address['name'] ?? '').toString();
    final address1 = (address['address1'] ?? '').toString();
    final city = (address['city'] ?? '').toString();
    final province = (address['province'] ?? '').toString();
    final country = (address['country'] ?? '').toString();
    final zip = (address['zip'] ?? '').toString();
    final phone = (address['phone'] ?? '').toString();

    final lines = <String>[
      if (name.isNotEmpty) name,
      if (address1.isNotEmpty) address1,
      [city, province, zip].where((e) => e.trim().isNotEmpty).join(', ').trim(),
      if (country.isNotEmpty) country,
      if (phone.isNotEmpty) 'Phone: $phone',
    ].where((l) => l.trim().isNotEmpty).toList();

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ship To',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if (lines.isEmpty)
            pw.Text('-', style: const pw.TextStyle(fontSize: 10))
          else
            ...lines.map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  static pw.Widget _itemsTable(List items) {
    final headers = ['Item', 'Qty', 'Unit', 'Total'];

    final rows = items.map((edge) {
      final node = (edge as Map)['node'] as Map? ?? <String, dynamic>{};
      final title = (node['title'] ?? 'Item').toString();
      final qty = (node['quantity'] ?? 1) as int? ?? 1;

      final unit = _parseAmount(node['variant']?['price']?['amount']);
      final lineTotal = unit * qty;

      return [
        title,
        qty.toString(),
        _money(unit),
        _money(lineTotal),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _totalsBox({
    required double subtotal,
    required double shipping,
    required double discount,
    required double total,
  }) {
    pw.Widget row(String label, String value, {bool bold = false}) {
      final style = pw.TextStyle(
        fontSize: 10,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style),
            pw.Text(value, style: style),
          ],
        ),
      );
    }

    return pw.Container(
      width: 240,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        children: [
          row('Subtotal', _money(subtotal)),
          row('Shipping', shipping == 0 ? 'Free' : _money(shipping)),
          if (discount > 0) row('Discount', '-${_money(discount)}'),
          pw.Divider(color: PdfColors.grey300),
          row('Total', _money(total), bold: true),
        ],
      ),
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static String _money(double amount) {
    final rounded = amount.toStringAsFixed(2);
    return 'Rs. $rounded';
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
    } catch (_) {
      return '';
    }
  }
}
