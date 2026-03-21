import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/api_client.dart';
import '../../../../core/error_handler.dart';
import '../../data/warranty_repository.dart';
import 'warranty_card_pdf.dart';

class WarrantyCardActions {
  WarrantyCardActions({required this.ref, required this.context});

  final WidgetRef ref;
  final BuildContext context;

  Future<void> printWarrantyCard(
    int warrantyId, {
    required PdfPageFormat format,
  }) async {
    try {
      final data = await ref
          .read(warrantyRepositoryProvider)
          .getWarrantyCardData(warrantyId);
      final logoUrl = _resolveLogoUrl(data.company.logo);
      await Printing.layoutPdf(
        onLayout: (_) => WarrantyCardPdfBuilder.build(
          data,
          format: format,
          logoUrl: logoUrl,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  Future<void> shareWarrantyCard(
    int warrantyId, {
    required PdfPageFormat format,
  }) async {
    try {
      final data = await ref
          .read(warrantyRepositoryProvider)
          .getWarrantyCardData(warrantyId);
      final logoUrl = _resolveLogoUrl(data.company.logo);
      final bytes = await WarrantyCardPdfBuilder.build(
        data,
        format: format,
        logoUrl: logoUrl,
      );
      final dir = await getTemporaryDirectory();
      final fileName =
          'Warranty-${data.warranty.saleNumber}-${data.warranty.warrantyId}-${format == PdfPageFormat.a5 ? 'A5' : 'A4'}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, name: fileName, mimeType: 'application/pdf')],
        subject: 'Warranty card ${data.warranty.saleNumber}',
        text: 'Please find the attached warranty card.',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  String? _resolveLogoUrl(String? logo) {
    if (logo == null || logo.trim().isEmpty) return null;
    try {
      final dio = ref.read(dioProvider);
      var base = dio.options.baseUrl;
      if (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      if (base.endsWith('/api/v1')) {
        base = base.substring(0, base.length - '/api/v1'.length);
      }
      return logo.startsWith('http') ? logo : '$base$logo';
    } catch (_) {
      return null;
    }
  }
}
