import 'package:ebs_lite/core/api_client.dart';
import 'package:ebs_lite/features/auth/controllers/auth_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompanyLogo extends ConsumerWidget {
  const CompanyLogo({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final logo = authState.company?.logo;
    ImageProvider? provider;
    if (logo != null && logo.isNotEmpty) {
      final dio = ref.read(dioProvider);
      var base = dio.options.baseUrl;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/api/v1')) {
        base = base.substring(0, base.length - '/api/v1'.length);
      }
      final url = logo.startsWith('http') ? logo : (base + logo);
      provider = NetworkImage(url);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
      backgroundImage: provider,
      child: provider == null
          ? const Icon(Icons.business, color: Colors.white, size: 28)
          : null,
    );
  }
}
