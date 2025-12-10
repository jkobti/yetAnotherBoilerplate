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

/// Provider for pending invites for the current organization.
final organizationInvitesProvider = StateNotifierProvider<
    OrganizationInvitesNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => OrganizationInvitesNotifier(),
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
  /// Does not set loading state to prevent UI flicker - updates directly on success.
  Future<void> switchTo(String organizationId) async {
    final previousValue = state.valueOrNull;
    try {
      final data = await ApiClient.I.switchOrganization(organizationId);
      final orgData = data['data'] as Map<String, dynamic>;
      state = AsyncValue.data(Organization.fromJson(orgData));
    } catch (e) {
      // On error, keep the previous value and rethrow
      state = AsyncValue.data(previousValue);
      rethrow;
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

/// Notifier for organization invites.
class OrganizationInvitesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  OrganizationInvitesNotifier() : super(const AsyncValue.data([]));

  /// Fetch pending invites for an organization (admin only).
  Future<void> fetch(String organizationId) async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiClient.I.listOrganizationInvites(organizationId);
      final invites = (data['data'] as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();
      state = AsyncValue.data(invites);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Send an invite and add to list.
  Future<Map<String, dynamic>> send({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    final data = await ApiClient.I.sendOrganizationInvite(
      organizationId: organizationId,
      email: email,
      role: role,
    );

    // Add to list
    state.whenData((invites) {
      state = AsyncValue.data([...invites, data]);
    });

    return data;
  }

  /// Clear invites (e.g., on logout or org switch).
  void clear() {
    state = const AsyncValue.data([]);
  }
}

/// Provider for pending invites sent TO the current user.
final myPendingInvitesProvider = StateNotifierProvider<MyPendingInvitesNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => MyPendingInvitesNotifier(),
);

/// Notifier for invites received by the current user.
class MyPendingInvitesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  MyPendingInvitesNotifier() : super(const AsyncValue.data([]));

  /// Fetch pending invites for the current user.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await ApiClient.I.getMyPendingInvites();
      final invites = (data['data'] as List)
          .map((json) => json as Map<String, dynamic>)
          .toList();
      state = AsyncValue.data(invites);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Remove an invite from the list (after accepting).
  void removeInvite(String inviteId) {
    state.whenData((invites) {
      state = AsyncValue.data(
        invites.where((i) => i['id'] != inviteId).toList(),
      );
    });
  }

  /// Clear invites (on logout).
  void clear() {
    state = const AsyncValue.data([]);
  }
}
