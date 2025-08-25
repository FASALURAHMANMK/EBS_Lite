import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme_notifier.dart';
import 'core/app_theme.dart';
import 'features/auth/controllers/auth_notifier.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/data/models.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.100.128:8080/api/v1'));
  final authRepo = AuthRepository(dio, prefs);
  User? user;
  Company? company;
  final accessToken = prefs.getString(AuthRepository.accessTokenKey);
  final refreshToken = prefs.getString(AuthRepository.refreshTokenKey);
  final sessionId = prefs.getString(AuthRepository.sessionIdKey);
  if (accessToken != null && refreshToken != null && sessionId != null) {
    try {
      final res = await authRepo.me();
      user = res.user;
      company = res.company;
    } catch (_) {
      await prefs.remove(AuthRepository.accessTokenKey);
      await prefs.remove(AuthRepository.refreshTokenKey);
      await prefs.remove(AuthRepository.sessionIdKey);
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
      child: MyApp(initialUser: user, initialCompany: company),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, this.initialUser, this.initialCompany});
  final User? initialUser;
  final Company? initialCompany;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialUser != null) {
      ref
          .read(authNotifierProvider.notifier)
          .setAuth(user: widget.initialUser!, company: widget.initialCompany);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeNotifierProvider);
    final home = widget.initialUser != null
        ? const DashboardScreen()
        : const LoginScreen();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EBS Lite',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      home: home,
    );
  }
}
