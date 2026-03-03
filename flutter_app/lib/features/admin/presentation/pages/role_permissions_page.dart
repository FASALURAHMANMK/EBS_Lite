import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../data/roles_repository.dart';

class RolePermissionsPage extends ConsumerStatefulWidget {
  const RolePermissionsPage({super.key, required this.role});

  final RoleDto role;

  @override
  ConsumerState<RolePermissionsPage> createState() =>
      _RolePermissionsPageState();
}

class _RolePermissionsPageState extends ConsumerState<RolePermissionsPage> {
  bool _loading = true;
  bool _saving = false;
  String _query = '';

  List<PermissionDto> _all = const [];
  Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(rolesRepositoryProvider);
      final results = await Future.wait([
        repo.listPermissions(),
        repo.getRolePermissions(widget.role.roleId),
      ]);
      final all = results[0] as List<PermissionDto>;
      final roleWith = results[1] as RoleWithPermissionsDto;
      final selected = roleWith.permissions.map((p) => p.permissionId).toSet();
      if (!mounted) return;
      setState(() {
        _all = all;
        _selected = selected;
      });
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
    final perms = ref.read(authPermissionsProvider);
    if (!perms.contains('ASSIGN_PERMISSIONS')) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(rolesRepositoryProvider)
          .assignPermissions(widget.role.roleId, _selected.toList()..sort());
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final perms = ref.watch(authPermissionsProvider);
    final canAssign = perms.contains('ASSIGN_PERMISSIONS');

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.module.toLowerCase().contains(q) ||
                p.action.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q))
            .toList();

    filtered.sort((a, b) {
      final am = a.module.compareTo(b.module);
      if (am != 0) return am;
      return a.name.compareTo(b.name);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Permissions: ${widget.role.name}'),
        actions: [
          TextButton(
            onPressed: (!canAssign || _saving) ? null : _save,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search permissions',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final enabled = canAssign;
                      final selected = _selected.contains(p.permissionId);
                      return Card(
                        elevation: 0,
                        child: CheckboxListTile(
                          value: selected,
                          onChanged: !enabled
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(p.permissionId);
                                    } else {
                                      _selected.remove(p.permissionId);
                                    }
                                  });
                                },
                          title: Text(p.name),
                          subtitle: Text(
                            '${p.module} • ${p.action}'
                            '${p.description.trim().isEmpty ? '' : '\n${p.description.trim()}'}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
