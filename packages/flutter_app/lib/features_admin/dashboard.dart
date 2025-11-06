import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/token_storage.dart';
import '../core/push/push_service.dart';
import '../core/widgets/app_scaffold.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  String _status = 'unknown';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _users = [];
  Set<String> _selectedUserIds = {};
  bool _loadingUsers = false;

  Future<void> _checkHealth() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient.I.health();
      setState(() {
        _status = data['status']?.toString() ?? 'unknown';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAuthAndMe() async {
    final repo = AuthRepository(ApiClient.I, TokenStorage());
    await repo.init();
    final me = await repo.me();
    if (mounted) setState(() => _me = me);
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final response = await ApiClient.I.dio.get('/admin/api/users');
      final users = (response.data['users'] as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAuthAndMe();
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Admin Portal',
      isAdmin: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend health: $_status'),
                const SizedBox(height: 12),
                if (_error != null)
                  Text('Error: $_error',
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PrimaryButton(
                      onPressed: _loading ? null : _checkHealth,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_me == null) ...[
                  const Text('Not signed in. Admin features require login.'),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Go to Login'),
                  ),
                ] else if (!(_me!['is_staff'] == true)) ...[
                  const Text('You are signed in but not an admin.'),
                ] else ...[
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
                ],
                const SizedBox(height: 24),
                if (PushService.isEnabled && _me != null && (_me!['is_staff'] == true))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Push Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Users with tokens (${_users.where((u) => (u['token_count'] ?? 0) > 0).length})'),
                              ),
                              if (_loadingUsers)
                                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                              constraints: const BoxConstraints(maxHeight: 200),
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
                                    onChanged: tokenCount > 0 ? (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedUserIds.add(userId);
                                        } else {
                                          _selectedUserIds.remove(userId);
                                        }
                                      });
                                    } : null,
                                    title: Text(
                                      email,
                                      style: TextStyle(
                                        color: tokenCount == 0 ? Colors.grey : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${tokenCount} token(s)${!isActive ? ' (inactive)' : ''}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                                          SnackBar(content: Text('Sent push to ${_selectedUserIds.length} user(s)')),
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
                                  child: Text('Send to ${_selectedUserIds.length} selected user(s)'),
                                ),
                              OutlinedButton(
                                onPressed: () async {
                                  try {
                                    await ApiClient.I.dio.post('/admin/api/push/send-test');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Sent test push to recent tokens')),
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
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
