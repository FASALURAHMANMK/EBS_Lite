import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ebs_lite/l10n/app_localizations.dart';

import 'core/theme_notifier.dart';
import 'core/app_theme.dart';
import 'core/api_client.dart';
import 'core/secure_storage.dart';
import 'core/auth_events.dart';
import 'core/locale_preferences.dart';

import 'features/auth/controllers/auth_notifier.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/models.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/auth/presentation/create_company_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/dashboard/controllers/location_notifier.dart';
import 'shared/widgets/training_mode_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final apiClient = ApiClient(prefs, secureStorage);

  // 1) Determine if we *really* have a session
  final hasTokens =
      (await secureStorage.read(key: AuthRepository.accessTokenKey)) != null &&
          (await secureStorage.read(key: AuthRepository.refreshTokenKey)) !=
              null &&
          (await secureStorage.read(key: AuthRepository.sessionIdKey)) != null;

  // 2) If tokens are incomplete, hard-reset all auth-related persisted data
  if (!hasTokens) {
    await _purgeAllAuthPrefs(prefs, secureStorage);
  }

  // NOTE: Do NOT trust persisted user/company here anymore.
  // We will only set them after validating tokens via /me.

  runApp(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(apiClient.dio),
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(secureStorage),
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
  StreamSubscription<void>? _logoutSub;

  @override
  void initState() {
    super.initState();
    // On every cold start, we re-validate if tokens exist.
    // If tokens don't exist, _validate() will early-out and show Login.
    _validating = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validate();
    });
    // Centralized logout on token refresh failure
    _logoutSub = AuthEvents.instance.onLogout.listen((_) async {
      final prefs = ref.read(sharedPreferencesProvider);
      final storage = ref.read(secureStorageProvider);
      await _purgeAllAuthPrefs(prefs, storage);
      if (mounted) {
        ref.read(authNotifierProvider.notifier).resetAuth();
      }
    });
  }

  Future<void> _validate() async {
    final authRepo = ref.read(authRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final secureStorage = ref.read(secureStorageProvider);

    final hasTokens = (await secureStorage.read(
                key: AuthRepository.accessTokenKey)) !=
            null &&
        (await secureStorage.read(key: AuthRepository.refreshTokenKey)) !=
            null &&
        (await secureStorage.read(key: AuthRepository.sessionIdKey)) != null;

    if (!hasTokens) {
      // Ensure clean state when there are no tokens.
      await _purgeAllAuthPrefs(prefs, secureStorage);
      ref.read(authNotifierProvider.notifier).resetAuth();
      if (mounted) setState(() => _validating = false);
      return;
    }

    try {
      // Authoritative server validation
      final res = await authRepo.me();
      final user = res.user.toUser();
      final company = res.company;

      // Update app state
      ref.read(authNotifierProvider.notifier).setAuth(
            user: user,
            company: company,
            permissions: res.user.permissions ?? const [],
          );

      if (company != null) {
        await ref
            .read(locationNotifierProvider.notifier)
            .load(company.companyId);
      }
    } on DioException catch (e) {
      // Any 401 => session is invalid. Purge everything and show Login.
      if (e.response?.statusCode == 401) {
        await _purgeAllAuthPrefs(prefs, secureStorage);
        ref.read(authNotifierProvider.notifier).resetAuth();
        return;
      }

      // If we can't validate now (offline/server unreachable), try to restore last known good session.
      final restored = await _restoreCachedSession(prefs);
      if (!restored) {
        debugPrint('authRepo.me error: $e');
        // Keep tokens but show login when we have no cached session snapshot.
        ref.read(authNotifierProvider.notifier).resetAuth();
      }
    } catch (e) {
      final restored = await _restoreCachedSession(prefs);
      if (!restored) {
        // Any unexpected error -> safe fallback: logged out UI (tokens remain).
        debugPrint('authRepo.me error: $e');
        ref.read(authNotifierProvider.notifier).resetAuth();
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<bool> _restoreCachedSession(SharedPreferences prefs) async {
    try {
      final userRaw = prefs.getString(AuthRepository.userKey);
      final companyRaw = prefs.getString(AuthRepository.companyKey);
      if (userRaw == null || userRaw.trim().isEmpty) return false;
      if (companyRaw == null || companyRaw.trim().isEmpty) return false;

      final userJson = jsonDecode(userRaw);
      final companyJson = jsonDecode(companyRaw);
      if (userJson is! Map || companyJson is! Map) return false;

      final u = Map<String, dynamic>.from(userJson);
      final c = Map<String, dynamic>.from(companyJson);

      final user = User(
        userId: (u['user_id'] as num?)?.toInt() ?? 0,
        username: (u['username'] ?? '').toString(),
        email: (u['email'] ?? '').toString(),
      );
      final company = Company(
        companyId: (c['company_id'] as num?)?.toInt() ?? 0,
        name: (c['name'] ?? '').toString(),
      );

      if (user.userId <= 0 || company.companyId <= 0) return false;

      final perms =
          (u['permissions'] as List?)?.map((x) => x.toString()).toList() ??
              const <String>[];

      ref.read(authNotifierProvider.notifier).setAuth(
            user: user,
            company: company,
            permissions: perms,
          );

      // Attempt to load locations; if offline, LocationNotifier falls back to cached values.
      await ref.read(locationNotifierProvider.notifier).load(company.companyId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _logoutSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final localePrefs = ref.watch(localePreferencesProvider);

    final home = _validating
        ? const SplashScreen()
        : (authState.user == null
            ? const LoginScreen()
            : (authState.company == null
                ? const CreateCompanyScreen()
                : const DashboardScreen()));

    return MaterialApp(
      key: ValueKey(
          'auth:${authState.user != null}:${authState.company != null}'),
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      builder: (context, child) =>
          TrainingModeOverlay(child: child ?? const SizedBox.shrink()),
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: mode,
      locale: localePrefs.uiLocale,
      supportedLocales: LocalePreferencesNotifier.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

Future<void> _purgeAllAuthPrefs(
    SharedPreferences prefs, FlutterSecureStorage secureStorage) async {
  await AuthRepository.purgeLocalSession(prefs, secureStorage);
}
