import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import 'auth/magic_link_service.dart';
import '../core/api_client.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/widgets/error_alert.dart';
import '../core/utils/error_handler.dart';
import '../core/auth/token_storage.dart';
import '../core/auth/auth_state.dart';

final _magicLinkServiceProvider = Provider<MagicLinkService>((ref) {
  // ApiClient's base URL is embedded in Dio options
  final client = ApiClient.I;
  final baseUrl = client.dio.options.baseUrl;
  return MagicLinkService(client.dio, baseUrl: baseUrl);
});

class MagicLinkLoginPage extends ConsumerStatefulWidget {
  const MagicLinkLoginPage({super.key, this.redirectPath = '/app'});
  final String redirectPath;

  @override
  ConsumerState<MagicLinkLoginPage> createState() => _MagicLinkLoginPageState();
}

class _MagicLinkLoginPageState extends ConsumerState<MagicLinkLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;
  bool _verifying = false;

  // (Unused helper retained for potential future refactor.)

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final svc = ref.read(_magicLinkServiceProvider);
      final ok = await svc.requestMagicLink(_emailCtrl.text.trim());
      if (ok) {
        setState(() => _sent = true);
      } else {
        setState(() => _error = 'Unexpected response');
      }
    } catch (e) {
      setState(() => _error = ErrorHandler.parseError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Magic Link Sign In',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: !_sent
                ? Form(
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
                          onPressed: _sending ? null : _submit,
                          child: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send sign-in link'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Use password login instead'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/signup'),
                          child: const Text('Create account with password'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mark_email_read, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Check your email for a sign-in link.\n'
                        'The link expires soon and can only be used once.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Manual code entry form
                      TextField(
                        controller: _codeCtrl,
                        maxLength: 8,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter 8-digit code',
                        ),
                        onSubmitted: (code) async {
                          if (code.trim().length != 8 || _verifying) return;

                          setState(() {
                            _verifying = true;
                            _error = null;
                          });
                          try {
                            final svc = ref.read(_magicLinkServiceProvider);
                            final data = await svc.verifyMagicLink(code.trim());
                            final access = data['access'] as String?;
                            final refresh = data['refresh'] as String?;
                            if (access == null || refresh == null) {
                              throw Exception('Malformed response');
                            }
                            final storage = TokenStorage();
                            await storage.saveTokens(
                                access: access, refresh: refresh);
                            ApiClient.I.setAuthToken(access);
                            await ref
                                .read(authStateProvider.notifier)
                                .refresh();
                            if (mounted) context.go(widget.redirectPath);
                          } catch (e) {
                            setState(() => _error = ErrorHandler.parseError(e));
                          } finally {
                            if (mounted) setState(() => _verifying = false);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton(
                        onPressed: _verifying
                            ? null
                            : () async {
                                final code = _codeCtrl.text.trim();
                                if (code.length != 8) {
                                  setState(() => _error = 'Enter 8-digit code');
                                  return;
                                }
                                setState(() {
                                  _verifying = true;
                                  _error = null;
                                });
                                try {
                                  final svc =
                                      ref.read(_magicLinkServiceProvider);
                                  final data = await svc.verifyMagicLink(code);
                                  final access = data['access'] as String?;
                                  final refresh = data['refresh'] as String?;
                                  if (access == null || refresh == null)
                                    throw Exception('Malformed response');
                                  final storage = TokenStorage();
                                  await storage.saveTokens(
                                      access: access, refresh: refresh);
                                  ApiClient.I.setAuthToken(access);
                                  await ref
                                      .read(authStateProvider.notifier)
                                      .refresh();
                                  if (mounted) context.go(widget.redirectPath);
                                } catch (e) {
                                  setState(() =>
                                      _error = ErrorHandler.parseError(e));
                                } finally {
                                  if (mounted)
                                    setState(() => _verifying = false);
                                }
                              },
                        child: _verifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify code'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _sending ? null : _submit,
                        child: const Text('Resend'),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to password login'),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ErrorAlert(
                          _error!,
                          dismissible: true,
                          onDismiss: () => setState(() => _error = null),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
