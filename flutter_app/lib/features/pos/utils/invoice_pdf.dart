import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class InvoicePdfBuilder {
  static Future<Uint8List> buildPdfFromWidgets(
    Map<String, dynamic> sale,
    Map<String, dynamic> company, {
    PdfPageFormat? format,
    String? logoUrl,
  }) async {
    final doc = pw.Document();

    final saleNumber = (sale['sale_number'] as String?) ?? '';
    final items = (sale['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final subtotal = _asDouble(sale['subtotal']);
    final tax = _asDouble(sale['tax_amount']);
    final discount = _asDouble(sale['discount_amount']);
    final total = _asDouble(sale['total_amount']);

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
          _header(company, saleNumber, logoProvider: logoProvider),
          pw.SizedBox(height: 16),
          _itemsTable(items),
          pw.SizedBox(height: 12),
          _totals(subtotal: subtotal, tax: tax, discount: discount, total: total),
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Map<String, dynamic> company, String saleNumber, {pw.ImageProvider? logoProvider}) {
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
          pw.Text(name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (address.isNotEmpty) pw.Text(address),
          if (phone.isNotEmpty) pw.Text('Phone: $phone'),
          if (email.isNotEmpty) pw.Text('Email: $email'),
          ]),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('No: $saleNumber'),
        ]),
      ],
    );
  }

  static pw.Widget _itemsTable(List<Map<String, dynamic>> items) {
    final headers = ['Item', 'Qty', 'Unit Price', 'Disc %', 'Tax', 'Line Total'];
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
            pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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

  static Future<Uint8List> buildPdfFromHtml(
    Map<String, dynamic> sale,
    Map<String, dynamic> company, {
    PdfPageFormat? format,
    String? logoUrl,
  }) async {
    final html = _buildHtml(sale, company, logoUrl: logoUrl);
    return await Printing.convertHtml(
      format: format ?? PdfPageFormat.a4,
      html: html,
    );
  }

  static String _buildHtml(Map<String, dynamic> sale, Map<String, dynamic> company, {String? logoUrl}) {
    final saleNumber = (sale['sale_number'] as String?) ?? '';
    final items = (sale['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final subtotal = _fmt(_asDouble(sale['subtotal']));
    final tax = _fmt(_asDouble(sale['tax_amount']));
    final discount = _fmt(_asDouble(sale['discount_amount']));
    final total = _fmt(_asDouble(sale['total_amount']));

    final name = (company['name'] as String?) ?? '';
    final address = (company['address'] as String?) ?? '';
    final phone = (company['phone'] as String?) ?? '';
    final email = (company['email'] as String?) ?? '';

    final rows = items.map((it) {
      final n = _productName(it);
      final qty = _fmt(_asDouble(it['quantity']));
      final unit = _fmt(_asDouble(it['unit_price']));
      final disc = _fmt(_asDouble(it['discount_percentage']));
      final tax = _fmt(_asDouble(it['tax_amount']));
      final total = _fmt(_asDouble(it['line_total']));
      return '<tr>'
          '<td>$n</td>'
          '<td class="r">$qty</td>'
          '<td class="r">$unit</td>'
          '<td class="r">$disc</td>'
          '<td class="r">$tax</td>'
          '<td class="r">$total</td>'
          '</tr>';
    }).join();

    final logoImg = (logoUrl != null && logoUrl.isNotEmpty) ? '<img src="$logoUrl" style="max-height:56px;max-width:56px;margin-right:12px" />' : '';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
    body { font-family: Arial, Helvetica, sans-serif; margin: 24px; }
    .header { display:flex; justify-content:space-between; }
    .title { font-size: 22px; font-weight: 700; }
    .muted { color: #666; font-size: 12px; }
    table { width: 100%; border-collapse: collapse; margin-top: 16px; }
    th, td { padding: 8px; border-bottom: 1px solid #eee; font-size: 12px; }
    th { text-align: left; background: #f3f3f3; }
    .r { text-align: right; }
    .totals { margin-top: 12px; width: 100%; }
    .totals td { padding: 4px 0; }
    .totals .label { text-align: right; }
    .totals .value { text-align: right; min-width: 120px; font-weight: 600; }
    .footer { margin-top: 16px; text-align:center; color:#888; font-size: 11px; }
  </style>
  <title>Invoice $saleNumber</title>
  </head>
  <body>
    <div class="header">
      <div style="display:flex;align-items:flex-start;">
        $logoImg
        <div class="title">$name</div>
        <div style="display:block">
          <div class="muted">$address</div>
          <div class="muted">$phone</div>
          <div class="muted">$email</div>
        </div>
      </div>
      <div>
        <div class="title">INVOICE</div>
        <div>No: $saleNumber</div>
      </div>
    </div>
    <table>
      <thead>
        <tr>
          <th>Item</th>
          <th class="r">Qty</th>
          <th class="r">Unit Price</th>
          <th class="r">Disc %</th>
          <th class="r">Tax</th>
          <th class="r">Line Total</th>
        </tr>
      </thead>
      <tbody>
        $rows
      </tbody>
    </table>
    <table class="totals">
      <tr><td class="label">Subtotal</td><td class="value">$subtotal</td></tr>
      <tr><td class="label">Tax</td><td class="value">$tax</td></tr>
      <tr><td class="label">Discount</td><td class="value">$discount</td></tr>
      <tr><td class="label">Total</td><td class="value">$total</td></tr>
    </table>
    <div class="footer">Thank you for your business!</div>
  </body>
</html>
''';
  }

  static String _productName(Map<String, dynamic> it) {
    if (it['product'] is Map<String, dynamic>) {
      return (it['product']['name'] as String?) ?? (it['product_name'] as String? ?? 'Item');
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
}
