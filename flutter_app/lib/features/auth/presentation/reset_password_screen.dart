import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_notifier.dart';
import '../../../core/theme_notifier.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _tokenFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscure = true;
  bool _obscureConfirm = true;

  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = ref.listenManual(authNotifierProvider, (prev, next) {
      if (next.error != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(next.error!),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _tokenFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _authSub?.close();
    super.dispose();
  }

  String? _validateToken(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Reset token is required';
    if (value.length < 6) return 'Token seems too short';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '');
    if (value.isEmpty) return 'New password is required';
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').isEmpty) return 'Please confirm your new password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  int _passwordScore(String v) {
    var score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]]').hasMatch(v)) score++;
    return score;
  }

  Future<void> _submit() async {
    final state = ref.read(authNotifierProvider);
    if (state.isLoading) return;

    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    FocusScope.of(context).unfocus();

    final ok = await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(_tokenController.text.trim(), _passwordController.text);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Password has been reset'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final shortest = media.size.shortestSide;

    final maxWidth = shortest < 600 ? double.infinity : 520.0;
    final padH = shortest < 600 ? 16.0 : 24.0;
    final padV = shortest < 600 ? 16.0 : 24.0;

    final pwd = _passwordController.text;
    final score = _passwordScore(pwd);
    final strengthLabel = ['Too weak', 'Weak', 'Okay', 'Good', 'Strong'][score];
    final strengthColor = [
      theme.colorScheme.error,
      Colors.orange,
      theme.colorScheme.tertiary,
      theme.colorScheme.primary,
      theme.colorScheme.primary,
    ][score];

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reset Password'),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: () =>
                  ref.read(themeNotifierProvider.notifier).toggle(),
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  padH, padV, padH, media.viewPadding.bottom + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Create a new password',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paste the reset token from your email and choose a strong new password.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _tokenController,
                            focusNode: _tokenFocus,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Reset token',
                              hintText: 'e.g. 6–32 chars',
                              prefixIcon: const Icon(Icons.vpn_key_rounded),
                            ),
                            validator: _validateToken,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          StatefulBuilder(
                            builder: (context, setInner) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    textInputAction: TextInputAction.next,
                                    obscureText: _obscure,
                                    onChanged: (_) => setInner(() {}),
                                    decoration: InputDecoration(
                                      labelText: 'New password',
                                      prefixIcon:
                                          const Icon(Icons.lock_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setInner(
                                            () => _obscure = !_obscure),
                                        icon: Icon(_obscure
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded),
                                      ),
                                    ),
                                    validator: _validatePassword,
                                    onFieldSubmitted: (_) =>
                                        _confirmFocus.requestFocus(),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          child: LinearProgressIndicator(
                                            minHeight: 7,
                                            value:
                                                pwd.isEmpty ? 0 : (score / 4.0),
                                            color: strengthColor,
                                            backgroundColor: theme.colorScheme
                                                .surfaceContainerHighest
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        strengthLabel,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(color: strengthColor),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmController,
                            focusNode: _confirmFocus,
                            textInputAction: TextInputAction.done,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm new password',
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirm
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(_obscureConfirm
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded),
                              ),
                            ),
                            validator: _validateConfirm,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          if (state.error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color:
                                          theme.colorScheme.onErrorContainer),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.error!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: theme.colorScheme
                                                  .onErrorContainer),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: state.isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                textStyle: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: state.isLoading
                                    ? Row(
                                        key: const ValueKey('loading'),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator
                                                .adaptive(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      theme.colorScheme
                                                          .onPrimary),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text('Resetting…'),
                                        ],
                                      )
                                    : const Text(
                                        'Reset password',
                                        key: ValueKey('label'),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'After resetting, use your new password to sign in.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
