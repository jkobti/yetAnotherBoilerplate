import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/widgets/error_alert.dart';
import '../core/utils/error_handler.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill email from auth state
    final authState = ref.read(authStateProvider);
    final meData = authState.asData?.value;
    if (meData != null && _emailController.text.isEmpty) {
      _emailController.text = meData['email']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty) {
      setState(() => _error = 'First name is required');
      return;
    }
    if (lastName.isEmpty) {
      setState(() => _error = 'Last name is required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ApiClient.I.updateProfile(firstName, lastName);
      // Refresh auth state to get updated user data
      await ref.read(authStateProvider.notifier).refresh();
      if (mounted) {
        context.go('/app');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = ErrorHandler.parseError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final meData = authState.asData?.value;

    return AppScaffold(
      title: 'Complete Your Profile',
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : meData == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'You must be signed in to complete your profile'),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Go to Login'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Complete Your Profile',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please fill in your name to complete your account setup.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 32),
                            // Email field (disabled)
                            TextField(
                              controller: _emailController,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // First name field
                            TextField(
                              controller: _firstNameController,
                              enabled: !_loading,
                              decoration: InputDecoration(
                                labelText: 'First Name *',
                                hintText: 'Enter your first name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Last name field
                            TextField(
                              controller: _lastNameController,
                              enabled: !_loading,
                              decoration: InputDecoration(
                                labelText: 'Last Name *',
                                hintText: 'Enter your last name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onSubmitted: (_) => _submitProfile(),
                            ),
                            const SizedBox(height: 24),
                            if (_error != null) ...[
                              ErrorAlert(
                                _error!,
                                dismissible: true,
                                onDismiss: () => setState(() => _error = null),
                              ),
                              const SizedBox(height: 24),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: PrimaryButton(
                                onPressed: _loading ? null : _submitProfile,
                                child: _loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text('Continue'),
                              ),
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
