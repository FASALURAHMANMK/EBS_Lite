import 'package:ebs_lite/features/accounts/controllers/training_mode_notifier.dart';
import 'package:ebs_lite/shared/widgets/training_mode_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TrainingModeOverlay shows banner when enabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingModeEnabledProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              TrainingModeOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    expect(find.textContaining('TRAINING MODE'), findsOneWidget);
  });

  testWidgets('TrainingModeOverlay is hidden when disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingModeEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              TrainingModeOverlay(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    expect(find.textContaining('TRAINING MODE'), findsNothing);
  });
}
