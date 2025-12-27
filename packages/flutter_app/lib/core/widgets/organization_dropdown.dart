import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../organizations/organization.dart';
import '../organizations/organization_provider.dart';

/// Dropdown widget showing the current organization and allowing switching.
/// Only visible in B2B mode for logged-in users.
class OrganizationDropdown extends ConsumerStatefulWidget {
  const OrganizationDropdown({super.key});

  @override
  ConsumerState<OrganizationDropdown> createState() =>
      _OrganizationDropdownState();
}

class _OrganizationDropdownState extends ConsumerState<OrganizationDropdown> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch organizations on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(organizationsProvider.notifier).fetch();
    });
  }

  Future<void> _switchOrganization(Organization org) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(currentOrganizationProvider.notifier).switchTo(org.id);
      // Refresh organizations to update isCurrent flag
      await ref.read(organizationsProvider.notifier).fetch();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to ${org.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error switching organization: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showCreateOrgDialog() {
    final nameController = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Organization'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Organization name',
              hintText: 'My Team',
              border: OutlineInputBorder(),
            ),
            enabled: !isCreating,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (value) async {
              if (value.trim().isEmpty || isCreating) return;

              setDialogState(() => isCreating = true);
              try {
                final org = await ref
                    .read(organizationsProvider.notifier)
                    .create(value.trim());

                // Switch to the new organization
                if (context.mounted) {
                  await ref
                      .read(currentOrganizationProvider.notifier)
                      .switchTo(org.id);
                  await ref.read(organizationsProvider.notifier).fetch();
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                  setDialogState(() => isCreating = false);
                }
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please enter an organization name')),
                        );
                        return;
                      }

                      setDialogState(() => isCreating = true);
                      try {
                        final org = await ref
                            .read(organizationsProvider.notifier)
                            .create(nameController.text.trim());

                        // Switch to the new organization
                        await ref
                            .read(currentOrganizationProvider.notifier)
                            .switchTo(org.id);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Created "${org.name}"')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                          setDialogState(() => isCreating = false);
                        }
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show in B2B mode
    if (!AppConfig.isB2B) {
      return const SizedBox.shrink();
    }

    final orgsState = ref.watch(organizationsProvider);
    final currentOrgState = ref.watch(currentOrganizationProvider);

    return orgsState.when(
      loading: () => const SizedBox(
        width: 120,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (organizations) {
        if (organizations.isEmpty) {
          return TextButton.icon(
            onPressed: _showCreateOrgDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Org'),
          );
        }

        // Find current organization
        final currentOrg = currentOrgState.valueOrNull ??
            organizations.firstWhere(
              (org) => org.isCurrent,
              orElse: () => organizations.first,
            );

        return PopupMenuButton<String>(
          tooltip: 'Switch organization',
          offset: const Offset(0, 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    currentOrg.name.isNotEmpty
                        ? currentOrg.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    currentOrg.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 4),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
          onSelected: (value) {
            if (value == '#create') {
              _showCreateOrgDialog();
            } else if (value == '#manage') {
              context.go('/organizations/${currentOrg.id}/team-management');
            } else {
              // Switch to organization by ID
              final org = organizations.firstWhere((o) => o.id == value);
              _switchOrganization(org);
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[];

            // Organization list
            for (final org in organizations) {
              items.add(
                PopupMenuItem(
                  value: org.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: org.isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                        child: Text(
                          org.name.isNotEmpty ? org.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color:
                                org.isCurrent ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              org.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: org.isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (org.role != null)
                              Text(
                                org.role!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (org.isCurrent)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              );
            }

            // Divider and actions
            items.add(const PopupMenuDivider());

            // Team management (only if current org is not personal)
            if (!currentOrg.isPersonal) {
              items.add(
                const PopupMenuItem(
                  value: '#manage',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Team Management'),
                    ],
                  ),
                ),
              );
            }

            items.add(
              const PopupMenuItem(
                value: '#create',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 12),
                    Text('Create Organization'),
                  ],
                ),
              ),
            );

            return items;
          },
        );
      },
    );
  }
}
