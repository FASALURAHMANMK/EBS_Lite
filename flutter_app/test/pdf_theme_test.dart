import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ebs_lite/core/pdf/pdf_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF theme loads and can render a bullet character', () async {
    final theme = await PdfTheme.inter();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Center(child: pw.Text('Tax • Base')),
      ),
    );

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });
}
