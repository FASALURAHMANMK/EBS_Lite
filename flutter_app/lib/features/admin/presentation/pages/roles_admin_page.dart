import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../data/roles_repository.dart';
import 'role_permissions_page.dart';

class RolesAdminPage extends ConsumerStatefulWidget {
  const RolesAdminPage({super.key});

  @override
  ConsumerState<RolesAdminPage> createState() => _RolesAdminPageState();
}

class _RolesAdminPageState extends ConsumerState<RolesAdminPage> {
  bool _loading = true;
  List<RoleDto> _roles = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(rolesRepositoryProvider).listRoles();
      if (!mounted) return;
      setState(() => _roles = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({RoleDto? initial}) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => _RoleEditorDialog(initial: initial),
        ) ??
        false;
    if (ok) await _load();
  }

  Future<void> _delete(RoleDto r) async {
    if (r.isSystemRole) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete role'),
            content: Text('Delete "${r.name}"?'),
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
      await ref.read(rolesRepositoryProvider).deleteRole(r.roleId);
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
    final perms = ref.watch(authPermissionsProvider);
    final canCreate = perms.contains('CREATE_ROLES');
    final canUpdate = perms.contains('UPDATE_ROLES');
    final canDelete = perms.contains('DELETE_ROLES');
    final canAssign = perms.contains('ASSIGN_PERMISSIONS');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
              ? const Center(child: Text('No roles'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _roles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = _roles[i];
                      final subtitle = [
                        if (r.isSystemRole) 'System',
                        if (r.description.trim().isNotEmpty)
                          r.description.trim(),
                      ].join(' • ');

                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.badge_rounded),
                          title: Text(r.name),
                          subtitle: Text(subtitle.isEmpty ? '—' : subtitle),
                          onTap: canAssign
                              ? () async {
                                  final ok =
                                      await Navigator.of(context).push<bool>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  RolePermissionsPage(role: r),
                                            ),
                                          ) ??
                                          false;
                                  if (ok) await _load();
                                }
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: canUpdate
                                    ? () => _openEditor(initial: r)
                                    : null,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                onPressed: (canDelete && !r.isSystemRole)
                                    ? () => _delete(r)
                                    : null,
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _RoleEditorDialog extends ConsumerStatefulWidget {
  const _RoleEditorDialog({this.initial});

  final RoleDto? initial;

  @override
  ConsumerState<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<_RoleEditorDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r != null) {
      _name.text = r.name;
      _desc.text = r.description;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(rolesRepositoryProvider);
      final initial = widget.initial;
      if (initial == null) {
        await repo.createRole(name: name, description: _desc.text.trim());
      } else {
        await repo.updateRole(
          roleId: initial.roleId,
          name: name,
          description: _desc.text.trim(),
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
    final perms = ref.watch(authPermissionsProvider);
    final allow = initial == null
        ? perms.contains('CREATE_ROLES')
        : perms.contains('UPDATE_ROLES');
    return AlertDialog(
      title: Text(initial == null ? 'Add role' : 'Edit role'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 5,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (!allow || _saving) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
