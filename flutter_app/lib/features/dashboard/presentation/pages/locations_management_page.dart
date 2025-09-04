import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/location_notifier.dart';
import '../../data/location_repository.dart';
import '../../data/models.dart';
import '../../../auth/controllers/auth_notifier.dart';

class LocationsManagementPage extends ConsumerStatefulWidget {
  const LocationsManagementPage({super.key});

  @override
  ConsumerState<LocationsManagementPage> createState() => _LocationsManagementPageState();
}

class _LocationsManagementPageState extends ConsumerState<LocationsManagementPage> {
  bool _busy = false;

  Future<void> _refresh() async {
    final companyId = ref.read(authNotifierProvider).company?.companyId;
    if (companyId == null) return;
    await ref.read(locationNotifierProvider.notifier).load(companyId);
  }

  Future<void> _openEditor({Location? initial}) async {
    final companyId = ref.read(authNotifierProvider).company?.companyId;
    if (companyId == null) return;
    final repo = ref.read(locationRepositoryProvider);
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? 'New Location' : 'Edit Location'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                if (initial == null) {
                  await repo.createLocation(
                    companyId: companyId,
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  );
                } else {
                  await repo.updateLocation(
                    locationId: initial.locationId,
                    name: nameCtrl.text.trim(),
                    address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  );
                }
                if (context.mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('Failed to save: $e')));
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _delete(Location loc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text("Are you sure you want to delete '${loc.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      setState(() => _busy = true);
      await ref.read(locationRepositoryProvider).deleteLocation(loc.locationId);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(locationNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: state.locations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final loc = state.locations[i];
            final selected = state.selected?.locationId == loc.locationId;
            return ListTile(
              tileColor: theme.colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(loc.name),
              leading: selected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.location_on),
              trailing: Wrap(spacing: 8, children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: _busy ? null : () => _openEditor(initial: loc),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _busy ? null : () => _delete(loc),
                ),
              ]),
              onTap: () async {
                await ref.read(locationNotifierProvider.notifier).select(loc);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text('Selected: ${loc.name}')));
                }
              },
            );
          },
        ),
      ),
    );
  }
}

