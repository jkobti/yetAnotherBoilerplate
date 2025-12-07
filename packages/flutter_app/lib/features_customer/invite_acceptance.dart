import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
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
        await ref
            .read(organizationInvitesProvider.notifier)
            .fetch(widget.organizationId);
      }

      return result;
    } catch (e) {
      rethrow;
    }
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to accept invitation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: () => context.go('/app'),
                    child: const Text('Go to Home'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasData) {
            final data = snapshot.data ?? {};
            final orgName =
                data['data']?['organization_name'] as String? ?? 'organization';
            final role = data['data']?['role'] as String? ?? 'member';

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Invitation Accepted!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have been added to $orgName as a $role.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: () => context.go('/app'),
                    child: const Text('Go to App'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/profile'),
                    child: const Text('View Profile'),
                  ),
                ],
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
