import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import 'organization.dart';

/// Provider for the current organization.
final currentOrganizationProvider = StateNotifierProvider<
    CurrentOrganizationNotifier, AsyncValue<Organization?>>(
  (ref) => CurrentOrganizationNotifier(),
);

/// Provider for the list of all user's organizations.
final organizationsProvider = StateNotifierProvider<OrganizationsNotifier,
    AsyncValue<List<Organization>>>(
  (ref) => OrganizationsNotifier(),
);

/// Notifier for the current organization state.
class CurrentOrganizationNotifier
    extends StateNotifier<AsyncValue<Organization?>> {
  CurrentOrganizationNotifier() : super(const AsyncValue.data(null));

  /// Set the current organization from user data (called after login/refresh).
  void setFromUserData(Map<String, dynamic>? orgData) {
    if (orgData == null) {
      state = const AsyncValue.data(null);
    } else {
      state = AsyncValue.data(Organization.fromJson(orgData));
    }
  }

  /// Switch to a different organization.
  Future<void> switchTo(String organizationId) async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiClient.I.switchOrganization(organizationId);
      final orgData = data['data'] as Map<String, dynamic>;
      state = AsyncValue.data(Organization.fromJson(orgData));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear the current organization (on logout).
  void clear() {
    state = const AsyncValue.data(null);
  }
}

/// Notifier for the list of organizations.
class OrganizationsNotifier
    extends StateNotifier<AsyncValue<List<Organization>>> {
  OrganizationsNotifier() : super(const AsyncValue.data([]));

  /// Fetch all organizations the user is a member of.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiClient.I.getOrganizations();
      final orgs = (data['data'] as List)
          .map((json) => Organization.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(orgs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new organization.
  Future<Organization> create(String name) async {
    final data = await ApiClient.I.createOrganization(name);
    final org = Organization.fromJson(data['data'] as Map<String, dynamic>);

    // Add to list
    state.whenData((orgs) {
      state = AsyncValue.data([...orgs, org]);
    });

    return org;
  }

  /// Clear organizations (on logout).
  void clear() {
    state = const AsyncValue.data([]);
  }
}
