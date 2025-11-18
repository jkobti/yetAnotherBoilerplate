import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/auth/auth_state.dart';
import '../core/widgets/app_scaffold.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
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

                              // Actions Section
                              _buildSectionHeader(context, 'Settings'),
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
}
