import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../pos/data/pos_repository.dart';
import '../../../pos/data/printer_settings_repository.dart';
import '../../../pos/utils/escpos.dart';
import '../../../pos/utils/invoice_pdf.dart';
import '../../../../core/api_client.dart';

class InvoiceActions {
  InvoiceActions({required this.ref, required this.context});

  final WidgetRef ref;
  final BuildContext context;

  Future<void> printSmart(int saleId) async {
    final data = await _loadPrintData(saleId);
    final sale = (data['sale'] as Map<String, dynamic>? ?? {});
    final company = (data['company'] as Map<String, dynamic>? ?? {});
    final printers =
        await ref.read(printerSettingsRepositoryProvider).loadAll();

    PrinterDevice? target;
    if (printers.length == 1) {
      target = printers.first;
    } else {
      target = printers.firstWhere((p) => p.isDefault,
          orElse: () => PrinterDevice(
              id: '', name: '', kind: 'a4', connectionType: 'system'));
      if (target.id.isEmpty) target = null;
    }

    if (target != null) {
      await _printToPrinter(target, sale, company);
    } else {
      await _showPrintOptions(sale, company, printers);
    }
  }

  Future<void> shareInvoice(int saleId) async {
    try {
      final data = await _loadPrintData(saleId);
      final sale = (data['sale'] as Map<String, dynamic>? ?? {});
      final company = (data['company'] as Map<String, dynamic>? ?? {});
      final logoUrl = _resolveLogoUrl(company);
      final bytes = await InvoicePdfBuilder.buildPdfFromHtml(
        sale,
        company,
        format: PdfPageFormat.a4,
        logoUrl: logoUrl,
      );
      final dir = await getTemporaryDirectory();
      final saleNumber = sale['sale_number']?.toString() ?? saleId.toString();
      final fileName = 'Invoice-$saleNumber.pdf';
      final path = '${dir.path}/$fileName';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(path, name: fileName, mimeType: 'application/pdf')],
        subject: 'Invoice $saleNumber',
        text: 'Please find the attached invoice.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }

  Future<Map<String, dynamic>> _loadPrintData(int saleId) async {
    return ref.read(posRepositoryProvider).getPrintData(invoiceId: saleId);
  }

  Future<void> _showPrintOptions(
    Map<String, dynamic> sale,
    Map<String, dynamic> company,
    List<PrinterDevice> printers,
  ) async {
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Select Printer'), dense: true),
              ...printers.map((p) => ListTile(
                    leading: Icon(p.kind.startsWith('thermal')
                        ? Icons.print_rounded
                        : Icons.picture_as_pdf_rounded),
                    title: Text(p.name),
                    subtitle:
                        Text('${p.kind.toUpperCase()} • ${p.connectionType}'),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _printToPrinter(p, sale, company);
                    },
                  )),
              if (printers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(children: [
                    const Text('No printers configured. Printing to A4.'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final logoUrl = _resolveLogoUrl(company);
                        await Printing.layoutPdf(
                          onLayout: (format) =>
                              InvoicePdfBuilder.buildPdfFromWidgets(
                            sale,
                            company,
                            format: PdfPageFormat.a4,
                            logoUrl: logoUrl,
                          ),
                        );
                      },
                      child: const Text('Print A4 Now'),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _printToPrinter(
    PrinterDevice p,
    Map<String, dynamic> sale,
    Map<String, dynamic> company,
  ) async {
    try {
      switch (p.kind) {
        case 'thermal_80':
        case 'thermal_58':
          final size = p.kind == 'thermal_80' ? '80mm' : '58mm';
          if (p.connectionType == 'network') {
            await printThermalOverTcp(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else if (p.connectionType == 'bluetooth') {
            await printThermalOverBluetooth(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else if (p.connectionType == 'usb') {
            await printThermalOverUsb(
              sale: sale,
              company: company,
              settings: p,
              paperSize: size,
            );
          } else {
            throw Exception('Unsupported connection type: ${p.connectionType}');
          }
          break;
        case 'a5':
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(
              sale,
              company,
              format: PdfPageFormat.a5,
              logoUrl: logoUrl,
            ),
          );
          break;
        case 'a4':
        default:
          final logoUrl = _resolveLogoUrl(company);
          await Printing.layoutPdf(
            onLayout: (format) => InvoicePdfBuilder.buildPdfFromWidgets(
              sale,
              company,
              format: PdfPageFormat.a4,
              logoUrl: logoUrl,
            ),
          );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Printed via ${p.name}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
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
    } catch (_) {
      return null;
    }
  }
}
