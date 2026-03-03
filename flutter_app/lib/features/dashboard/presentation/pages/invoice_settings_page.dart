import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_models.dart';
import '../../data/settings_repository.dart';
import 'invoice_templates_page.dart';

class InvoiceSettingsPage extends ConsumerStatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  ConsumerState<InvoiceSettingsPage> createState() =>
      _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends ConsumerState<InvoiceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _prefix = TextEditingController();
  final _nextNumber = TextEditingController();
  final _notes = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _prefix.dispose();
    _nextNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cfg =
          await ref.read(settingsRepositoryProvider).getInvoiceSettings();
      _prefix.text = cfg.prefix ?? '';
      _nextNumber.text = cfg.nextNumber?.toString() ?? '';
      _notes.text = cfg.notes ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final prefix = _prefix.text.trim();
      final nextRaw = _nextNumber.text.trim();
      final nextNumber = nextRaw.isEmpty ? null : int.tryParse(nextRaw);
      if (nextRaw.isNotEmpty && nextNumber == null) {
        throw Exception('Invalid next number');
      }
      final notes = _notes.text.trim();
      await ref.read(settingsRepositoryProvider).updateInvoiceSettings(
            InvoiceSettingsDto(
              prefix: prefix.isEmpty ? null : prefix,
              nextNumber: nextNumber,
              notes: notes.isEmpty ? null : notes,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Numbering',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _prefix,
                            decoration: const InputDecoration(
                              labelText: 'Prefix',
                              helperText: 'Example: INV',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nextNumber,
                            decoration: const InputDecoration(
                              labelText: 'Next number',
                              helperText: 'Example: 1001',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final raw = (v ?? '').trim();
                              if (raw.isEmpty) return null;
                              final i = int.tryParse(raw);
                              if (i == null) return 'Enter an integer';
                              if (i < 0) return 'Must be >= 0';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            decoration: const InputDecoration(
                              labelText: 'Default notes',
                            ),
                            minLines: 2,
                            maxLines: 6,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.description_rounded),
                  title: const Text('Invoice templates'),
                  subtitle: const Text('Create and manage templates'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: theme.colorScheme.surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InvoiceTemplatesPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
