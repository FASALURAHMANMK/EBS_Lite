import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_confirm_dialog.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../data/invoice_templates_repository.dart';

class InvoiceTemplatesPage extends ConsumerStatefulWidget {
  const InvoiceTemplatesPage({super.key});

  @override
  ConsumerState<InvoiceTemplatesPage> createState() =>
      _InvoiceTemplatesPageState();
}

class _InvoiceTemplatesPageState extends ConsumerState<InvoiceTemplatesPage> {
  bool _loading = true;
  List<InvoiceTemplateDto> _templates = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(invoiceTemplatesRepositoryProvider).list();
      if (!mounted) return;
      setState(() => _templates = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({InvoiceTemplateDto? initial}) async {
    final auth = ref.read(authNotifierProvider);
    final companyId = auth.company?.companyId;
    if (companyId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No company context')));
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _InvoiceTemplateEditorPage(
              companyId: companyId,
              initial: initial,
            ),
          ),
        ) ??
        false;
    if (ok) {
      await _load();
    }
  }

  Future<void> _delete(InvoiceTemplateDto t) async {
    final ok = await showAppConfirmDialog(
      context,
      title: 'Delete Template',
      message: 'Delete "${t.name}"? This cannot be undone.',
      confirmLabel: 'Delete',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(invoiceTemplatesRepositoryProvider).delete(t.templateId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Templates'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('No templates'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = _templates[i];
                      final meta = [
                        t.templateType,
                        if (t.isDefault) 'Default',
                        if (!t.isActive) 'Inactive',
                      ].where((e) => e.trim().isNotEmpty).join(' • ');
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.description_rounded),
                          title: Text(t.name),
                          subtitle: Text(meta.isEmpty ? '—' : meta),
                          onTap: () => _openEditor(initial: t),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _delete(t),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InvoiceTemplateEditorPage extends ConsumerStatefulWidget {
  const _InvoiceTemplateEditorPage({
    required this.companyId,
    this.initial,
  });

  final int companyId;
  final InvoiceTemplateDto? initial;

  @override
  ConsumerState<_InvoiceTemplateEditorPage> createState() =>
      _InvoiceTemplateEditorPageState();
}

class _InvoiceTemplateEditorPageState
    extends ConsumerState<_InvoiceTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _primaryLang = TextEditingController();
  final _secondaryLang = TextEditingController();
  final _layout = TextEditingController();
  bool _isDefault = false;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _name.text = t.name;
      _type.text = t.templateType;
      _primaryLang.text = t.primaryLanguage ?? '';
      _secondaryLang.text = t.secondaryLanguage ?? '';
      _layout.text = ref
          .read(invoiceTemplatesRepositoryProvider)
          .encodeLayoutJson(t.layout);
      _isDefault = t.isDefault;
      _isActive = t.isActive;
    } else {
      _layout.text = '{}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _primaryLang.dispose();
    _secondaryLang.dispose();
    _layout.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(invoiceTemplatesRepositoryProvider);
      final layout = repo.decodeLayoutJson(_layout.text);
      final name = _name.text.trim();
      final type = _type.text.trim();
      final primary = _primaryLang.text.trim();
      final secondary = _secondaryLang.text.trim();
      final initial = widget.initial;
      if (initial == null) {
        await repo.create(
          companyId: widget.companyId,
          name: name,
          templateType: type,
          layout: layout,
          primaryLanguage: primary.isEmpty ? null : primary,
          secondaryLanguage: secondary.isEmpty ? null : secondary,
          isDefault: _isDefault,
          isActive: _isActive,
        );
      } else {
        await repo.update(
          templateId: initial.templateId,
          name: name,
          templateType: type,
          layout: layout,
          primaryLanguage: primary.isEmpty ? null : primary,
          secondaryLanguage: secondary.isEmpty ? null : secondary,
          isDefault: _isDefault,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final initial = widget.initial;
    return Scaffold(
      appBar: AppBar(
        title: Text(initial == null ? 'Add template' : 'Edit template'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _type,
                  decoration: const InputDecoration(
                    labelText: 'Template type',
                    helperText: 'Example: SALE_INVOICE',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _primaryLang,
                  decoration: const InputDecoration(
                    labelText: 'Primary language (optional)',
                    helperText: 'Example: en',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _secondaryLang,
                  decoration: const InputDecoration(
                    labelText: 'Secondary language (optional)',
                    helperText: 'Example: ar',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isDefault,
                  onChanged: (v) => setState(() => _isDefault = v),
                  title: const Text('Default'),
                ),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _layout,
                  decoration: const InputDecoration(
                    labelText: 'Layout (JSON)',
                    helperText: 'Raw JSON stored in the backend',
                    alignLabelWithHint: true,
                  ),
                  minLines: 8,
                  maxLines: 20,
                  validator: (v) {
                    try {
                      ref
                          .read(invoiceTemplatesRepositoryProvider)
                          .decodeLayoutJson(v ?? '');
                      return null;
                    } catch (_) {
                      return 'Invalid JSON';
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
