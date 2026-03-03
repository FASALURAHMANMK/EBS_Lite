import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications_repository.dart';

final notificationsUnreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.getUnreadCount();
});
