import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/models.dart';
import '../../../core/api_client.dart';
import '../presentation/login_screen.dart';

class AuthState {
  final bool isLoading;
  final User? user;
  final Company? company;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.company,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    User? user,
    Company? company,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      company: company ?? this.company,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState());
  final AuthRepository _repository;

  Future<LoginResponse?> login(
      {String? username, String? email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repository.login(
          username: username, email: email, password: password);
      state = state.copyWith(
          isLoading: false, user: res.user, company: res.company);
      return res;
    } on AuthException catch (ex) {
      state = state.copyWith(isLoading: false, error: ex.message);
      return null;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Login failed. Please try again later.');
      return null;
    }
  }

  Future<RegisterResponse?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repository.register(
          username: username, email: email, password: password);
      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.forgotPassword(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.resetPassword(token: token, newPassword: newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<Company?> createCompany({required String name, String? email}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final company = await _repository.createCompany(name: name, email: email);
      state = state.copyWith(isLoading: false, company: company);
      return company;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void setAuth({required User user, Company? company}) {
    state = state.copyWith(user: user, company: company);
  }

  Future<void> logout(BuildContext context) async {
    await _repository.logout();
    state = const AuthState();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthRepository(dio, prefs);
});
