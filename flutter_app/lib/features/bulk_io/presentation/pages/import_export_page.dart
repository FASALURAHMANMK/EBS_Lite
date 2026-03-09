import 'package:ebs_lite/core/error_handler.dart';
import 'package:ebs_lite/features/auth/controllers/auth_permissions_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import_export_repository.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PlatformFile?> _pickExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: const ['xlsx'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = ref.watch(authPermissionsProvider);
    bool has(String p) => perms.contains(p);

    final canCustomerImport = has('CREATE_CUSTOMERS');
    final canCustomerExport = has('VIEW_CUSTOMERS');
    final canSupplierImport = has('CREATE_SUPPLIERS');
    final canSupplierExport = has('VIEW_SUPPLIERS');
    final canInventoryImport = has('ADJUST_STOCK');
    final canInventoryExport = has('VIEW_INVENTORY');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CardSection(
              title: 'Customers',
              subtitle: 'Import/export customers via Excel (.xlsx)',
              icon: Icons.people_rounded,
              canImport: canCustomerImport,
              canExport: canCustomerExport,
              onImport: () => _run(() async {
                final messenger = ScaffoldMessenger.of(context);
                final f = await _pickExcel();
                if (f == null) return;
                final path = f.path;
                if (path == null || path.isEmpty) {
                  throw Exception('File path unavailable');
                }
                final count = await ref
                    .read(importExportRepositoryProvider)
                    .importCustomers(filePath: path, filename: f.name);
                if (!mounted) return;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(
                        'Customers import completed${count == null ? '' : ' ($count created)'}'),
                  ));
              }),
              onExport: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .exportCustomers();
              }),
              onTemplate: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadCustomersTemplate();
              }),
              onExample: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadCustomersExample();
              }),
            ),
            const SizedBox(height: 12),
            _CardSection(
              title: 'Suppliers',
              subtitle: 'Import/export suppliers via Excel (.xlsx)',
              icon: Icons.factory_rounded,
              canImport: canSupplierImport,
              canExport: canSupplierExport,
              onImport: () => _run(() async {
                final messenger = ScaffoldMessenger.of(context);
                final f = await _pickExcel();
                if (f == null) return;
                final path = f.path;
                if (path == null || path.isEmpty) {
                  throw Exception('File path unavailable');
                }
                final count = await ref
                    .read(importExportRepositoryProvider)
                    .importSuppliers(filePath: path, filename: f.name);
                if (!mounted) return;
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(
                        'Suppliers import completed${count == null ? '' : ' ($count created)'}'),
                  ));
              }),
              onExport: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .exportSuppliers();
              }),
              onTemplate: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadSuppliersTemplate();
              }),
              onExample: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadSuppliersExample();
              }),
            ),
            const SizedBox(height: 12),
            _CardSection(
              title: 'Inventory',
              subtitle: 'Import/export inventory via Excel (.xlsx)',
              icon: Icons.inventory_2_rounded,
              canImport: canInventoryImport,
              canExport: canInventoryExport,
              onImport: () => _run(() async {
                final messenger = ScaffoldMessenger.of(context);
                final f = await _pickExcel();
                if (f == null) return;
                final path = f.path;
                if (path == null || path.isEmpty) {
                  throw Exception('File path unavailable');
                }
                final counts = await ref
                    .read(importExportRepositoryProvider)
                    .importInventory(filePath: path, filename: f.name);
                if (!mounted) return;

                var msg = 'Inventory import completed';
                if (counts != null && counts.isNotEmpty) {
                  final parts = <String>[];
                  final created = counts['created'];
                  final updated = counts['updated'];
                  final skipped = counts['skipped'];
                  final errors = counts['errors'];
                  if (created != null) parts.add('$created created');
                  if (updated != null) parts.add('$updated updated');
                  if (skipped != null) parts.add('$skipped skipped');
                  if (errors != null) parts.add('$errors errors');
                  if (parts.isNotEmpty) msg = '$msg (${parts.join(', ')})';
                }
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(msg)));
              }),
              onExport: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .exportInventory();
              }),
              onTemplate: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadInventoryTemplate();
              }),
              onExample: () => _run(() async {
                await ref
                    .read(importExportRepositoryProvider)
                    .downloadInventoryExample();
              }),
            ),
            const SizedBox(height: 16),
            if (_busy)
              Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Expanded(child: Text('Working...')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.canImport,
    required this.canExport,
    required this.onImport,
    required this.onExport,
    required this.onTemplate,
    required this.onExample,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool canImport;
  final bool canExport;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onTemplate;
  final VoidCallback onExample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canImport ? onImport : null,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Import'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canExport ? onExport : null,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: canImport ? onTemplate : null,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Template'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: canImport ? onExample : null,
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Example'),
                  ),
                ),
              ],
            ),
            if (!canImport || !canExport)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Permissions:'
                  '${canImport ? '' : ' import disabled'}'
                  '${canExport ? '' : ' export disabled'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
