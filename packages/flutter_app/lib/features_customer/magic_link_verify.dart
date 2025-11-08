import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/magic_link_service.dart';
import '../core/api_client.dart';
import '../core/auth/token_storage.dart';
import '../core/auth/auth_state.dart';
import '../core/widgets/app_scaffold.dart';

final _magicLinkVerifyServiceProvider = Provider<MagicLinkService>((ref) {
  final client = ApiClient.I;
  final baseUrl = client.dio.options.baseUrl;
  return MagicLinkService(client.dio, baseUrl: baseUrl);
});

class MagicLinkVerifyPage extends ConsumerStatefulWidget {
  const MagicLinkVerifyPage(
      {super.key, this.redirectPath = '/app', this.token});
  final String redirectPath;
  final String? token; // If route pre-parsed token; else read from query

  @override
  ConsumerState<MagicLinkVerifyPage> createState() =>
      _MagicLinkVerifyPageState();
}

class _MagicLinkVerifyPageState extends ConsumerState<MagicLinkVerifyPage> {
  String? _error;
  bool _verifying = true;
  bool _done = false; // kept for potential future UI (analytics animation)
  String? _observedToken; // show for debug

  @override
  void initState() {
    super.initState();
    // Use post-frame to ensure router state fully initialized for query/path params.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startVerification());
  }

  Future<void> _startVerification() async {
    final svc = ref.read(_magicLinkVerifyServiceProvider);
    // Attempt multiple extraction strategies using current browser location.
    final current = Uri.base; // Browser location (web) or app deep link.
    String? token = widget.token;
    token ??= current.queryParameters['token'];
    if ((token == null || token.isEmpty) && current.pathSegments.isNotEmpty) {
      final segs = current.pathSegments;
      if (segs.length >= 2 && segs[segs.length - 2] == 'magic-verify') {
        token = segs.last;
      }
    }
    setState(() => _observedToken = token);
    // ignore: avoid_print
    print(
        '[MagicLinkVerifyPage] extracted token=$token from Uri.base=$current widget.token=${widget.token}');
    // ignore: avoid_print
    print(
        '[MagicLinkVerifyPage] extracted token=$token from route=${GoRouterState.of(context).uri}');
    if (token == null || token.isEmpty) {
      // No query param; allow manual entry instead of immediate error.
      setState(() {
        _verifying = false; // show form
      });
      return;
    }
    try {
      final data = await svc.verifyMagicLink(token);
      // ignore: avoid_print
      print('[MagicLinkVerifyPage] verification success data=$data');
      final access = data['access'] as String?;
      final refresh = data['refresh'] as String?;
      if (access == null || refresh == null) {
        setState(() {
          _error = 'Malformed response';
          _verifying = false;
        });
        return;
      }
      // Persist tokens
      final storage = TokenStorage();
      await storage.saveTokens(access: access, refresh: refresh);
      ApiClient.I.setAuthToken(access);
      // Refresh global auth state
      await ref.read(authStateProvider.notifier).refresh();
      setState(() {
        _done = true;
        _verifying = false;
      });

      // Check if user needs to complete their profile (first name and last name)
      final authState = ref.read(authStateProvider);
      final meData = authState.asData?.value;
      final needsProfileSetup = (meData?['first_name']?.isEmpty ?? true) ||
          (meData?['last_name']?.isEmpty ?? true);

      // ignore: avoid_print
      print('[MagicLinkVerifyPage] needsProfileSetup=$needsProfileSetup');
      if (mounted) {
        if (needsProfileSetup) {
          context.go('/profile-setup');
        } else {
          context.go(widget.redirectPath);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[MagicLinkVerifyPage] verification error=$e');
      setState(() {
        _error = e.toString();
        _verifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Verifying link',
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _verifying
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                          'Verifying your magic link...${_observedToken != null ? '' : ' (waiting for token)'}'),
                      const SizedBox(height: 8),
                      if (_observedToken != null)
                        Text('Token: $_observedToken',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  )
                : _error != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.go('/login-magic'),
                            child: const Text('Request new link'),
                          ),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Use password login'),
                          ),
                        ],
                      )
                    : (!_done && _error == null && !_verifying)
                        ? _ManualCodeEntry(onSubmit: (code) async {
                            setState(() {
                              _verifying = true;
                              _error = null;
                            });
                            try {
                              final svc =
                                  ref.read(_magicLinkVerifyServiceProvider);
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
                              setState(() {
                                _done = true;
                                _verifying = false;
                              });

                              // Check if user needs to complete their profile
                              final authState = ref.read(authStateProvider);
                              final meData = authState.asData?.value;
                              final needsProfileSetup =
                                  (meData?['first_name']?.isEmpty ?? true) ||
                                      (meData?['last_name']?.isEmpty ?? true);

                              if (mounted) {
                                if (needsProfileSetup) {
                                  context.go('/profile-setup');
                                } else {
                                  context.go(widget.redirectPath);
                                }
                              }
                            } catch (e) {
                              setState(() {
                                _error = e.toString();
                                _verifying = false;
                              });
                            }
                          })
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                  'Signed in successfully. Redirecting...'),
                              if (_observedToken != null) ...[
                                const SizedBox(height: 8),
                                Text('Token: $_observedToken',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ],
                            ],
                          ),
          ),
        ),
      ),
    );
  }
}

class _ManualCodeEntry extends StatefulWidget {
  const _ManualCodeEntry({required this.onSubmit});
  final Future<void> Function(String code) onSubmit;
  @override
  State<_ManualCodeEntry> createState() => _ManualCodeEntryState();
}

class _ManualCodeEntryState extends State<_ManualCodeEntry> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_codeCtrl.text.trim());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Enter your 8-digit code:'),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: TextFormField(
            controller: _codeCtrl,
            maxLength: 8,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Code'),
            validator: (v) {
              if (v == null || v.length != 8) return '8 digits required';
              if (!RegExp(r'^\d{8}$').hasMatch(v)) return 'Digits only';
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }
}
