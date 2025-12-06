import 'package:flutter/foundation.dart';

/// Organization model representing a workspace or team.
@immutable
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.isPersonal,
    required this.ownerId,
    this.role,
    this.isCurrent = false,
  });

  /// Create an Organization from JSON response.
  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String,
      name: json['name'] as String,
      isPersonal: json['is_personal'] as bool? ?? false,
      ownerId: json['owner_id'] as String,
      role: json['role'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final bool isPersonal;
  final String ownerId;

  /// User's role in this organization (admin, member, billing).
  final String? role;

  /// Whether this is the user's currently active organization.
  final bool isCurrent;

  /// Whether team features should be hidden for this organization.
  /// True for personal workspaces in B2C mode.
  bool get shouldHideTeamFeatures => isPersonal;

  /// Convert to JSON for API requests.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_personal': isPersonal,
        'owner_id': ownerId,
        if (role != null) 'role': role,
        'is_current': isCurrent,
      };

  Organization copyWith({
    String? id,
    String? name,
    bool? isPersonal,
    String? ownerId,
    String? role,
    bool? isCurrent,
  }) {
    return Organization(
      id: id ?? this.id,
      name: name ?? this.name,
      isPersonal: isPersonal ?? this.isPersonal,
      ownerId: ownerId ?? this.ownerId,
      role: role ?? this.role,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organization &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Organization(id: $id, name: $name, isPersonal: $isPersonal)';
}
