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
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/data/models.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'package:dio/dio.dart';
import 'features/dashboard/controllers/location_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient(prefs);
  const userKey = 'user';
  User? user;
  Company? company;
  var storedUser = prefs.getString(userKey);
  if (storedUser != null) {
    try {
      user = User.fromJson(jsonDecode(storedUser) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(userKey);
    }
  }
  var storedCompany = prefs.getString(AuthRepository.companyKey);
  if (storedCompany != null) {
    try {
      company =
          Company.fromJson(jsonDecode(storedCompany) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(AuthRepository.companyKey);
    }
  }
  final hasTokens =
      prefs.getString(AuthRepository.accessTokenKey) != null &&
          prefs.getString(AuthRepository.refreshTokenKey) != null &&
          prefs.getString(AuthRepository.sessionIdKey) != null;
  if (!hasTokens) {
    await prefs.remove(AuthRepository.accessTokenKey);
    await prefs.remove(AuthRepository.refreshTokenKey);
    await prefs.remove(AuthRepository.sessionIdKey);
  }
  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(apiClient.dio),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MyApp(
        initialUser: user,
        initialCompany: company,
        needsValidation: hasTokens,
      ),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp(
      {super.key, this.initialUser, this.initialCompany, this.needsValidation});
  final User? initialUser;
  final Company? initialCompany;
  final bool? needsValidation;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _validating = false;

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
    if (widget.needsValidation == true) {
      _validating = true;
      _validate();
    }
  }

  Future<void> _validate() async {
    const userKey = 'user';
    final authRepo = ref.read(authRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final res = await authRepo.me();
      final user = res.user.toUser();
      final company = res.company;
      await prefs.setString(
        userKey,
        jsonEncode({
          'user_id': user.userId,
          'username': user.username,
          'email': user.email,
        }),
      );
      ref
          .read(authNotifierProvider.notifier)
          .setAuth(user: user, company: company);
      if (company != null) {
        ref.read(locationNotifierProvider.notifier).load(company.companyId);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await prefs.remove(AuthRepository.accessTokenKey);
        await prefs.remove(AuthRepository.refreshTokenKey);
        await prefs.remove(AuthRepository.sessionIdKey);
        if (widget.initialUser == null) {
          await prefs.remove(userKey);
          ref.read(authNotifierProvider.notifier).state = const AuthState();
        }
      } else {
        debugPrint('authRepo.me error: $e');
      }
    } catch (e) {
      debugPrint('authRepo.me error: $e');
    } finally {
      if (mounted) {
        setState(() => _validating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final home = _validating
        ? const SplashScreen()
        : authState.user != null
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
