import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pos/data/printer_settings_repository.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  ConsumerState<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  String _connectionType = 'network';
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  String _paperSize = '80mm';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(printerSettingsRepositoryProvider);
    final s = await repo.load();
    if (s != null) {
      setState(() {
        _connectionType = s.connectionType;
        _hostCtrl.text = s.host ?? '';
        _portCtrl.text = (s.port ?? 9100).toString();
        _paperSize = s.paperSize;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(printerSettingsRepositoryProvider);
      final port = int.tryParse(_portCtrl.text.trim());
      await repo.save(PrinterSettings(
        connectionType: _connectionType,
        host: _hostCtrl.text.trim().isEmpty ? null : _hostCtrl.text.trim(),
        port: port,
        paperSize: _paperSize,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer settings saved')),
        );
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final repo = ref.read(printerSettingsRepositoryProvider);
    await repo.clear();
    if (mounted) {
      setState(() {
        _connectionType = 'network';
        _hostCtrl.text = '';
        _portCtrl.text = '9100';
        _paperSize = '80mm';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer settings cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _connectionType,
                      onChanged: (v) => setState(() => _connectionType = v ?? 'network'),
                      items: const [
                        DropdownMenuItem(value: 'network', child: Text('Network (TCP/IP)')),
                        // Future support: bluetooth, usb
                        // DropdownMenuItem(value: 'bluetooth', child: Text('Bluetooth')),
                        // DropdownMenuItem(value: 'usb', child: Text('USB')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Connection Type',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Printer IP Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (_connectionType == 'network') {
                          if (v == null || v.trim().isEmpty) return 'IP address required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Port (default 9100)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paperSize,
                      onChanged: (v) => setState(() => _paperSize = v ?? '80mm'),
                      items: const [
                        DropdownMenuItem(value: '80mm', child: Text('Thermal 80mm')),
                        DropdownMenuItem(value: '58mm', child: Text('Thermal 58mm')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Thermal Paper Size',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _saving ? null : _clear,
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: const Text('Save'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }
}

