from __future__ import annotations

from rest_framework import serializers

from apps.organizations.models import OrganizationInvite


class InviteSerializer(serializers.Serializer):
    """Serializer for creating/listing organization invites."""

    id = serializers.UUIDField(read_only=True)
    invited_email = serializers.EmailField()
    role = serializers.ChoiceField(
        choices=OrganizationInvite.ROLE_CHOICES,
        default=OrganizationInvite.ROLE_MEMBER,
    )
    status = serializers.CharField(read_only=True)
    invited_by_email = serializers.SerializerMethodField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)
    expires_at = serializers.DateTimeField(read_only=True)

    def get_invited_by_email(self, obj) -> str | None:
        return obj.invited_by.email if obj.invited_by else None


class MembershipRoleUpdateSerializer(serializers.Serializer):
    """Serializer for updating a member's role."""

    role = serializers.ChoiceField(
        choices=[
            ("admin", "Admin"),
            ("member", "Member"),
            ("billing", "Billing"),
        ]
    )
