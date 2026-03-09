import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSidebarNotifier extends StateNotifier<bool> {
  DesktopSidebarNotifier() : super(true);

  void toggle() => state = !state;

  void setExpanded(bool value) => state = value;
}

final desktopSidebarExpandedProvider =
    StateNotifierProvider<DesktopSidebarNotifier, bool>((ref) {
  return DesktopSidebarNotifier();
});
