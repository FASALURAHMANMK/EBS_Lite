import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/settings_models.dart';
import '../../data/settings_repository.dart';

class TaxSettingsPage extends ConsumerStatefulWidget {
  const TaxSettingsPage({super.key});

  @override
  ConsumerState<TaxSettingsPage> createState() => _TaxSettingsPageState();
}

class _TaxSettingsPageState extends ConsumerState<TaxSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _taxName = TextEditingController();
  final _taxPercent = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _taxName.dispose();
    _taxPercent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cfg = await ref.read(settingsRepositoryProvider).getTaxSettings();
      _taxName.text = cfg.taxName ?? '';
      _taxPercent.text = cfg.taxPercent?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _taxName.text.trim();
      final percentRaw = _taxPercent.text.trim();
      final percent = percentRaw.isEmpty ? null : double.tryParse(percentRaw);
      if (percentRaw.isNotEmpty && percent == null) {
        throw Exception('Invalid tax percent');
      }
      await ref.read(settingsRepositoryProvider).updateTaxSettings(
            TaxSettingsDto(
              taxName: name.isEmpty ? null : name,
              taxPercent: percent,
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
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tax Settings')),
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
                            'Default tax settings',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _taxName,
                            decoration:
                                const InputDecoration(labelText: 'Tax name'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _taxPercent,
                            decoration: const InputDecoration(
                              labelText: 'Tax percent',
                              helperText: 'Example: 5 or 5.0',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              final raw = (v ?? '').trim();
                              if (raw.isEmpty) return null;
                              final d = double.tryParse(raw);
                              if (d == null) return 'Enter a number';
                              if (d < 0) return 'Must be >= 0';
                              return null;
                            },
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
              ],
            ),
    );
  }
}
