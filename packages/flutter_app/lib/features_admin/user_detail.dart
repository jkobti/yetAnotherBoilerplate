import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/widgets/app_scaffold.dart';

class UserDetailPage extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailPage({super.key, required this.userId});

  @override
  ConsumerState<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends ConsumerState<UserDetailPage> {
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await ApiClient.I.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'User Details',
      isAdmin: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: _loadUser,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _user == null
                  ? const Center(child: Text('User not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _user!['email'] as String? ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (_user!['first_name'] != null ||
                                            _user!['last_name'] != null)
                                          Text(
                                            '${_user!['first_name'] ?? ''} ${_user!['last_name'] ?? ''}'.trim(),
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Status badges
                                  Wrap(
                                    spacing: 8,
                                    direction: Axis.vertical,
                                    children: [
                                      Chip(
                                        label: Text(
                                          (_user!['is_active'] as bool? ?? false)
                                              ? 'Active'
                                              : 'Inactive',
                                        ),
                                        backgroundColor: (_user!['is_active'] as bool? ?? false)
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                        labelStyle: TextStyle(
                                          color: (_user!['is_active'] as bool? ?? false)
                                              ? Colors.green.shade900
                                              : Colors.red.shade900,
                                        ),
                                      ),
                                      if (_user!['is_staff'] as bool? ?? false)
                                        Chip(
                                          label: const Text('Staff'),
                                          backgroundColor: Colors.blue.shade100,
                                          labelStyle: TextStyle(
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      if (_user!['is_superuser'] as bool? ?? false)
                                        Chip(
                                          label: const Text('Superuser'),
                                          backgroundColor: Colors.purple.shade100,
                                          labelStyle: TextStyle(
                                            color: Colors.purple.shade900,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              // Details
                              _buildDetailRow('User ID', _user!['id']?.toString() ?? 'N/A'),
                              _buildDetailRow(
                                'Email',
                                _user!['email']?.toString() ?? 'N/A',
                              ),
                              if (_user!['first_name'] != null)
                                _buildDetailRow(
                                  'First Name',
                                  _user!['first_name']?.toString() ?? 'N/A',
                                ),
                              if (_user!['last_name'] != null)
                                _buildDetailRow(
                                  'Last Name',
                                  _user!['last_name']?.toString() ?? 'N/A',
                                ),
                              _buildDetailRow(
                                'Active Status',
                                (_user!['is_active'] as bool? ?? false) ? 'Active' : 'Inactive',
                              ),
                              _buildDetailRow(
                                'Staff Status',
                                (_user!['is_staff'] as bool? ?? false) ? 'Staff' : 'Non-Staff',
                              ),
                              _buildDetailRow(
                                'Superuser Status',
                                (_user!['is_superuser'] as bool? ?? false)
                                    ? 'Superuser'
                                    : 'Regular User',
                              ),
                              _buildDetailRow(
                                'Device Tokens',
                                '${_user!['token_count'] ?? 0}',
                              ),
                              if (_user!['date_joined'] != null)
                                _buildDetailRow(
                                  'Date Joined',
                                  _formatDateTime(_user!['date_joined']),
                                ),
                              if (_user!['last_login'] != null)
                                _buildDetailRow(
                                  'Last Login',
                                  _formatDateTime(_user!['last_login']),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
