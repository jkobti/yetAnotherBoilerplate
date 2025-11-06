import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../core/api_client.dart';
import '../core/widgets/app_scaffold.dart';

class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  String? _error;

  // Filter state
  final TextEditingController _emailController = TextEditingController();
  bool? _isActiveFilter;
  bool? _isStaffFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await ApiClient.I.getUsers(
        email: _emailController.text.isEmpty ? null : _emailController.text,
        isActive: _isActiveFilter,
        isStaff: _isStaffFilter,
      );
      if (mounted) {
        setState(() {
          _users = users;
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

  void _applyFilters() {
    _loadUsers();
  }

  void _clearFilters() {
    setState(() {
      _emailController.clear();
      _isActiveFilter = null;
      _isStaffFilter = null;
    });
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'User Management',
      isAdmin: true,
      body: Column(
        children: [
          // Filters section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Search by email',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<bool?>(
                        value: _isActiveFilter,
                        hint: const Text('Active Status'),
                        items: const [
                          DropdownMenuItem<bool?>(value: null, child: Text('All')),
                          DropdownMenuItem<bool?>(value: true, child: Text('Active')),
                          DropdownMenuItem<bool?>(value: false, child: Text('Inactive')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _isActiveFilter = value;
                          });
                          _applyFilters();
                        },
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<bool?>(
                        value: _isStaffFilter,
                        hint: const Text('Staff Status'),
                        items: const [
                          DropdownMenuItem<bool?>(value: null, child: Text('All')),
                          DropdownMenuItem<bool?>(value: true, child: Text('Staff')),
                          DropdownMenuItem<bool?>(value: false, child: Text('Non-Staff')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _isStaffFilter = value;
                          });
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PrimaryButton(
                        onPressed: _applyFilters,
                        child: const Text('Apply Filters'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear Filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Results section
          Expanded(
            child: _loading
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
                              onPressed: _loadUsers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(
                            child: Text('No users found'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final userId = user['id'].toString();
                              final email = user['email'] as String? ?? '';
                              final firstName = user['first_name'] as String? ?? '';
                              final lastName = user['last_name'] as String? ?? '';
                              final isActive = user['is_active'] as bool? ?? false;
                              final isStaff = user['is_staff'] as bool? ?? false;
                              final tokenCount = user['token_count'] as int? ?? 0;
                              final dateJoined = user['date_joined'] as String?;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(email),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (firstName.isNotEmpty || lastName.isNotEmpty)
                                        Text('$firstName $lastName'.trim()),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          Chip(
                                            label: Text(isActive ? 'Active' : 'Inactive'),
                                            backgroundColor: isActive
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                            labelStyle: TextStyle(
                                              color: isActive
                                                  ? Colors.green.shade900
                                                  : Colors.red.shade900,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (isStaff)
                                            Chip(
                                              label: const Text('Staff'),
                                              backgroundColor: Colors.blue.shade100,
                                              labelStyle: TextStyle(
                                                color: Colors.blue.shade900,
                                                fontSize: 12,
                                              ),
                                            ),
                                          Chip(
                                            label: Text('$tokenCount token(s)'),
                                            backgroundColor: Colors.grey.shade100,
                                            labelStyle: TextStyle(
                                              color: Colors.grey.shade900,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (dateJoined != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Joined: ${_formatDate(dateJoined)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    context.push('/users/$userId');
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
