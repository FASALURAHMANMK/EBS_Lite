import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Centralized PDF theming so generated PDFs don't fall back to Helvetica
/// (which has very limited Unicode support in dart_pdf).
class PdfTheme {
  PdfTheme._();

  static Future<pw.ThemeData>? _cached;

  static Future<pw.ThemeData> inter() {
    return _cached ??= _loadInter();
  }

  static Future<pw.ThemeData> _loadInter() async {
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/pdf_fonts/Inter-Regular.ttf'));
    final bold =
        pw.Font.ttf(await rootBundle.load('assets/pdf_fonts/Inter-Bold.ttf'));

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      italic: regular,
      boldItalic: bold,
    );
  }
}
