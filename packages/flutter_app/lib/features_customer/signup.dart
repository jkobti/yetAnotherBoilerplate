import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_repository.dart';
import '../core/api_client.dart';
import '../core/auth/token_storage.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/widgets/error_alert.dart';
import '../core/utils/error_handler.dart';
import '../core/auth/auth_state.dart';

class SignupPage extends ConsumerStatefulWidget {
  final String redirectPath;
  final bool isAdmin;
  const SignupPage(
      {super.key, this.redirectPath = '/app', this.isAdmin = false});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passRepeatCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _passRepeatFocus = FocusNode();

  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _passKey = GlobalKey<FormFieldState<String>>();
  final _passRepeatKey = GlobalKey<FormFieldState<String>>();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _emailKey.currentState?.validate();
      }
    });
    _passFocus.addListener(() {
      if (!_passFocus.hasFocus) {
        _passKey.currentState?.validate();
      }
    });
    _passRepeatFocus.addListener(() {
      if (!_passRepeatFocus.hasFocus) {
        _passRepeatKey.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passRepeatCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _passRepeatFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = AuthRepository(ApiClient.I, TokenStorage());
    try {
      await repo.register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        firstName:
            _firstCtrl.text.trim().isEmpty ? null : _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim().isEmpty ? null : _lastCtrl.text.trim(),
      );
      // Refresh global auth state so navbar updates immediately
      await ref.read(authStateProvider.notifier).refresh();
      if (mounted) context.go(widget.redirectPath);
    } catch (e) {
      setState(() => _error = ErrorHandler.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Sign up',
      isAdmin: widget.isAdmin,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: _emailKey,
                    focusNode: _emailFocus,
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v)) {
                        return 'Invalid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: _passKey,
                    focusNode: _passFocus,
                    controller: _passCtrl,
                    decoration: const InputDecoration(
                        labelText:
                            'Password (min 8 chars, upper, lower, number)'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.length < 8) return 'Min 8 chars';
                      if (!v.contains(RegExp(r'[A-Z]'))) {
                        return 'Must contain uppercase';
                      }
                      if (!v.contains(RegExp(r'[a-z]'))) {
                        return 'Must contain lowercase';
                      }
                      if (!v.contains(RegExp(r'[0-9]'))) {
                        return 'Must contain number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: _passRepeatKey,
                    focusNode: _passRepeatFocus,
                    controller: _passRepeatCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Repeat Password'),
                    obscureText: true,
                    validator: (v) {
                      if (v != _passCtrl.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstCtrl,
                    decoration: const InputDecoration(
                        labelText: 'First name (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lastCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Last name (optional)'),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    ErrorAlert(
                      _error!,
                      dismissible: true,
                      onDismiss: () => setState(() => _error = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  PrimaryButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login-magic'),
                    child: const Text('Use magic link sign-in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
