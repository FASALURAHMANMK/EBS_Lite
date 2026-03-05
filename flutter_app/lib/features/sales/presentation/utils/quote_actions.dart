import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/api_client.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/file_transfer.dart';
import '../../data/sales_repository.dart';
import 'quote_pdf.dart';

class QuoteActions {
  QuoteActions({required this.ref, required this.context});

  final WidgetRef ref;
  final BuildContext context;

  Future<void> printQuote(int quoteId) async {
    try {
      await ref.read(salesRepositoryProvider).printQuote(quoteId);
      final data = await ref.read(salesRepositoryProvider).getQuotePrintData(
            quoteId,
          );
      final quote = (data['quote'] as Map<String, dynamic>? ?? {});
      final company = (data['company'] as Map<String, dynamic>? ?? {});
      final logoUrl = _resolveLogoUrl(company);

      final bytes = await QuotePdfBuilder.buildPdfFromWidgets(
        quote,
        company,
        format: PdfPageFormat.a4,
        logoUrl: logoUrl,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
      }
    }
  }

  Future<void> shareQuote(int quoteId) async {
    try {
      await ref.read(salesRepositoryProvider).markQuoteShared(quoteId);
      final data = await ref.read(salesRepositoryProvider).getQuotePrintData(
            quoteId,
          );
      final quote = (data['quote'] as Map<String, dynamic>? ?? {});
      final company = (data['company'] as Map<String, dynamic>? ?? {});
      final logoUrl = _resolveLogoUrl(company);

      final bytes = await QuotePdfBuilder.buildPdfFromWidgets(
        quote,
        company,
        format: PdfPageFormat.a4,
        logoUrl: logoUrl,
      );

      final quoteNumber =
          (quote['quote_number']?.toString() ?? quoteId.toString()).trim();
      final fileName = 'Quote-$quoteNumber.pdf';
      final filePath = await FileTransfer.saveToTemp(bytes, fileName);
      await FileTransfer.shareTempFile(
        filePath: filePath,
        filename: fileName,
        mimeType: 'application/pdf',
        subject: 'Quote $quoteNumber',
        text: 'Please find the attached quote.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
      }
    }
  }

  String? _resolveLogoUrl(Map<String, dynamic> company) {
    final logo = company['logo'] as String?;
    if (logo == null || logo.isEmpty) return null;
    try {
      final dio = ref.read(dioProvider);
      var base = dio.options.baseUrl;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/api/v1')) {
        base = base.substring(0, base.length - '/api/v1'.length);
      }
      final url = logo.startsWith('http') ? logo : (base + logo);
      return url;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
