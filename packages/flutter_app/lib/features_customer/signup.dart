import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_repository.dart';
import '../core/api_client.dart';
import '../core/auth/token_storage.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

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
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
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
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Password (min 8 chars)'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Min 8 chars' : null,
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
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
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
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
