import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../core/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/config/app_config.dart';
import '../core/organizations/organization.dart';
import '../core/organizations/organization_provider.dart';
import '../core/widgets/app_scaffold.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _hasFetchedInvites = false;

  @override
  void initState() {
    super.initState();
    // Fetch pending invites on first load (B2B only)
    if (AppConfig.isB2B) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasFetchedInvites) {
          _hasFetchedInvites = true;
          ref.read(myPendingInvitesProvider.notifier).fetch();
        }
      });
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      if (context.mounted) {
        await ref.read(authStateProvider.notifier).signOut();
        if (context.mounted) {
          context.go('/login');
        }
      }
    }
  }

  /// Determines if team features should be shown based on app mode and org type.
  bool _shouldShowTeamFeatures(Organization? currentOrg) {
    // B2B mode always shows team features
    if (AppConfig.isB2B) return true;

    // B2C mode: hide for personal workspaces
    if (currentOrg == null) return false;
    return !currentOrg.isPersonal;
  }

  /// Get section header title based on app mode.
  String _getSettingsHeader(Organization? currentOrg) {
    if (currentOrg == null) return 'Settings';

    if (currentOrg.isPersonal && AppConfig.isB2C) {
      return 'Workspace Settings';
    }
    return 'Organization Settings';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    // Watch currentOrganizationProvider for immediate UI updates when organization switches
    final currentOrgState = ref.watch(currentOrganizationProvider);
    final currentOrg = currentOrgState.valueOrNull;
    final meData = authState.asData?.value;

    return AppScaffold(
      title: 'Profile',
      body: authState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : authState.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Error loading profile'),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: () =>
                            ref.read(authStateProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : meData == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('You are not signed in'),
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
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            children: [
                              const SizedBox(height: 32),
                              // Avatar & Name
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  _getInitials(meData),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _getDisplayName(meData),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              if (_getDisplayName(meData) !=
                                  (meData['email']?.toString() ?? ''))
                                Text(
                                  meData['email']?.toString() ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              const SizedBox(height: 32),

                              // Info Section
                              _buildSectionHeader(context, 'Account Details'),
                              Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    _buildListTile(
                                      icon: Icons.badge_outlined,
                                      title: 'User ID',
                                      subtitle:
                                          meData['id']?.toString() ?? 'N/A',
                                    ),
                                    const Divider(height: 1, indent: 56),
                                    _buildListTile(
                                      icon: Icons.calendar_today_outlined,
                                      title: 'Joined',
                                      subtitle:
                                          _formatDate(meData['date_joined']),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Organization Section (conditional)
                              _buildOrganizationSection(
                                  context, ref, currentOrg, meData),

                              // Pending Invites Section (B2B only)
                              if (AppConfig.isB2B)
                                _buildPendingInvitesSection(context, ref),

                              // Actions Section
                              _buildSectionHeader(
                                  context, _getSettingsHeader(currentOrg)),
                              Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.logout,
                                          color: Colors.red),
                                      title: const Text(
                                        'Sign out',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      onTap: () => _logout(context, ref),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
        ),
      ),
    );
  }

  /// Build the organization section with conditional team features.
  Widget _buildOrganizationSection(
    BuildContext context,
    WidgetRef ref,
    Organization? currentOrg,
    Map<String, dynamic>? meData,
  ) {
    final showTeamFeatures = _shouldShowTeamFeatures(currentOrg);

    // In B2B mode, show org creation UI even if user has no org yet
    if (currentOrg == null && !AppConfig.isB2B) {
      return const SizedBox.shrink();
    }

    final orgName = currentOrg?.name ?? 'Workspace';
    final isPersonal = currentOrg?.isPersonal ?? false;

    // Header: "Workspace" for B2C personal, "Organization" for B2B
    final sectionTitle =
        isPersonal && AppConfig.isB2C ? 'Workspace' : 'Organization';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, sectionTitle),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              // Current workspace/org name (only if user has an org)
              if (currentOrg != null) ...[
                _buildListTile(
                  icon: isPersonal
                      ? Icons.person_outline
                      : Icons.business_outlined,
                  title: isPersonal ? 'Personal Workspace' : 'Team',
                  subtitle: orgName,
                ),
              ],

              // Team Members - only in B2B or non-personal orgs
              if (showTeamFeatures && currentOrg != null) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.people_outline, color: Colors.grey[600]),
                  title: const Text(
                    'Team Members',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    if (currentOrg.id.isNotEmpty) {
                      context.push(
                          '/organizations/${currentOrg.id}/team-management');
                    }
                  },
                ),
              ],

              // Organization Switcher - only in B2B mode with existing org
              if (AppConfig.isB2B && currentOrg != null) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.swap_horiz, color: Colors.grey[600]),
                  title: const Text(
                    'Switch Organization',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showOrganizationSwitcher(context, ref),
                ),
              ],

              // Create New Organization - always shown in B2B mode
              if (AppConfig.isB2B) ...[
                if (currentOrg != null) const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.add_business_outlined,
                      color: Colors.grey[600]),
                  title: const Text(
                    'Create New Organization',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCreateOrganizationDialog(context, ref),
                ),
              ],

              // Leave Organization - shown if user is not the owner
              if (AppConfig.isB2B && currentOrg != null) ...[
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.grey[600]),
                  title: Text(
                    'Leave Organization',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (meData?['id'] == currentOrg.ownerId)
                          ? Colors.grey[400]
                          : null,
                    ),
                  ),
                  enabled: meData?['id'] != currentOrg.ownerId,
                  onTap: (meData?['id'] != currentOrg.ownerId)
                      ? () =>
                          _showLeaveOrganizationDialog(context, ref, currentOrg)
                      : null,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Show organization switcher dialog (B2B mode).
  Future<void> _showOrganizationSwitcher(
      BuildContext context, WidgetRef ref) async {
    // Fetch organizations
    await ref.read(organizationsProvider.notifier).fetch();

    if (!context.mounted) return;

    final orgsState = ref.read(organizationsProvider);
    final orgs = orgsState.valueOrNull ?? [];

    if (orgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No organizations found')),
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Organization'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: orgs.length,
            itemBuilder: (context, index) {
              final org = orgs[index];
              return ListTile(
                leading: Icon(
                  org.isPersonal
                      ? Icons.person_outline
                      : Icons.business_outlined,
                ),
                title: Text(org.name),
                subtitle: org.isPersonal
                    ? const Text('Personal workspace')
                    : Text(org.role ?? 'Member'),
                trailing: org.isCurrent
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.of(context).pop(org.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && context.mounted) {
      try {
        // Switch to the new organization
        await ref.read(currentOrganizationProvider.notifier).switchTo(selected);

        // Refresh user data to sync authStateProvider
        await ref.read(authStateProvider.notifier).refresh();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Switched organization')),
          );

          // Reload the page on web to ensure all state is fresh
          if (kIsWeb) {
            html.window.location.reload();
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error switching organization: $e')),
          );
        }
      }
    }
  }

  /// Show create organization dialog (B2B mode).
  Future<void> _showCreateOrganizationDialog(
      BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Organization'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Organization Name',
            hintText: 'Enter team name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (name != null && name.isNotEmpty && context.mounted) {
      try {
        await ref.read(organizationsProvider.notifier).create(name);
        await ref.read(authStateProvider.notifier).refresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created organization: $name')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating organization: $e')),
          );
        }
      }
    }
  }

  Future<void> _showLeaveOrganizationDialog(
      BuildContext context, WidgetRef ref, Organization currentOrg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Organization?'),
        content: Text(
          'Are you sure you want to leave "${currentOrg.name}"? You will need to be invited again to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      if (context.mounted) {
        try {
          await ApiClient.I.leaveOrganization(currentOrg.id);

          // Refresh organizations and auth state
          await ref.read(organizationsProvider.notifier).fetch();
          await ref.read(authStateProvider.notifier).refresh();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Left organization: ${currentOrg.name}')),
            );

            // Reload page on web to ensure fresh state
            if (kIsWeb) {
              html.window.location.reload();
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error leaving organization: $e')),
            );
          }
        }
      }
    }
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? subtitleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: subtitleColor ?? Colors.grey[800],
        ),
      ),
    );
  }

  String _getInitials(Map<String, dynamic>? data) {
    if (data == null) return '?';
    final first = data['first_name']?.toString() ?? '';
    final last = data['last_name']?.toString() ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final email = data['email']?.toString() ?? '';
    if (email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  String _getDisplayName(Map<String, dynamic>? data) {
    if (data == null) return 'User';
    final first = data['first_name']?.toString() ?? '';
    final last = data['last_name']?.toString() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) {
      return '$first $last'.trim();
    }
    return data['email']?.toString() ?? 'User';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      // Format: "Jan 1, 2024"
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  /// Build pending invites section for B2B users.
  Widget _buildPendingInvitesSection(BuildContext context, WidgetRef ref) {
    final invitesState = ref.watch(myPendingInvitesProvider);

    return invitesState.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (invites) {
        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Pending Invitations'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.orange.shade200),
              ),
              color: Colors.orange.shade50,
              child: Column(
                children: invites.asMap().entries.map((entry) {
                  final index = entry.key;
                  final invite = entry.value;
                  final orgName = invite['organization_name'] ?? 'Unknown';
                  final role = invite['role'] ?? 'member';
                  final invitedBy = invite['invited_by_email'] ?? 'Unknown';

                  return Column(
                    children: [
                      if (index > 0) const Divider(height: 1, indent: 16),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.mail_outline,
                              color: Colors.orange),
                        ),
                        title: Text(
                          'Join $orgName',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text('As $role • from $invitedBy'),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptInvite(context, ref, invite),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _acceptInvite(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> invite,
  ) async {
    final orgId = invite['organization_id'] as String;
    final tokenHash = invite['token_hash'] as String;
    final inviteId = invite['id'] as String;

    try {
      await ApiClient.I.acceptOrganizationInvite(
        organizationId: orgId,
        tokenHash: tokenHash,
      );

      // Remove from pending invites
      ref.read(myPendingInvitesProvider.notifier).removeInvite(inviteId);

      // Refresh organizations
      await ref.read(organizationsProvider.notifier).fetch();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${invite['organization_name']}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
