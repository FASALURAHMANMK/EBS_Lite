import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

import 'core/theme_notifier.dart';
import 'core/app_theme.dart';
import 'core/api_client.dart';

import 'features/auth/controllers/auth_notifier.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/data/models.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/controllers/location_notifier.dart';

/// Keys used across the app
const String _userKey = 'user';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final apiClient = ApiClient(prefs);

  // 1) Determine if we *really* have a session
  final hasTokens = prefs.getString(AuthRepository.accessTokenKey) != null &&
      prefs.getString(AuthRepository.refreshTokenKey) != null &&
      prefs.getString(AuthRepository.sessionIdKey) != null;

  // 2) If tokens are incomplete, hard-reset all auth-related persisted data
  if (!hasTokens) {
    await _purgeAllAuthPrefs(prefs);
  }

  // NOTE: Do NOT trust persisted user/company here anymore.
  // We will only set them after validating tokens via /me.

  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(apiClient.dio),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(needsValidation: true),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, this.needsValidation = true});
  final bool? needsValidation;

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    // On every cold start, we re-validate if tokens exist.
    // If tokens don't exist, _validate() will early-out and show Login.
    _validating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validate();
    });
  }

  Future<void> _validate() async {
    final authRepo = ref.read(authRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);

    final hasTokens = prefs.getString(AuthRepository.accessTokenKey) != null &&
        prefs.getString(AuthRepository.refreshTokenKey) != null &&
        prefs.getString(AuthRepository.sessionIdKey) != null;

    if (!hasTokens) {
      // Ensure clean state when there are no tokens.
      await _purgeAllAuthPrefs(prefs);
      ref.read(authNotifierProvider.notifier).state = const AuthState();
      if (mounted) setState(() => _validating = false);
      return;
    }

    try {
      // Authoritative server validation
      final res = await authRepo.me();
      final user = res.user.toUser();
      final company = res.company;

      // Persist *fresh* minimal user payload only after validation succeeds
      await prefs.setString(
        _userKey,
        jsonEncode({
          'user_id': user.userId,
          'username': user.username,
          'email': user.email,
        }),
      );

      // Update app state
      ref.read(authNotifierProvider.notifier).setAuth(
            user: user,
            company: company,
          );

      if (company != null) {
        await ref
            .read(locationNotifierProvider.notifier)
            .load(company.companyId);
      }
    } on DioException catch (e) {
      // Any 401 => session is invalid. Purge everything and show Login.
      if (e.response?.statusCode == 401) {
        await _purgeAllAuthPrefs(prefs);
        ref.read(authNotifierProvider.notifier).state = const AuthState();
      } else {
        // Non-auth errors shouldn't keep a stale session around.
        // Be safe: treat as logged out if we cannot confirm.
        debugPrint('authRepo.me error: $e');
        await _purgeAllAuthPrefs(prefs);
        ref.read(authNotifierProvider.notifier).state = const AuthState();
      }
    } catch (e) {
      // Any unexpected error -> safe fallback: logged out
      debugPrint('authRepo.me error: $e');
      await _purgeAllAuthPrefs(prefs);
      ref.read(authNotifierProvider.notifier).state = const AuthState();
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    final home = _validating
        ? const SplashScreen()
        : (authState.user != null
            ? const DashboardScreen()
            : const LoginScreen());

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

Future<void> _purgeAllAuthPrefs(SharedPreferences prefs) async {
  await prefs.remove(AuthRepository.accessTokenKey);
  await prefs.remove(AuthRepository.refreshTokenKey);
  await prefs.remove(AuthRepository.sessionIdKey);
  await prefs.remove(_userKey);
  await prefs.remove(AuthRepository.companyKey);
}
