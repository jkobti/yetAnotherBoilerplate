import 'package:dio/dio.dart';
import 'auth/token_storage.dart';

class ApiClient {
  ApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            // Do NOT set Content-Type globally to avoid CORS preflight on GET.
            headers: {
              'Accept': 'application/json',
            },
          ),
        );

  static final ApiClient _instance = ApiClient._internal();
  final Dio _dio;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static ApiClient get I => _instance;

  Dio get dio => _dio;

  // Track current token value for potential future refresh workflows.
  String? get accessToken => _dio.options.headers['Authorization']
      ?.toString()
      .replaceFirst('Bearer ', '');

  Future<void> initFromStorage() async {
    final storage = TokenStorage();
    final token = await storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      setAuthToken(token);
    }
  }

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Map<String, dynamic>> health() async {
    final resp = await _dio.get('/health/');
    return resp.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) async {
    final resp = await _dio.post('/api/auth/jwt/token/', data: {
      'email': email,
      'password': password,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> refresh({required String refreshToken}) async {
    final resp = await _dio.post('/api/auth/jwt/refresh/', data: {
      'refresh': refreshToken,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> me() async {
    final resp = await _dio.get('/api/v1/me');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateProfile(
    String firstName,
    String lastName,
  ) async {
    final resp = await _dio.patch('/api/v1/me', data: {
      'first_name': firstName,
      'last_name': lastName,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> triggerTask() async {
    final resp = await _dio.post('/api/v1/trigger-task');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final resp = await _dio.post('/api/auth/register/', data: {
      'email': email,
      'password': password,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<void> registerPushToken({
    required String token,
    String platform = 'web',
    String? userAgent,
  }) async {
    await _dio.post('/api/push/register/', data: {
      'token': token,
      'platform': platform,
      if (userAgent != null) 'user_agent': userAgent,
    });
  }

  /// Get list of users with optional filters
  Future<List<Map<String, dynamic>>> getUsers({
    String? email,
    bool? isActive,
    bool? isStaff,
  }) async {
    final queryParams = <String, dynamic>{};
    if (email != null && email.isNotEmpty) {
      queryParams['email'] = email;
    }
    if (isActive != null) {
      queryParams['is_active'] = isActive;
    }
    if (isStaff != null) {
      queryParams['is_staff'] = isStaff;
    }

    final resp = await _dio.get(
      '/admin/api/users',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    return (resp.data['users'] as List).cast<Map<String, dynamic>>();
  }

  /// Get a single user by ID
  Future<Map<String, dynamic>> getUser(String userId) async {
    final resp = await _dio.get('/admin/api/users/$userId');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Delete a user by ID
  Future<void> deleteUser(String userId) async {
    await _dio.delete('/admin/api/users/$userId');
  }

  // ============================================================================
  // Organizations API
  // ============================================================================

  /// Get list of organizations the current user is a member of.
  Future<Map<String, dynamic>> getOrganizations() async {
    final resp = await _dio.get('/api/v1/organizations/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Create a new organization.
  Future<Map<String, dynamic>> createOrganization(String name) async {
    final resp = await _dio.post('/api/v1/organizations/create/', data: {
      'name': name,
    });
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Get details of a specific organization.
  Future<Map<String, dynamic>> getOrganization(String organizationId) async {
    final resp = await _dio.get('/api/v1/organizations/$organizationId/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Switch to a different organization.
  Future<Map<String, dynamic>> switchOrganization(String organizationId) async {
    final resp =
        await _dio.post('/api/v1/organizations/$organizationId/switch/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Get members of an organization (requires admin role).
  Future<Map<String, dynamic>> getOrganizationMembers(
      String organizationId) async {
    final resp =
        await _dio.get('/api/v1/organizations/$organizationId/members/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  // ============================================================================
  // Organization Invites API
  // ============================================================================

  /// Get pending invites for the current user (invites sent TO me).
  Future<Map<String, dynamic>> getMyPendingInvites() async {
    final resp = await _dio.get('/api/v1/organizations/my-invites/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Send an invitation to join an organization (admin only, B2B only).
  Future<Map<String, dynamic>> sendOrganizationInvite({
    required String organizationId,
    required String email,
    required String role,
  }) async {
    final resp = await _dio.post(
      '/api/v1/organizations/$organizationId/invites/send/',
      data: {
        'invited_email': email,
        'role': role,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Get list of pending invites for an organization (admin only).
  Future<Map<String, dynamic>> listOrganizationInvites(
      String organizationId) async {
    final resp =
        await _dio.get('/api/v1/organizations/$organizationId/invites/');
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Accept an organization invitation using token.
  Future<Map<String, dynamic>> acceptOrganizationInvite({
    required String organizationId,
    required String tokenHash,
  }) async {
    final resp = await _dio.post(
      '/api/v1/organizations/$organizationId/invites/$tokenHash/accept/',
      data: {
        'token_hash': tokenHash,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Update a member's role (admin only).
  Future<Map<String, dynamic>> updateMemberRole({
    required String organizationId,
    required String membershipId,
    required String role,
  }) async {
    final resp = await _dio.patch(
      '/api/v1/organizations/$organizationId/members/$membershipId/',
      data: {
        'role': role,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Remove a member from an organization (admin only).
  Future<Map<String, dynamic>> removeMember({
    required String organizationId,
    required String membershipId,
  }) async {
    final resp = await _dio.delete(
      '/api/v1/organizations/$organizationId/members/$membershipId/',
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Revoke/cancel a pending organization invite (admin only).
  Future<Map<String, dynamic>> revokeOrganizationInvite({
    required String organizationId,
    required String inviteId,
  }) async {
    final resp = await _dio.delete(
      '/api/v1/organizations/$organizationId/invites/$inviteId/revoke/',
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Leave an organization (cannot be performed by organization owner).
  Future<Map<String, dynamic>> leaveOrganization(String organizationId) async {
    final resp = await _dio.post(
      '/api/v1/organizations/$organizationId/leave/',
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Close (delete) an organization. Only the owner can perform this action.
  /// Requires the organization name to be provided for confirmation.
  Future<Map<String, dynamic>> closeOrganization({
    required String organizationId,
    required String organizationName,
  }) async {
    final resp = await _dio.delete(
      '/api/v1/organizations/$organizationId/close/',
      data: {
        'name': organizationName,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  /// Transfer organization ownership to another member. Only the owner can perform this action.
  /// This action is irreversible and requires the organization name to be provided for confirmation.
  /// The target user will be automatically promoted to admin if they aren't already.
  Future<Map<String, dynamic>> transferOrganizationOwnership({
    required String organizationId,
    required String newOwnerId,
    required String confirmOrganizationName,
  }) async {
    final resp = await _dio.post(
      '/api/v1/organizations/$organizationId/transfer-ownership/',
      data: {
        'new_owner_id': newOwnerId,
        'confirm_organization_name': confirmOrganizationName,
      },
    );
    return (resp.data as Map).cast<String, dynamic>();
  }
}
