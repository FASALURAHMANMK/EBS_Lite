import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/pdf/pdf_theme.dart';

class QuotePdfBuilder {
  static Future<Uint8List> buildPdfFromWidgets(
    Map<String, dynamic> quote,
    Map<String, dynamic> company, {
    PdfPageFormat? format,
    String? logoUrl,
  }) async {
    final doc = pw.Document(theme: await PdfTheme.inter());

    final quoteNumber = (quote['quote_number'] as String?) ?? '';
    final items = (quote['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final subtotal = _asDouble(quote['subtotal']);
    final tax = _asDouble(quote['tax_amount']);
    final discount = _asDouble(quote['discount_amount']);
    final total = _asDouble(quote['total_amount']);
    final status = (quote['status'] as String?) ?? '';

    final validUntilText = _formatDate(quote['valid_until']);

    pw.ImageProvider? logoProvider;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        logoProvider = await networkImage(logoUrl);
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format ?? PdfPageFormat.a4,
        build: (context) => [
          _header(
            company,
            quoteNumber,
            status: status,
            validUntilText: validUntilText,
            logoProvider: logoProvider,
          ),
          pw.SizedBox(height: 16),
          _itemsTable(items),
          pw.SizedBox(height: 12),
          _totals(
              subtotal: subtotal, tax: tax, discount: discount, total: total),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'This is a quotation and not a tax invoice.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(
    Map<String, dynamic> company,
    String quoteNumber, {
    required String status,
    required String validUntilText,
    pw.ImageProvider? logoProvider,
  }) {
    final name = (company['name'] as String?) ?? '';
    final address = (company['address'] as String?) ?? '';
    final phone = (company['phone'] as String?) ?? '';
    final email = (company['email'] as String?) ?? '';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (logoProvider != null) ...[
            pw.Container(
              margin: const pw.EdgeInsets.only(right: 12),
              width: 56,
              height: 56,
              child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
            ),
          ],
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(name,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (address.isNotEmpty) pw.Text(address),
            if (phone.isNotEmpty) pw.Text('Phone: $phone'),
            if (email.isNotEmpty) pw.Text('Email: $email'),
          ]),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('QUOTE',
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('No: $quoteNumber'),
          if (status.isNotEmpty) pw.Text('Status: $status'),
          if (validUntilText.isNotEmpty)
            pw.Text('Valid until: $validUntilText'),
        ]),
      ],
    );
  }

  static pw.Widget _itemsTable(List<Map<String, dynamic>> items) {
    final headers = [
      'Item',
      'Qty',
      'Unit Price',
      'Disc %',
      'Tax',
      'Line Total'
    ];
    final data = items.map((it) {
      final name = _productName(it);
      final qty = _asDouble(it['quantity']);
      final unitPrice = _asDouble(it['unit_price']);
      final disc = _asDouble(it['discount_percentage']);
      final tax = _asDouble(it['tax_amount']);
      final line = _asDouble(it['line_total']);
      return [
        name,
        _fmt(qty),
        _fmt(unitPrice),
        _fmt(disc),
        _fmt(tax),
        _fmt(line),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(2),
      },
    );
  }

  static pw.Widget _totals({
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
  }) {
    pw.Widget row(String label, String value, {bool bold = false}) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        );
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          row('Subtotal', _fmt(subtotal)),
          row('Tax', _fmt(tax)),
          row('Discount', _fmt(discount)),
          pw.Divider(),
          row('Total', _fmt(total), bold: true),
        ],
      ),
    );
  }

  static String _productName(Map<String, dynamic> it) {
    if (it['product'] is Map<String, dynamic>) {
      return (it['product']['name'] as String?) ??
          (it['product_name'] as String? ?? 'Item');
    }
    return (it['product_name'] as String?) ?? 'Item';
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static String _fmt(double v) {
    final nf = NumberFormat.decimalPattern();
    return nf.format(v);
  }

  static String _formatDate(dynamic v) {
    if (v == null) return '';
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt == null) return '';
      return dt.toIso8601String().split('T').first;
    }
    return '';
  }
}
