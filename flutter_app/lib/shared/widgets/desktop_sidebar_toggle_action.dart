import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/core/layout/desktop_sidebar_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DesktopSidebarToggleAction extends ConsumerWidget {
  const DesktopSidebarToggleAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!AppBreakpoints.isTabletOrDesktop(context)) {
      return const SizedBox.shrink();
    }

    final expanded = ref.watch(desktopSidebarExpandedProvider);
    return IconButton(
      tooltip: expanded ? 'Hide sidebar' : 'Show sidebar',
      icon: Icon(expanded ? Icons.menu_open_rounded : Icons.menu_rounded),
      onPressed: () =>
          ref.read(desktopSidebarExpandedProvider.notifier).toggle(),
    );
  }
}

class DesktopSidebarToggleLeading extends ConsumerWidget {
  const DesktopSidebarToggleLeading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expanded = ref.watch(desktopSidebarExpandedProvider);
    final canPop = Navigator.of(context).canPop();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop) const BackButton(),
        IconButton(
          tooltip: expanded ? 'Hide sidebar' : 'Show sidebar',
          icon: Icon(expanded ? Icons.menu_open_rounded : Icons.menu_rounded),
          onPressed: () =>
              ref.read(desktopSidebarExpandedProvider.notifier).toggle(),
        ),
      ],
    );
  }
}
