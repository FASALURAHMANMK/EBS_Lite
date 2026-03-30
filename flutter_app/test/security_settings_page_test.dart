import 'package:dio/dio.dart';
import 'package:ebs_lite/features/dashboard/data/settings_models.dart';
import 'package:ebs_lite/features/dashboard/data/settings_repository.dart';
import 'package:ebs_lite/features/dashboard/presentation/pages/security_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository() : super(Dio());

  @override
  Future<DeviceControlSettingsDto> getDeviceControlSettings() async {
    return DeviceControlSettingsDto(allowRemote: true);
  }

  @override
  Future<SessionLimitDto> getSessionLimit() async {
    return SessionLimitDto(maxSessions: 3);
  }

  @override
  Future<SecurityPolicyDto> getSecurityPolicy() async {
    return const SecurityPolicyDto(
      minPasswordLength: 12,
      requireUppercase: true,
      requireLowercase: true,
      requireNumber: true,
      requireSpecial: false,
      sessionIdleTimeoutMins: 240,
      elevatedAccessWindowMins: 7,
    );
  }
}

void main() {
  testWidgets('SecuritySettingsPage shows password and session policy fields',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider
              .overrideWithValue(_FakeSettingsRepository()),
        ],
        child: const MaterialApp(
          home: SecuritySettingsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Password policy'), findsOneWidget);
    expect(find.text('Minimum password length'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Elevated access window (minutes)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Session idle timeout (minutes)'), findsOneWidget);
    expect(find.text('Elevated access window (minutes)'), findsOneWidget);
    expect(find.text('Require uppercase letter'), findsOneWidget);
  });
}
