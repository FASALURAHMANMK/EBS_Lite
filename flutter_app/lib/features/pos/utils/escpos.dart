import 'dart:convert';
import 'dart:io';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart' hide PrinterDevice;

import '../data/printer_settings_repository.dart';

class EscPos {
  final List<int> _bytes = [];
  final int charsPerLine;

  EscPos({required this.charsPerLine});

  void init() {
    _bytes.addAll([0x1B, 0x40]); // Initialize
  }

  void setAlign(int align) {
    // 0 left, 1 center, 2 right
    _bytes.addAll([0x1B, 0x61, align]);
  }

  void setBold(bool on) {
    _bytes.addAll([0x1B, 0x45, on ? 1 : 0]);
  }

  void setSize({int width = 0, int height = 0}) {
    // width/height: 0..7 (multiplier flags)
    final n = (width << 4) | height;
    _bytes.addAll([0x1D, 0x21, n]);
  }

  void text(String s) {
    _bytes.addAll(latin1.encode(s));
    _bytes.add(0x0A); // LF
  }

  void hr() {
    text('-' * charsPerLine);
  }

  void feed([int n = 1]) {
    for (var i = 0; i < n; i++) {
      _bytes.add(0x0A);
    }
  }

  void cut() {
    _bytes.addAll([0x1D, 0x56, 0x00]); // full cut
  }

  List<int> bytes() => List<int>.from(_bytes);
}

Future<void> printThermalOverTcp({
  required Map<String, dynamic> sale,
  required Map<String, dynamic> company,
  required PrinterDevice settings,
  required String paperSize, // '58mm' or '80mm'
}) async {
  final width = paperSize == '58mm' ? 32 : 48; // typical char widths
  final p = _ticketFromSale(sale: sale, company: company, charsPerLine: width);

  if (settings.connectionType == 'network' && settings.host != null && (settings.port ?? 0) > 0) {
    final socket = await Socket.connect(settings.host, settings.port!);
    socket.add(p.bytes());
    await socket.flush();
    await socket.close();
  } else {
    throw Exception('Unsupported connection or missing host/port');
  }
}

Future<void> printThermalOverBluetooth({
  required Map<String, dynamic> sale,
  required Map<String, dynamic> company,
  required PrinterDevice settings,
  required String paperSize,
}) async {
  final width = paperSize == '58mm' ? 32 : 48;
  final ticket = _ticketFromSale(sale: sale, company: company, charsPerLine: width);
  final printerManager = PrinterManager.instance;
  final btName = settings.btName ?? '';
  final btAddr = settings.btAddress ?? '';
  if (btAddr.isEmpty) throw Exception('Missing Bluetooth address');
  await printerManager.connect(
    type: PrinterType.bluetooth,
    model: BluetoothPrinterInput(name: btName, address: btAddr),
  );
  await printerManager.send(type: PrinterType.bluetooth, bytes: ticket.bytes());
  await printerManager.disconnect(type: PrinterType.bluetooth);
}

Future<void> printThermalOverUsb({
  required Map<String, dynamic> sale,
  required Map<String, dynamic> company,
  required PrinterDevice settings,
  required String paperSize,
}) async {
  final width = paperSize == '58mm' ? 32 : 48;
  final ticket = _ticketFromSale(sale: sale, company: company, charsPerLine: width);
  final printerManager = PrinterManager.instance;
  await printerManager.connect(
    type: PrinterType.usb,
    model: UsbPrinterInput(
      name: settings.name,
      productId: settings.usbProductId?.toString(),
      vendorId: settings.usbVendorId?.toString(),
    ),
  );
  await printerManager.send(type: PrinterType.usb, bytes: ticket.bytes());
  await printerManager.disconnect(type: PrinterType.usb);
}

EscPos _ticketFromSale({
  required Map<String, dynamic> sale,
  required Map<String, dynamic> company,
  required int charsPerLine,
}) {
  final p = EscPos(charsPerLine: charsPerLine)..init();

  final saleNumber = (sale['sale_number'] as String?) ?? '';
  final items = (sale['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  final subtotal = _asDouble(sale['subtotal']);
  final tax = _asDouble(sale['tax_amount']);
  final discount = _asDouble(sale['discount_amount']);
  final total = _asDouble(sale['total_amount']);

  final name = (company['name'] as String?) ?? '';
  final address = (company['address'] as String?) ?? '';
  final phone = (company['phone'] as String?) ?? '';

  p.setAlign(1);
  p.setBold(true);
  p.text(name);
  p.setBold(false);
  if (address.isNotEmpty) p.text(address);
  if (phone.isNotEmpty) p.text('Tel: $phone');
  p.hr();
  p.setAlign(0);
  p.text('Invoice: $saleNumber');
  p.hr();

  for (final it in items) {
    final n = _productName(it);
    final qty = _asDouble(it['quantity']);
    final unit = _asDouble(it['unit_price']);
    final lineTotal = _asDouble(it['line_total']);
    p.text(n);
    final right = '${_fmt(qty)} x ${_fmt(unit)}   ${_fmt(lineTotal)}';
    p.text(_padLeft(right, charsPerLine));
  }
  p.hr();
  p.text(_padBoth('Subtotal', _fmt(subtotal), charsPerLine));
  p.text(_padBoth('Tax', _fmt(tax), charsPerLine));
  if (discount > 0) p.text(_padBoth('Discount', _fmt(discount), charsPerLine));
  p.setBold(true);
  p.text(_padBoth('TOTAL', _fmt(total), charsPerLine));
  p.setBold(false);
  p.feed(2);
  p.setAlign(1);
  p.text('Thank you!');
  p.feed(3);
  p.cut();
  return p;
}

List<int> buildTestTicketBytes({int charsPerLine = 48}) {
  final p = EscPos(charsPerLine: charsPerLine)..init();
  p.setAlign(1);
  p.setBold(true);
  p.text('TEST PRINT');
  p.setBold(false);
  p.text('------------------------------');
  p.text('Connection OK.');
  p.feed(3);
  p.cut();
  return p.bytes();
}

String _productName(Map<String, dynamic> it) {
  if (it['product'] is Map<String, dynamic>) {
    return (it['product']['name'] as String?) ?? (it['product_name'] as String? ?? 'Item');
  }
  return (it['product_name'] as String?) ?? 'Item';
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String _fmt(double v) => v.toStringAsFixed(2);

String _padBoth(String left, String right, int width) {
  final space = width - left.length - right.length;
  if (space <= 0) return '$left $right';
  return left + (' ' * space) + right;
}

String _padLeft(String text, int width) {
  if (text.length >= width) return text;
  return (' ' * (width - text.length)) + text;
}


