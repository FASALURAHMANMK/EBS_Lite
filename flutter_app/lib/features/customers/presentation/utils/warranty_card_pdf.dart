import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/pdf/pdf_theme.dart';
import '../../data/warranty_models.dart';

class WarrantyCardPdfBuilder {
  static Future<Uint8List> build(
    WarrantyCardDataDto data, {
    required PdfPageFormat format,
    String? logoUrl,
  }) async {
    final doc = pw.Document(theme: await PdfTheme.inter());
    final isCompact = format.width <= PdfPageFormat.a5.width + 1;

    pw.ImageProvider? logoProvider;
    if (logoUrl != null && logoUrl.trim().isNotEmpty) {
      try {
        logoProvider = await networkImage(logoUrl.trim());
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(isCompact ? 24 : 32),
        build: (context) => [
          _header(data, logoProvider: logoProvider, compact: isCompact),
          pw.SizedBox(height: 16),
          _heroBanner(data, compact: isCompact),
          pw.SizedBox(height: 16),
          _section(
            title: 'Customer',
            child: _customerBlock(data, compact: isCompact),
          ),
          pw.SizedBox(height: 12),
          _section(
            title: 'Covered Items',
            child: _itemsTable(data, compact: isCompact),
          ),
          pw.SizedBox(height: 12),
          _section(
            title: 'Warranty Notes',
            child: _notesBlock(data, compact: isCompact),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(
    WarrantyCardDataDto data, {
    required bool compact,
    pw.ImageProvider? logoProvider,
  }) {
    final company = data.company;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoProvider != null)
                pw.Container(
                  width: compact ? 44 : 54,
                  height: compact ? 44 : 54,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logoProvider, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.name,
                      style: pw.TextStyle(
                        fontSize: compact ? 16 : 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    if ((company.address ?? '').trim().isNotEmpty)
                      pw.Text(company.address!.trim()),
                    if ((company.phone ?? '').trim().isNotEmpty)
                      pw.Text('Phone: ${company.phone!.trim()}'),
                    if ((company.email ?? '').trim().isNotEmpty)
                      pw.Text('Email: ${company.email!.trim()}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey900,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            'WARRANTY CARD',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _heroBanner(
    WarrantyCardDataDto data, {
    required bool compact,
  }) {
    final warranty = data.warranty;
    final range = _coverageRange(warranty.items);
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(compact ? 14 : 18),
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [
            PdfColor.fromInt(0xFF16324F),
            PdfColor.fromInt(0xFF2A5C8A),
          ],
        ),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            warranty.customerName,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: compact ? 18 : 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _badge('Invoice', warranty.saleNumber),
              _badge('Registration', '#${warranty.warrantyId}'),
              _badge(
                'Issued',
                _fmtDate(warranty.registeredAt),
              ),
              if (range != null) _badge('Coverage', range),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _section({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey700,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey100),
            borderRadius: pw.BorderRadius.circular(12),
            color: PdfColors.white,
          ),
          child: child,
        ),
      ],
    );
  }

  static pw.Widget _customerBlock(
    WarrantyCardDataDto data, {
    required bool compact,
  }) {
    final warranty = data.warranty;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kv('Customer', warranty.customerName),
        if ((warranty.customerPhone ?? '').trim().isNotEmpty)
          _kv('Mobile', warranty.customerPhone!.trim()),
        if ((warranty.customerEmail ?? '').trim().isNotEmpty)
          _kv('Email', warranty.customerEmail!.trim()),
        if ((warranty.customerAddress ?? '').trim().isNotEmpty)
          _kv('Address', warranty.customerAddress!.trim()),
      ],
    );
  }

  static pw.Widget _itemsTable(
    WarrantyCardDataDto data, {
    required bool compact,
  }) {
    final rows = data.warranty.items.map((item) {
      final tracking = [
        if ((item.variantName ?? '').trim().isNotEmpty)
          item.variantName!.trim(),
        if ((item.barcode ?? '').trim().isNotEmpty)
          'Code ${item.barcode!.trim()}',
        if ((item.serialNumber ?? '').trim().isNotEmpty)
          'Serial ${item.serialNumber!.trim()}',
        if ((item.batchNumber ?? '').trim().isNotEmpty)
          'Batch ${item.batchNumber!.trim()}',
      ].join(' | ');
      final coverage = [
        _fmtDate(item.warrantyStartDate),
        _fmtDate(item.warrantyEndDate),
      ].join(' to ');
      return [
        item.productName,
        tracking.isEmpty ? item.trackingType : tracking,
        _fmtQty(item.quantity),
        coverage,
      ];
    }).toList(growable: false);

    return pw.TableHelper.fromTextArray(
      headers: const ['Item', 'Traceability', 'Qty', 'Coverage'],
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: compact ? 9 : 10,
      ),
      cellStyle: pw.TextStyle(fontSize: compact ? 8.5 : 9.5),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFEAF0F6),
      ),
      border: null,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(0.7),
        3: const pw.FlexColumnWidth(1.8),
      },
    );
  }

  static pw.Widget _notesBlock(
    WarrantyCardDataDto data, {
    required bool compact,
  }) {
    final notes = (data.warranty.notes ?? '').trim();
    final bullets = <String>[
      'Present this card or invoice when requesting service support.',
      'Warranty applies only to the covered products listed on this card.',
      'Physical damage, misuse, liquid damage, and unauthorized repairs are excluded.',
      if (notes.isNotEmpty) 'Registration note: $notes',
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: bullets
          .map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• '),
                  pw.Expanded(child: pw.Text(line)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _badge(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0x33FFFFFF),
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        '$label: $value',
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static String? _coverageRange(List<WarrantyItemDto> items) {
    if (items.isEmpty) return null;
    DateTime? start;
    DateTime? end;
    for (final item in items) {
      final currentStart = item.warrantyStartDate;
      final currentEnd = item.warrantyEndDate;
      if (currentStart != null &&
          (start == null || currentStart.isBefore(start))) {
        start = currentStart;
      }
      if (currentEnd != null && (end == null || currentEnd.isAfter(end))) {
        end = currentEnd;
      }
    }
    if (start == null || end == null) return null;
    return '${_fmtDate(start)} to ${_fmtDate(end)}';
  }

  static String _fmtQty(double value) {
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  static String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }
}
