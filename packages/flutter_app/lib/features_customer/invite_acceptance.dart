import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/organizations/organization_provider.dart';

class InviteAcceptancePage extends ConsumerStatefulWidget {
  final String organizationId;
  final String tokenHash;

  const InviteAcceptancePage({
    required this.organizationId,
    required this.tokenHash,
    super.key,
  });

  @override
  ConsumerState<InviteAcceptancePage> createState() =>
      _InviteAcceptancePageState();
}

class _InviteAcceptancePageState extends ConsumerState<InviteAcceptancePage> {
  late Future<Map<String, dynamic>> _acceptanceFuture;
  bool _isAuthError = false;

  @override
  void initState() {
    super.initState();
    _acceptanceFuture = _acceptInvite();
  }

  Future<Map<String, dynamic>> _acceptInvite() async {
    try {
      final result = await ApiClient.I.acceptOrganizationInvite(
        organizationId: widget.organizationId,
        tokenHash: widget.tokenHash,
      );

      // Refresh organizations and invites
      if (mounted) {
        await ref.read(organizationsProvider.notifier).fetch();
        await ref.read(authStateProvider.notifier).refresh();
        await ref
            .read(organizationInvitesProvider.notifier)
            .fetch(widget.organizationId);
      }

      return result;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        _isAuthError = true;
      }
      rethrow;
    }
  }

  String _getErrorMessage(dynamic error) {
    String errorStr = '';

    if (error is DioException) {
      errorStr = (error.response?.data?.toString() ?? error.message ?? '')
          .toLowerCase();
    } else {
      errorStr = error.toString().toLowerCase();
    }

    if (errorStr.contains('revoked') || errorStr.contains('cancelled')) {
      return 'This invitation has been cancelled by the organization administrator.';
    } else if (errorStr.contains('expired')) {
      return 'This invitation has expired. Please request a new invitation.';
    } else if (errorStr.contains('not found') || errorStr.contains('invalid')) {
      return 'This invitation is not valid. It may have been cancelled or already used.';
    } else if (errorStr.contains('already') || errorStr.contains('member')) {
      return 'You are already a member of this organization.';
    }

    return 'Unable to accept invitation. Please contact the organization administrator.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accept Invitation'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _acceptanceFuture,
        builder: (context, snapshot) {
          print(
              '[InviteAcceptance] ConnectionState: ${snapshot.connectionState}');
          print('[InviteAcceptance] HasError: ${snapshot.hasError}');
          print('[InviteAcceptance] HasData: ${snapshot.hasData}');
          print('[InviteAcceptance] Error: ${snapshot.error}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Accepting invitation...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            // Check if this is an authentication error
            if (_isAuthError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.login,
                        size: 64,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Login Required',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please log in to accept this organization invitation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        onPressed: () {
                          final inviteUrl =
                              '/invites/${widget.organizationId}/${widget.tokenHash}/accept';
                          context.go('/login?redirect=$inviteUrl');
                        },
                        child: const Text('Log In'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          final inviteUrl =
                              '/invites/${widget.organizationId}/${widget.tokenHash}/accept';
                          context.go('/signup?redirect=$inviteUrl');
                        },
                        child: const Text('Create Account'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Other errors
            final errorMessage = _getErrorMessage(snapshot.error);

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cancel_outlined,
                      size: 64,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.red[400]
                          : Colors.red[300],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Invitation Not Valid',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[700]
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      onPressed: () => context.go('/app'),
                      child: const Text('Go to Home'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/profile'),
                      child: const Text('View Profile'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            final data = snapshot.data ?? {};
            final orgName =
                data['data']?['organization_name'] as String? ?? 'organization';
            final role = data['data']?['role'] as String? ?? 'member';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.green[600]
                          : Colors.green[400],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome Aboard!',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You have successfully joined $orgName as a $role.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey[700]
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      onPressed: () => context.go('/app'),
                      child: const Text('Go to App'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/profile'),
                      child: const Text('View Your Profile'),
                    ),
                  ],
                ),
              ),
            );
          }

          return const Center(
            child: Text('Unknown state'),
          );
        },
      ),
    );
  }
}
