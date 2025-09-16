import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../controllers/auth_notifier.dart';
import '../../../core/theme_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _agree = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateUsername(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    final rx = RegExp(r'^[a-zA-Z0-9._-]+$');
    if (!rx.hasMatch(value)) {
      return 'Only letters, numbers, dot, underscore, hyphen';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final rx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!rx.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '');
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Use at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
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
    if (!_agree) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please agree to the terms to continue'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    FocusScope.of(context).unfocus();

    final res = await ref.read(authNotifierProvider.notifier).register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    if (res != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (prev, next) {
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
          title: const Text('Register',
              style: TextStyle(fontWeight: FontWeight.w700)),
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
            alignment: Alignment.center,
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
                            'Create your account',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Join your team and start collaborating.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Username',
                              prefixIcon:
                                  const Icon(Icons.alternate_email_rounded),
                            ),
                            validator: _validateUsername,
                            onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              prefixIcon: const Icon(Icons.email_rounded),
                            ),
                            validator: _validateEmail,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
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
                                      hintText: 'Password',
                                      prefixIcon:
                                          const Icon(Icons.lock_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: _obscure
                                            ? 'Show password'
                                            : 'Hide password',
                                        onPressed: () => setInner(
                                            () => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure
                                              ? PhosphorIconsBold.eye
                                              : PhosphorIconsBold.eyeSlash,
                                        ),
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
                              hintText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_reset_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscureConfirm
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                                icon: Icon(
                                  _obscureConfirm
                                      ? PhosphorIconsBold.eye
                                      : PhosphorIconsBold.eyeSlash,
                                ),
                              ),
                            ),
                            validator: _validateConfirm,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Checkbox.adaptive(
                                value: _agree,
                                onChanged: (v) =>
                                    setState(() => _agree = v ?? false),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'I agree to the Terms of Service and Privacy Policy.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                          const Text('Creating account…'),
                                        ],
                                      )
                                    : const Text(
                                        'Create account',
                                        key: ValueKey('label'),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              'By creating an account, you agree to our terms.',
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
