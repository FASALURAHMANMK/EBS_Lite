import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart' hide PrinterDevice;
import 'dart:io';

import '../../../pos/data/printer_settings_repository.dart';
import '../../../pos/utils/escpos.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  ConsumerState<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  bool _loading = true;
  List<PrinterDevice> _printers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = ref.read(printerSettingsRepositoryProvider);
    final list = await repo.loadAll();
    if (!mounted) return;
    setState(() {
      _printers = list;
      _loading = false;
    });
  }

  Future<void> _setDefault(PrinterDevice p) async {
    await ref.read(printerSettingsRepositoryProvider).setDefault(p.id);
    await _load();
  }

  Future<void> _delete(PrinterDevice p) async {
    await ref.read(printerSettingsRepositoryProvider).remove(p.id);
    await _load();
  }

  Future<void> _test(PrinterDevice p) async {
    try {
      if (p.kind.startsWith('thermal')) {
        final bytes = buildTestTicketBytes(charsPerLine: p.kind == 'thermal_58' ? 32 : 48);
        if (p.connectionType == 'network') {
          if (p.host != null && (p.port ?? 0) > 0) {
            final socket = await Socket.connect(p.host, p.port!);
            socket.add(bytes);
            await socket.flush();
            await socket.close();
          } else {
            throw Exception('Missing host/port');
          }
        } else if (p.connectionType == 'bluetooth') {
          final printerManager = PrinterManager.instance;
          final btName = p.btName ?? '';
          final btAddr = p.btAddress ?? '';
          if (btAddr.isEmpty) throw Exception('Missing Bluetooth address');
          await printerManager.connect(
            type: PrinterType.bluetooth,
            model: BluetoothPrinterInput(name: btName, address: btAddr),
          );
          await printerManager.send(type: PrinterType.bluetooth, bytes: bytes);
          await printerManager.disconnect(type: PrinterType.bluetooth);
        } else if (p.connectionType == 'usb') {
          final printerManager = PrinterManager.instance;
          await printerManager.connect(
            type: PrinterType.usb,
            model: UsbPrinterInput(
              name: p.name,
              productId: p.usbProductId?.toString(),
              vendorId: p.usbVendorId?.toString(),
            ),
          );
          await printerManager.send(type: PrinterType.usb, bytes: bytes);
          await printerManager.disconnect(type: PrinterType.usb);
        }
      } else {
        await Printing.layoutPdf(onLayout: (format) async {
          final doc = pw.Document();
          doc.addPage(pw.Page(build: (ctx) => pw.Center(child: pw.Text('Test Print - ${p.name}'))));
          return doc.save();
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test sent to ${p.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  Future<void> _addOrEdit({PrinterDevice? edit}) async {
    final result = await showDialog<PrinterDevice>(
      context: context,
      builder: (_) => _PrinterEditDialog(initial: edit),
    );
    if (result != null) {
      final repo = ref.read(printerSettingsRepositoryProvider);
      if (edit == null) {
        await repo.add(result);
      } else {
        await repo.update(result);
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _printers.isEmpty
              ? const Center(child: Text('No printers configured'))
              : ListView.separated(
                  itemCount: _printers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = _printers[index];
                    final subtitle = _subtitleFor(p);
                    return ListTile(
                      leading: Icon(
                        p.kind.startsWith('thermal') ? Icons.print_rounded : Icons.picture_as_pdf_rounded,
                      ),
                      title: Text('${p.name} (${p.kind.toUpperCase()})'),
                      subtitle: Text(subtitle),
                      trailing: Wrap(spacing: 8, children: [
                        if (p.isDefault) const Icon(Icons.star, color: Colors.amber)
                        else TextButton(onPressed: () => _setDefault(p), child: const Text('Set Default')),
                        IconButton(onPressed: () => _test(p), icon: const Icon(Icons.science_outlined)),
                        IconButton(onPressed: () => _addOrEdit(edit: p), icon: const Icon(Icons.edit_rounded)),
                        IconButton(onPressed: () => _delete(p), icon: const Icon(Icons.delete_outline_rounded)),
                      ]),
                    );
                  },
                ),
    );
  }

  String _subtitleFor(PrinterDevice p) {
    switch (p.connectionType) {
      case 'network':
        return 'Network: ${p.host}:${p.port}';
      case 'bluetooth':
        return 'Bluetooth: ${p.btName ?? p.btAddress ?? ''}';
      case 'usb':
        return 'USB: vendor=${p.usbVendorId}, product=${p.usbProductId}';
      case 'system':
      default:
        return 'System printer';
    }
  }
}

class _PrinterEditDialog extends StatefulWidget {
  const _PrinterEditDialog({this.initial});
  final PrinterDevice? initial;

  @override
  State<_PrinterEditDialog> createState() => _PrinterEditDialogState();
}

class _PrinterEditDialogState extends State<_PrinterEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String _kind = 'a4';
  String _conn = 'system';
  final _host = TextEditingController();
  final _port = TextEditingController(text: '9100');
  final _btName = TextEditingController();
  final _btAddr = TextEditingController();
  final _usbVid = TextEditingController();
  final _usbPid = TextEditingController();
  bool _isDefault = false;
  String _id = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    if (widget.initial != null) {
      _id = widget.initial!.id;
      _kind = widget.initial!.kind;
      _conn = widget.initial!.connectionType;
      _host.text = widget.initial!.host ?? '';
      _port.text = (widget.initial!.port ?? 9100).toString();
      _btName.text = widget.initial!.btName ?? '';
      _btAddr.text = widget.initial!.btAddress ?? '';
      _usbVid.text = (widget.initial!.usbVendorId ?? '').toString();
      _usbPid.text = (widget.initial!.usbProductId ?? '').toString();
      _isDefault = widget.initial!.isDefault;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    _btName.dispose();
    _btAddr.dispose();
    _usbVid.dispose();
    _usbPid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isThermal = _kind.startsWith('thermal');
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add Printer' : 'Edit Printer'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Printer Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  items: const [
                    DropdownMenuItem(value: 'thermal_80', child: Text('Thermal 80mm')),
                    DropdownMenuItem(value: 'thermal_58', child: Text('Thermal 58mm')),
                    DropdownMenuItem(value: 'a4', child: Text('A4')),
                    DropdownMenuItem(value: 'a5', child: Text('A5')),
                  ],
                  onChanged: (v) => setState(() {
                    _kind = v ?? 'a4';
                    if (_kind.startsWith('thermal') && _conn == 'system') _conn = 'network';
                    if (!_kind.startsWith('thermal')) _conn = 'system';
                  }),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _conn,
                  items: [
                    if (isThermal) const DropdownMenuItem(value: 'network', child: Text('Network (TCP/IP)')),
                    if (isThermal) const DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth')),
                    if (isThermal) const DropdownMenuItem(value: 'usb', child: Text('USB')),
                    if (!isThermal) const DropdownMenuItem(value: 'system', child: Text('System')),
                  ],
                  onChanged: (v) => setState(() => _conn = v ?? (isThermal ? 'network' : 'system')),
                  decoration: const InputDecoration(labelText: 'Connection'),
                ),
                if (isThermal && _conn == 'network') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _host,
                    decoration: const InputDecoration(labelText: 'IP Address'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'IP required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: 'Port (9100)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (isThermal && _conn == 'bluetooth') ...[
                  const SizedBox(height: 8),
                  TextFormField(controller: _btName, decoration: const InputDecoration(labelText: 'BT Name (optional)')),
                  const SizedBox(height: 8),
                  TextFormField(controller: _btAddr, decoration: const InputDecoration(labelText: 'BT Address/MAC')),
                ],
                if (isThermal && _conn == 'usb') ...[
                  const SizedBox(height: 8),
                  TextFormField(controller: _usbVid, decoration: const InputDecoration(labelText: 'USB Vendor ID')),
                  const SizedBox(height: 8),
                  TextFormField(controller: _usbPid, decoration: const InputDecoration(labelText: 'USB Product ID')),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Set as default'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final form = _formKey.currentState;
            if (form == null) return;
            if (!form.validate()) return;
            final dev = PrinterDevice(
              id: _id,
              name: _name.text.trim(),
              kind: _kind,
              connectionType: _conn,
              host: _host.text.trim().isEmpty ? null : _host.text.trim(),
              port: int.tryParse(_port.text.trim()),
              btName: _btName.text.trim().isEmpty ? null : _btName.text.trim(),
              btAddress: _btAddr.text.trim().isEmpty ? null : _btAddr.text.trim(),
              usbVendorId: int.tryParse(_usbVid.text.trim()),
              usbProductId: int.tryParse(_usbPid.text.trim()),
              isDefault: _isDefault,
            );
            Navigator.of(context).pop(dev);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
