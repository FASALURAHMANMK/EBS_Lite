import 'package:ebs_lite/features/auth/controllers/auth_notifier.dart';
import 'package:ebs_lite/features/auth/data/auth_repository.dart';
import 'package:ebs_lite/features/auth/data/models.dart';
import 'package:ebs_lite/features/auth/presentation/login_screen.dart';
import 'package:ebs_lite/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// A minimal fake repository that satisfies the interface required by the
// authentication notifier. The methods are left unimplemented as they are not
// invoked by this smoke test.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<LoginResponse> login(
      {String? username, String? email, required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResponse> register(
      {required String username,
      required String email,
      required String password}) {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword(
      {required String token, required String newPassword}) async {}

  @override
  Future<Company> createCompany({required String name, String? email}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthMeResponse> me() {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
