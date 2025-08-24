import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_notifier.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/quick_action_button.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DashboardHeader(
        onToggleTheme: () => ref.read(themeNotifierProvider.notifier).toggle(),
      ),
      drawer: const DashboardSidebar(),
      body: const DashboardContent(),
      floatingActionButton: const QuickActionButton(),
    );
  }
}
