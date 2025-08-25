import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme_notifier.dart';
import 'core/app_theme.dart';
import 'core/api_client.dart';
import 'features/auth/controllers/auth_notifier.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/data/models.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'features/dashboard/controllers/location_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient(prefs);
  final authRepo = AuthRepository(apiClient.dio, prefs);
  User? user;
  Company? company;
  var storedCompany = prefs.getString(AuthRepository.companyKey);
  if (storedCompany != null) {
    try {
      company =
          Company.fromJson(jsonDecode(storedCompany) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(AuthRepository.companyKey);
    }
  }
  final accessToken = prefs.getString(AuthRepository.accessTokenKey);
  final refreshToken = prefs.getString(AuthRepository.refreshTokenKey);
  final sessionId = prefs.getString(AuthRepository.sessionIdKey);
  if (accessToken != null && refreshToken != null && sessionId != null) {
    try {
      final res = await authRepo.me();
      user = res.user.toUser();
      company = res.company;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await prefs.remove(AuthRepository.accessTokenKey);
        await prefs.remove(AuthRepository.refreshTokenKey);
        await prefs.remove(AuthRepository.sessionIdKey);
      }
      // For other errors, keep tokens and any cached company info
    } catch (_) {
      // Parsing or other errors should not clear tokens
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(apiClient.dio),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
      final company = widget.initialCompany;
      if (company != null) {
        Future.microtask(() =>
            ref.read(locationNotifierProvider.notifier).load(company.companyId));
      }
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
