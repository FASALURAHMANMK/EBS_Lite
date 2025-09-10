import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_controller.dart';
import '../../data/db.dart';
import '../../app_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeControllerProvider);
    final db = ref.watch(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Supabase ↔ Drift Sync Demo')),
      body: Column(
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton(
              onPressed: s.running ? null : () => ref.read(homeControllerProvider.notifier).startSync(),
              child: const Text('Start Sync'),
            ),
            ElevatedButton(
              onPressed: s.running ? () => ref.read(homeControllerProvider.notifier).stopSync() : null,
              child: const Text('Stop Sync'),
            ),
            ElevatedButton(
              onPressed: () => ref.read(homeControllerProvider.notifier).seedLocalData(),
              child: const Text('Seed Local'),
            ),
            ElevatedButton(
              onPressed: () => ref.read(homeControllerProvider.notifier).makeLocalChange(),
              child: const Text('Insert Local Product'),
            ),
          ]),
          const Divider(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<int>(
                    future: db.select(db.products).get().then((v) => v.length),
                    builder: (c, snap) => _StatCard(title: 'Products (local)', value: '${snap.data ?? 0}'),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<int>(
                    future: db.select(db.sales).get().then((v) => v.length),
                    builder: (c, snap) => _StatCard(title: 'Sales last 30d (local)', value: '${snap.data ?? 0}'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Text(s.log, style: const TextStyle(fontFamily: 'monospace')),
            ),
          )
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.displaySmall),
        ]),
      ),
    );
  }
}