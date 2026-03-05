import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../auth/controllers/auth_permissions_provider.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../data/users_repository.dart';
import '../../data/roles_repository.dart';

class UsersAdminPage extends ConsumerStatefulWidget {
  const UsersAdminPage({super.key});

  @override
  ConsumerState<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends ConsumerState<UsersAdminPage> {
  bool _loading = true;
  List<AdminUserDto> _users = const [];
  List<RoleDto> _roles = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usersRepo = ref.read(usersRepositoryProvider);
      final rolePerms = ref.read(authPermissionsProvider);
      final canViewRoles = rolePerms.contains('VIEW_ROLES');

      final users = await usersRepo.listUsers();
      List<RoleDto> roles = const <RoleDto>[];
      if (canViewRoles) {
        try {
          roles = await ref.read(rolesRepositoryProvider).listRoles();
        } catch (_) {
          roles = const <RoleDto>[];
        }
      }
      if (!mounted) return;
      setState(() {
        _users = users;
        _roles = roles;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleName(int? roleId) {
    if (roleId == null) return '—';
    final r = _roles.where((x) => x.roleId == roleId).toList();
    return r.isEmpty ? 'Role $roleId' : r.first.name;
  }

  Future<void> _openEditor({AdminUserDto? initial}) async {
    final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _UserEditorPage(
              initial: initial,
              roles: _roles,
            ),
          ),
        ) ??
        false;
    if (ok) await _load();
  }

  Future<void> _delete(AdminUserDto u) async {
    final auth = ref.read(authNotifierProvider);
    final currentId = auth.user?.userId;
    if (currentId != null && currentId == u.userId) return;

    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete user'),
            content: Text('Delete "${u.username}"?'),
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
      await ref.read(usersRepositoryProvider).deleteUser(u.userId);
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
    final canCreate = perms.contains('CREATE_USERS');
    final canUpdate = perms.contains('UPDATE_USERS');
    final canDelete = perms.contains('DELETE_USERS');
    final auth = ref.watch(authNotifierProvider);
    final currentId = auth.user?.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
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
          : _users.isEmpty
              ? const Center(child: Text('No users'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _users[i];
                      final name = [
                        (u.firstName ?? '').trim(),
                        (u.lastName ?? '').trim(),
                      ].where((e) => e.isNotEmpty).join(' ');
                      final subtitle = [
                        u.email,
                        if (_roles.isNotEmpty) _roleName(u.roleId),
                        if (!u.isActive) 'Inactive',
                        if (u.isLocked) 'Locked',
                      ].join(' • ');

                      final editable = canUpdate;
                      final deletable = canDelete &&
                          (currentId == null || currentId != u.userId);

                      return Card(
                        elevation: 0,
                        child: ListTile(
                          leading: const Icon(Icons.person_rounded),
                          title: Text(name.isEmpty
                              ? u.username
                              : '$name (${u.username})'),
                          subtitle: Text(subtitle),
                          onTap:
                              editable ? () => _openEditor(initial: u) : null,
                          trailing: deletable
                              ? IconButton(
                                  tooltip: 'Delete',
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _delete(u),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _UserEditorPage extends ConsumerStatefulWidget {
  const _UserEditorPage({this.initial, required this.roles});

  final AdminUserDto? initial;
  final List<RoleDto> roles;

  @override
  ConsumerState<_UserEditorPage> createState() => _UserEditorPageState();
}

class _UserEditorPageState extends ConsumerState<_UserEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();

  int? _roleId;
  int? _locationId;
  bool _isActive = true;
  bool _isLocked = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    if (u != null) {
      _username.text = u.username;
      _email.text = u.email;
      _firstName.text = u.firstName ?? '';
      _lastName.text = u.lastName ?? '';
      _phone.text = u.phone ?? '';
      _roleId = u.roleId;
      _locationId = u.locationId;
      _isActive = u.isActive;
      _isLocked = u.isLocked;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final auth = ref.read(authNotifierProvider);
    final companyId = auth.company?.companyId;
    if (companyId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No company context')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(usersRepositoryProvider);
      final initial = widget.initial;
      if (initial == null) {
        await repo.createUser(
          companyId: companyId,
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          firstName:
              _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
          lastName:
              _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          roleId: _roleId,
          locationId: _locationId,
        );
      } else {
        await repo.updateUser(
          userId: initial.userId,
          firstName:
              _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
          lastName:
              _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          roleId: _roleId,
          locationId: _locationId,
          isActive: _isActive,
          isLocked: _isLocked,
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
    final canCreate = perms.contains('CREATE_USERS');
    final canUpdate = perms.contains('UPDATE_USERS');
    final allowSave = initial == null ? canCreate : canUpdate;

    final locations = ref.watch(locationNotifierProvider).locations;

    return Scaffold(
      appBar: AppBar(
        title: Text(initial == null ? 'Add user' : 'Edit user'),
        actions: [
          TextButton(
            onPressed: (!allowSave || _saving) ? null : _save,
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
                  controller: _username,
                  enabled: initial == null,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (v) {
                    if (initial != null) return null;
                    if (v == null || v.trim().length < 3) {
                      return 'Min 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  enabled: initial == null,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    if (initial != null) return null;
                    if (v == null || !v.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                if (initial == null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Role'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _roleId,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('No role')),
                        ...widget.roles.map(
                          (r) => DropdownMenuItem<int?>(
                            value: r.roleId,
                            child: Text(r.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _roleId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Location scope'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _locationId,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All locations')),
                        ...locations.map(
                          (l) => DropdownMenuItem<int?>(
                            value: l.locationId,
                            child: Text(l.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _locationId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: initial == null
                      ? null
                      : (v) => setState(() => _isActive = v),
                  title: const Text('Active'),
                ),
                SwitchListTile(
                  value: _isLocked,
                  onChanged: initial == null
                      ? null
                      : (v) => setState(() => _isLocked = v),
                  title: const Text('Locked'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
