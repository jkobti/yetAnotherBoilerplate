import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_storage.dart';
import '../core/push/push_service.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/feature_flags/feature_flags_provider.dart';
import '../core/feature_flags/admin_feature_flags_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  String _status = 'unknown';
  bool _healthLoading = false;
  String? _healthError;
  Map<String, dynamic>? _me;
  bool _usersLoading = false;
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _checkHealth(),
      _loadAuthAndMe(),
      _loadUsers(),
    ]);
  }

  Future<void> _checkHealth() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
    });
    try {
      final data = await ApiClient.I.health();
      setState(() => _status = (data['status'] ?? 'unknown').toString());
    } catch (e) {
      setState(() => _healthError = e.toString());
    } finally {
      if (mounted) setState(() => _healthLoading = false);
    }
  }

  Future<void> _loadAuthAndMe() async {
    final repo = AuthRepository(ApiClient.I, TokenStorage());
    await repo.init();
    final me = await repo.me();
    if (mounted) setState(() => _me = me);
  }

  Future<void> _loadUsers() async {
    setState(() => _usersLoading = true);
    try {
      final resp = await ApiClient.I.dio.get('/admin/api/users');
      final list = (resp.data['users'] as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _users = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _usersLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
        featureFlagsProvider); // keep warm so downstream listeners get updates
    final adminFlagsAsync = ref.watch(adminFeatureFlagsProvider);
    return AppScaffold(
      title: 'Admin Portal',
      isAdmin: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHealthSection(),
                const SizedBox(height: 28),
                _buildAuthSection(adminFlagsAsync),
                const SizedBox(height: 24),
                if (PushService.isEnabled &&
                    _me != null &&
                    (_me!['is_staff'] == true))
                  _buildPushSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Service Health',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Backend: $_status'),
              if (_healthError != null) ...[
                const SizedBox(height: 6),
                Text(_healthError!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              PrimaryButton(
                onPressed: _healthLoading ? null : _checkHealth,
                child: _healthLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Refresh'),
              ),
            ],
          ),
        ),
      );

  Widget _buildAuthSection(
      AsyncValue<List<Map<String, dynamic>>> adminFlagsAsync) {
    if (_me == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Not signed in. Admin features require login.'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to Login'),
          ),
        ],
      );
    }
    if (!(_me!['is_staff'] == true)) {
      return const Text('You are signed in but not an admin.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome, ${_me!['email']} (admin)'),
        const SizedBox(height: 16),
        PrimaryButton(
          onPressed: () => context.go('/users'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 20),
              SizedBox(width: 8),
              Text('User Management'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildFlagsCard(adminFlagsAsync),
      ],
    );
  }

  Widget _buildFlagsCard(
          AsyncValue<List<Map<String, dynamic>>> adminFlagsAsync) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Feature Flags',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              adminFlagsAsync.when(
                loading: () => const SizedBox(
                    height: 32,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
                error: (err, _) => Text('Failed to load flags: $err',
                    style: const TextStyle(color: Colors.red)),
                data: (flags) {
                  if (flags.isEmpty) {
                    return const Text('No flags yet. Create one below.');
                  }
                  return Column(
                    children: [
                      for (final flag in flags)
                        _FlagTile(
                          flag: flag,
                          onToggle: () => _toggleFlag(flag),
                          onDelete: () => _deleteFlag(flag),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ref.read(featureFlagsProvider.notifier).refresh();
                      ref.read(adminFeatureFlagsProvider.notifier).refresh();
                    },
                    child: const Text('Refresh'),
                  ),
                  OutlinedButton(
                    onPressed: _showCreateFlagDialog,
                    child: const Text('Create Flag'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _toggleFlag(Map<String, dynamic> flag) async {
    try {
      await ref.read(adminFeatureFlagsProvider.notifier).toggleFlag(
          id: flag['id'] as String, enabled: flag['enabled'] == true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggled ${flag['key']}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Toggle failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteFlag(Map<String, dynamic> flag) async {
    final key = flag['key'] as String;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Flag'),
        content: Text('Delete "$key"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref
          .read(adminFeatureFlagsProvider.notifier)
          .deleteFlag(flag['id'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $key')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _showCreateFlagDialog() async {
    final controllerKey = TextEditingController(text: 'demo_feature');
    final controllerName = TextEditingController(text: 'Demo Feature');
    final controllerDesc = TextEditingController(
        text: 'Controls demo card on customer home page.');
    bool enabled = true;
    String? errorMessage;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Feature Flag'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controllerKey,
                  decoration: const InputDecoration(labelText: 'Key'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controllerName,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controllerDesc,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => enabled = v),
                  title: const Text('Enabled'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(adminFeatureFlagsProvider.notifier).createFlag(
                        key: controllerKey.text.trim(),
                        name: controllerName.text.trim(),
                        description: controllerDesc.text.trim(),
                        enabled: enabled,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Flag created')),
                    );
                  }
                  Navigator.pop(ctx);
                  ref.read(featureFlagsProvider.notifier).refresh();
                } catch (e) {
                  String friendly = 'Unable to create flag. Ensure the key is unique and try again.';
                  final raw = e.toString();
                  final lower = raw.toLowerCase();
                  if (lower.contains('already exists')) {
                    friendly = 'A flag with this key already exists.';
                  } else if (lower.contains('lowercase')) {
                    friendly =
                        'Key must be lowercase letters, digits, hyphen or underscore.';
                  } else if (lower.contains('cannot be blank')) {
                    friendly = 'Key cannot be blank.';
                  } else if (raw.length < 140) {
                    friendly = raw;
                  }
                  setDialogState(() => errorMessage = friendly);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPushSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Push Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Users with tokens (${_users.where((u) => (u['token_count'] ?? 0) > 0).length})'),
                  ),
                  if (_usersLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadUsers,
                      tooltip: 'Refresh users',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_users.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final userId = user['id'].toString();
                      final email = user['email'] as String;
                      final tokenCount = user['token_count'] as int? ?? 0;
                      final isActive = user['is_active'] as bool? ?? false;
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedUserIds.contains(userId),
                        onChanged: tokenCount > 0
                            ? (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedUserIds.add(userId);
                                  } else {
                                    _selectedUserIds.remove(userId);
                                  }
                                });
                              }
                            : null,
                        title: Text(
                          email,
                          style: TextStyle(
                            color: tokenCount == 0 ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          '$tokenCount token(s)${!isActive ? ' (inactive)' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedUserIds.isNotEmpty)
                    PrimaryButton(
                      onPressed: () async {
                        try {
                          await ApiClient.I.dio.post(
                            '/admin/api/push/send-test',
                            data: {
                              'user_ids': _selectedUserIds.toList(),
                              'title': 'Hello from Admin',
                              'body': 'This is a targeted test notification',
                            },
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Sent push to ${_selectedUserIds.length} user(s)'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to send push: $e')),
                            );
                          }
                        }
                      },
                      child: Text(
                          'Send to ${_selectedUserIds.length} selected user(s)'),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await ApiClient.I.dio.post('/admin/api/push/send-test');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Sent test push to recent tokens')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to send push: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Send to all recent'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Background notifications will appear as system notifications.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
}

class _FlagTile extends StatelessWidget {
  const _FlagTile(
      {required this.flag, required this.onToggle, required this.onDelete});

  final Map<String, dynamic> flag;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final key = flag['key'] as String? ?? 'unknown';
    final enabled = flag['enabled'] == true;
    final desc = (flag['description'] as String?)?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
        color: enabled
            ? Colors.green.withOpacity(0.06)
            : Colors.red.withOpacity(0.04),
      ),
      child: ListTile(
        dense: true,
        title: Text(key, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${enabled ? 'enabled' : 'disabled'}${desc.isNotEmpty ? ' • $desc' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: enabled ? 'Disable' : 'Enable',
              icon: Icon(enabled ? Icons.visibility_off : Icons.visibility,
                  size: 20),
              onPressed: onToggle,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_forever, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
