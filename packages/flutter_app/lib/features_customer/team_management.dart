import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/config/app_config.dart';
import '../core/organizations/organization.dart';
import '../core/organizations/organization_provider.dart';
import '../core/widgets/app_scaffold.dart';

class TeamManagementPage extends ConsumerStatefulWidget {
  final String organizationId;

  const TeamManagementPage({
    required this.organizationId,
    super.key,
  });

  @override
  ConsumerState<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends ConsumerState<TeamManagementPage> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Fetch invites when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(organizationInvitesProvider.notifier)
          .fetch(widget.organizationId);
      _fetchMembers();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    try {
      await ApiClient.I.getOrganizationMembers(widget.organizationId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  void _showInviteDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'member';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Invite Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'member@example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'member',
                    child: Text('Member'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'billing',
                    child: Text('Billing'),
                  ),
                ],
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setDialogState(() => selectedRole = value);
                        }
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            PrimaryButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please enter an email address')),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await ref
                            .read(organizationInvitesProvider.notifier)
                            .send(
                              organizationId: widget.organizationId,
                              email: emailController.text.trim(),
                              role: selectedRole,
                            );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Invitation sent to ${emailController.text}',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invitesState = ref.watch(organizationInvitesProvider);

    if (!AppConfig.isB2B) {
      return const AppScaffold(
        title: 'Team Management',
        body: Center(
          child: Text('Team management is only available in B2B mode'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Management'),
      ),
      body: Column(
        children: [
          // Tab switcher
          Container(
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _currentPage == 0
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Members',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _currentPage == 1
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Pending Invites',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Page view
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                // Members tab
                _buildMembersTab(),
                // Pending Invites tab
                _buildPendingInvitesTab(invitesState),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInviteDialog(context),
        tooltip: 'Invite member',
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildMembersTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ApiClient.I.getOrganizationMembers(widget.organizationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Error loading members'),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: () {
                    (context as Element).markNeedsBuild();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = snapshot.data ?? {};
        final members = (data['data'] as List?) ?? [];

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No team members yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final member = members[index] as Map<String, dynamic>;
            return _buildMemberTile(member);
          },
        );
      },
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member) {
    final email = member['email'] as String? ?? 'Unknown';
    final role = member['role'] as String? ?? 'member';
    final firstName = member['first_name'] as String? ?? '';
    final lastName = member['last_name'] as String? ?? '';
    final membershipId = member['id'] as String? ?? '';

    final displayName = firstName.isNotEmpty || lastName.isNotEmpty
        ? '$firstName $lastName'.trim()
        : email;

    return ListTile(
      leading: CircleAvatar(
        child:
            Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
      ),
      title: Text(displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(email, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(role),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          if (role != 'admin')
            PopupMenuItem(
              child: const Text('Make Admin'),
              onTap: () => _updateMemberRole(
                membershipId,
                'admin',
              ),
            ),
          if (role != 'member')
            PopupMenuItem(
              child: const Text('Make Member'),
              onTap: () => _updateMemberRole(
                membershipId,
                'member',
              ),
            ),
          PopupMenuItem(
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmRemoveMember(membershipId, email),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveMember(String membershipId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $email from this organization?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeMember(membershipId);
    }
  }

  Future<void> _removeMember(String membershipId) async {
    try {
      await ApiClient.I.removeMember(
        organizationId: widget.organizationId,
        membershipId: membershipId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed')),
        );
        // Refresh members
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateMemberRole(String membershipId, String newRole) async {
    try {
      await ApiClient.I.updateMemberRole(
        organizationId: widget.organizationId,
        membershipId: membershipId,
        role: newRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Member role updated to $newRole')),
        );
        // Refresh members
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildPendingInvitesTab(AsyncValue<List<Map<String, dynamic>>> state) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error loading invites'),
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: () => ref
                  .read(organizationInvitesProvider.notifier)
                  .fetch(widget.organizationId),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (invites) {
        final pendingInvites =
            invites.where((i) => i['status'] == 'pending').toList();

        if (pendingInvites.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No pending invitations',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pendingInvites.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final invite = pendingInvites[index];
            return _buildInviteTile(invite);
          },
        );
      },
    );
  }

  Widget _buildInviteTile(Map<String, dynamic> invite) {
    final email = invite['invited_email'] as String? ?? 'Unknown';
    final role = invite['role'] as String? ?? 'member';
    final createdAt = invite['created_at'] as String? ?? '';
    final inviteId = invite['id'] as String? ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.amber[100],
        child: const Icon(Icons.mail_outline, color: Colors.amber),
      ),
      title: Text(email),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(role),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              role,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sent on ${_formatDate(createdAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
        tooltip: 'Cancel invitation',
        onPressed: () => _confirmRevokeInvite(inviteId, email),
      ),
    );
  }

  Future<void> _confirmRevokeInvite(String inviteId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: Text('Are you sure you want to cancel the invitation to $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _revokeInvite(inviteId);
    }
  }

  Future<void> _revokeInvite(String inviteId) async {
    try {
      await ApiClient.I.revokeOrganizationInvite(
        organizationId: widget.organizationId,
        inviteId: inviteId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
        // Refresh invites
        ref
            .read(organizationInvitesProvider.notifier)
            .fetch(widget.organizationId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Unknown date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red[400]!;
      case 'billing':
        return Colors.orange[400]!;
      case 'member':
      default:
        return Colors.blue[400]!;
    }
  }
}
