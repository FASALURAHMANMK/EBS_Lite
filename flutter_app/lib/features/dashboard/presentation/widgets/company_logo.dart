import 'package:ebs_lite/core/api_client.dart';
import 'package:ebs_lite/core/auth_image.dart';
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
    if (logo != null && logo.isNotEmpty) {
      final dio = ref.read(dioProvider);
      var base = dio.options.baseUrl;
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      if (base.endsWith('/api/v1')) {
        base = base.substring(0, base.length - '/api/v1'.length);
      }
      final url = logo.startsWith('http') ? logo : (base + logo);
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
        child: ClipOval(
          child: AuthImage(
            url: url,
            fit: BoxFit.cover,
            fallback: const Icon(Icons.business, color: Colors.white, size: 28),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
      child: const Icon(Icons.business, color: Colors.white, size: 28),
    );
  }
}
