import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../data/printer_profiles_repository.dart';

class PrinterProfilesPage extends ConsumerStatefulWidget {
  const PrinterProfilesPage({super.key});

  @override
  ConsumerState<PrinterProfilesPage> createState() =>
      _PrinterProfilesPageState();
}

class _PrinterProfilesPageState extends ConsumerState<PrinterProfilesPage> {
  bool _loading = true;
  List<PrinterProfileDto> _printers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(printerProfilesRepositoryProvider).list();
      if (!mounted) return;
      setState(() => _printers = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({PrinterProfileDto? initial}) async {
    final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _PrinterProfileEditorPage(initial: initial),
          ),
        ) ??
        false;
    if (ok) {
      await _load();
    }
  }

  Future<void> _delete(PrinterProfileDto p) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete printer'),
            content: Text('Delete "${p.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await ref.read(printerProfilesRepositoryProvider).delete(p.printerId);
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
      appBar: AppBar(title: const Text('Printer Profiles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _printers.isEmpty
              ? const Center(child: Text('No printers configured'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _printers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = _printers[i];
                      final meta = [
                        p.printerType,
                        if (p.paperSize != null && p.paperSize!.isNotEmpty)
                          p.paperSize!,
                        if (p.locationId != null) 'Location ${p.locationId}',
                        if (p.isDefault) 'Default',
                        if (!p.isActive) 'Inactive',
                      ].join(' • ');
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.print_rounded),
                          title: Text(p.name),
                          subtitle: Text(meta),
                          onTap: () => _openEditor(initial: p),
                          trailing: IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _delete(p),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _PrinterProfileEditorPage extends ConsumerStatefulWidget {
  const _PrinterProfileEditorPage({this.initial});

  final PrinterProfileDto? initial;

  @override
  ConsumerState<_PrinterProfileEditorPage> createState() =>
      _PrinterProfileEditorPageState();
}

class _PrinterProfileEditorPageState
    extends ConsumerState<_PrinterProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _paper = TextEditingController();
  final _locationId = TextEditingController();
  final _conn = TextEditingController();

  bool _isDefault = false;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _name.text = p.name;
      _type.text = p.printerType;
      _paper.text = p.paperSize ?? '';
      _locationId.text = p.locationId?.toString() ?? '';
      _conn.text = ref
          .read(printerProfilesRepositoryProvider)
          .encodeConnectivity(p.connectivity);
      _isDefault = p.isDefault;
      _isActive = p.isActive;
    } else {
      _conn.text = '{}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _paper.dispose();
    _locationId.dispose();
    _conn.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(printerProfilesRepositoryProvider);
      final name = _name.text.trim();
      final type = _type.text.trim();
      final paper = _paper.text.trim();
      final locRaw = _locationId.text.trim();
      final loc = locRaw.isEmpty ? null : int.tryParse(locRaw);
      if (locRaw.isNotEmpty && loc == null) {
        throw Exception('Invalid location id');
      }
      final conn = repo.decodeConnectivity(_conn.text);
      final initial = widget.initial;
      if (initial == null) {
        await repo.create(
          PrinterProfileDto(
            printerId: 0,
            locationId: loc,
            name: name,
            printerType: type,
            paperSize: paper.isEmpty ? null : paper,
            connectivity: conn,
            isDefault: _isDefault,
            isActive: _isActive,
          ),
        );
      } else {
        await repo.update(
          PrinterProfileDto(
            printerId: initial.printerId,
            locationId: loc,
            name: name,
            printerType: type,
            paperSize: paper.isEmpty ? null : paper,
            connectivity: conn,
            isDefault: _isDefault,
            isActive: _isActive,
          ),
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
        title: Text(initial == null ? 'Add printer' : 'Edit printer'),
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
                    labelText: 'Printer type',
                    helperText: 'Example: THERMAL, A4, SYSTEM',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paper,
                  decoration: const InputDecoration(
                    labelText: 'Paper size (optional)',
                    helperText: 'Example: 80mm, A4',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationId,
                  decoration: const InputDecoration(
                    labelText: 'Location ID (optional)',
                  ),
                  keyboardType: TextInputType.number,
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
                  controller: _conn,
                  decoration: const InputDecoration(
                    labelText: 'Connectivity (JSON)',
                    helperText: 'Raw JSON object stored in the backend',
                    alignLabelWithHint: true,
                  ),
                  minLines: 6,
                  maxLines: 16,
                  validator: (v) {
                    try {
                      ref
                          .read(printerProfilesRepositoryProvider)
                          .decodeConnectivity(v ?? '');
                      return null;
                    } catch (_) {
                      return 'Invalid JSON object';
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
