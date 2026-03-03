import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_notifier.dart';

final authPermissionsProvider = Provider<List<String>>((ref) {
  final auth = ref.watch(authNotifierProvider);
  return auth.permissions ?? const [];
});

final authHasPermissionProvider = Provider.family<bool, String>((ref, perm) {
  final perms = ref.watch(authPermissionsProvider);
  return perms.contains(perm);
});
