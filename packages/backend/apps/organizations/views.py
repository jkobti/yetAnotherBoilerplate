from __future__ import annotations

import hashlib
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.notifications.models import Notification
from apps.organizations.invite_serializers import (
    InviteSerializer,
    MembershipRoleUpdateSerializer,
)
from apps.organizations.models import Membership, Organization, OrganizationInvite


class OrganizationSerializer(serializers.Serializer):
    """Serializer for Organization data."""

    id = serializers.UUIDField(read_only=True)
    name = serializers.CharField(max_length=255)
    is_personal = serializers.BooleanField(read_only=True)
    owner_id = serializers.UUIDField(read_only=True)
    created_at = serializers.DateTimeField(read_only=True)


class OrganizationListView(APIView):
    """List all organizations the current user is a member of."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        orgs = request.user.organizations.all().order_by("-membership__created_at")
        data = []
        for org in orgs:
            membership = Membership.objects.get(user=request.user, organization=org)
            data.append(
                {
                    "id": str(org.id),
                    "name": org.name,
                    "is_personal": org.is_personal,
                    "owner_id": str(org.owner_id),
                    "role": membership.role,
                    "is_current": org.id
                    == getattr(request.user.current_organization, "id", None),
                }
            )
        return Response({"data": data, "count": len(data)})


class OrganizationCreateView(APIView):
    """Create a new organization (B2B mode: explicit team creation)."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = OrganizationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        org = Organization.objects.create(
            name=serializer.validated_data["name"],
            owner=request.user,
            is_personal=False,  # Explicit creation = team org
        )
        Membership.objects.create(
            user=request.user,
            organization=org,
            role=Membership.ROLE_ADMIN,
        )

        # If user has no current org, set this one
        if request.user.current_organization is None:
            request.user.current_organization = org
            request.user.save(update_fields=["current_organization"])

        return Response(
            {
                "data": {
                    "id": str(org.id),
                    "name": org.name,
                    "is_personal": org.is_personal,
                    "owner_id": str(org.owner_id),
                }
            },
            status=status.HTTP_201_CREATED,
        )


class OrganizationDetailView(APIView):
    """Get details of a specific organization."""

    permission_classes = [IsAuthenticated]

    def get(self, request, org_id):
        # Ensure user is a member
        org = get_object_or_404(Organization, id=org_id, members=request.user)
        membership = Membership.objects.get(user=request.user, organization=org)

        return Response(
            {
                "data": {
                    "id": str(org.id),
                    "name": org.name,
                    "is_personal": org.is_personal,
                    "owner_id": str(org.owner_id),
                    "role": membership.role,
                    "is_current": org.id
                    == getattr(request.user.current_organization, "id", None),
                    "created_at": org.created_at.isoformat(),
                }
            }
        )


class OrganizationSwitchView(APIView):
    """Switch the user's current organization."""

    permission_classes = [IsAuthenticated]

    def post(self, request, org_id):
        # Verify user is a member of the target organization
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        request.user.current_organization = org
        request.user.save(update_fields=["current_organization"])

        # Get the user's role in this organization
        membership = Membership.objects.get(user=request.user, organization=org)

        return Response(
            {
                "message": "Switched to organization",
                "data": {
                    "id": str(org.id),
                    "name": org.name,
                    "is_personal": org.is_personal,
                    "role": membership.role,
                },
            }
        )


class OrganizationMembersView(APIView):
    """List members of an organization (requires membership)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        members = []
        for m in Membership.objects.filter(organization=org).select_related("user"):
            members.append(
                {
                    "id": str(m.id),
                    "user_id": str(m.user.id),
                    "email": m.user.email,
                    "first_name": m.user.first_name,
                    "last_name": m.user.last_name,
                    "role": m.role,
                    "joined_at": m.created_at.isoformat(),
                }
            )

        return Response({"data": members, "count": len(members)})


class OrganizationInviteListView(APIView):
    """List pending invites for an organization (admin only)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Check admin role
        membership = Membership.objects.get(user=request.user, organization=org)
        if membership.role not in [Membership.ROLE_ADMIN, Membership.ROLE_BILLING]:
            return Response(
                {"error": "Admin access required"},
                status=status.HTTP_403_FORBIDDEN,
            )

        invites = OrganizationInvite.objects.filter(
            organization=org,
            status=OrganizationInvite.STATUS_PENDING,
        ).select_related("invited_by")

        serializer = InviteSerializer(invites, many=True)
        return Response({"data": serializer.data, "count": len(serializer.data)})


class MyPendingInvitesView(APIView):
    """List pending invites for the current user's email address."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        """Get all pending invites sent to the current user's email."""
        invites = OrganizationInvite.objects.filter(
            invited_email__iexact=request.user.email,
            status=OrganizationInvite.STATUS_PENDING,
        ).select_related("organization", "invited_by")

        data = []
        for invite in invites:
            data.append(
                {
                    "id": str(invite.id),
                    "organization_id": str(invite.organization.id),
                    "organization_name": invite.organization.name,
                    "role": invite.role,
                    "invited_by_email": invite.invited_by.email
                    if invite.invited_by
                    else None,
                    "token_hash": invite.token_hash,
                    "created_at": invite.created_at.isoformat(),
                    "expires_at": invite.expires_at.isoformat(),
                }
            )

        return Response({"data": data, "count": len(data)})


class OrganizationInviteCreateView(APIView):
    """Send an invitation to join an organization (admin only, B2B only)."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # B2B only + admin check
        if org.is_personal:
            return Response(
                {"error": "Invites not available for personal workspaces"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        membership = Membership.objects.get(user=request.user, organization=org)
        if membership.role != Membership.ROLE_ADMIN:
            return Response(
                {"error": "Only admins can invite users"},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = InviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        invited_email = serializer.validated_data["invited_email"].lower()
        role = serializer.validated_data.get("role", OrganizationInvite.ROLE_MEMBER)

        # Check if user is already a member
        User = get_user_model()
        try:
            existing_user = User.objects.get(email__iexact=invited_email)
            if Membership.objects.filter(user=existing_user, organization=org).exists():
                return Response(
                    {"error": "User is already a member of this organization"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
        except User.DoesNotExist:
            pass

        # Generate token for accept link
        raw_token = f"{org.id}:{invited_email}:{timezone.now().timestamp()}"
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

        # Revoke any existing pending invites to same email
        OrganizationInvite.objects.filter(
            organization=org,
            invited_email__iexact=invited_email,
            status=OrganizationInvite.STATUS_PENDING,
        ).update(status=OrganizationInvite.STATUS_REVOKED)

        # Create new invite
        invite = OrganizationInvite.objects.create(
            organization=org,
            invited_email=invited_email,
            invited_by=request.user,
            role=role,
            token_hash=token_hash,
            expires_at=timezone.now() + timedelta(days=7),
        )

        # Send email - try async Celery task first, fall back to sync
        from apps.organizations.tasks import send_org_invite_email

        try:
            send_org_invite_email.delay(str(invite.id))
        except Exception:
            # Celery/Redis not available, send synchronously
            send_org_invite_email(str(invite.id))

        # Create notification for inviter
        Notification.objects.create(
            recipient=request.user,
            type="invite_sent",
            message=f"Invitation sent to {invited_email}",
            target_url=f"/organizations/{org.id}/members",
        )

        serializer = InviteSerializer(invite)
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class OrganizationInviteAcceptView(APIView):
    """Accept an organization invite by token."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, org_id, token):
        org = get_object_or_404(Organization, id=org_id)

        # Token comes from URL path parameter
        token_hash = token.strip() if token else ""

        # Also allow token_hash in body for backwards compatibility
        if not token_hash:
            token_hash = request.data.get("token_hash", "").strip()

        if not token_hash:
            return Response(
                {"error": "token_hash is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        invite = get_object_or_404(
            OrganizationInvite,
            organization=org,
            token_hash=token_hash,
            status=OrganizationInvite.STATUS_PENDING,
        )

        # Check expiration
        if timezone.now() > invite.expires_at:
            invite.status = OrganizationInvite.STATUS_EXPIRED
            invite.save(update_fields=["status"])
            return Response(
                {"error": "Invite has expired"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Accept invite: create/update membership
        membership, created = Membership.objects.get_or_create(
            user=request.user,
            organization=org,
            defaults={"role": invite.role},
        )

        if not created:
            # User already a member, just update role
            membership.role = invite.role
            membership.save(update_fields=["role"])

        # Mark invite as accepted
        invite.status = OrganizationInvite.STATUS_ACCEPTED
        invite.accepted_by = request.user
        invite.accepted_at = timezone.now()
        invite.save(update_fields=["status", "accepted_by", "accepted_at"])

        # Create in-app notification for inviter
        if invite.invited_by:
            Notification.objects.create(
                recipient=invite.invited_by,
                type="invite_accepted",
                message=f"{request.user.email} accepted your invite to {org.name}",
                target_url=f"/organizations/{org.id}/members",
            )

        return Response(
            {
                "message": "Invite accepted",
                "data": {
                    "organization_id": str(org.id),
                    "organization_name": org.name,
                    "role": membership.role,
                },
            }
        )


class MembershipRoleUpdateView(APIView):
    """Update a member's role (admin only)."""

    permission_classes = [IsAuthenticated]

    def patch(self, request, org_id, membership_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Check admin role
        requester_membership = Membership.objects.get(
            user=request.user, organization=org
        )
        if requester_membership.role != Membership.ROLE_ADMIN:
            return Response(
                {"error": "Only admins can update roles"},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Get target membership
        target_membership = get_object_or_404(
            Membership,
            id=membership_id,
            organization=org,
        )

        serializer = MembershipRoleUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_role = serializer.validated_data["role"]
        old_role = target_membership.role

        target_membership.role = new_role
        target_membership.save(update_fields=["role"])

        # Notify the member
        Notification.objects.create(
            recipient=target_membership.user,
            type="role_updated",
            message=f"Your role in {org.name} was changed from {old_role} to {new_role}",
            target_url=f"/organizations/{org.id}",
        )

        return Response(
            {
                "message": "Role updated",
                "data": {
                    "id": str(target_membership.id),
                    "email": target_membership.user.email,
                    "role": target_membership.role,
                },
            }
        )

    def delete(self, request, org_id, membership_id):
        """Remove a member from an organization (admin only)."""
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Check admin role
        requester_membership = Membership.objects.get(
            user=request.user, organization=org
        )
        if requester_membership.role != Membership.ROLE_ADMIN:
            return Response(
                {"error": "Only admins can remove members"},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Get target membership
        target_membership = get_object_or_404(
            Membership,
            id=membership_id,
            organization=org,
        )

        # Prevent removing org owner
        if target_membership.user == org.owner:
            return Response(
                {"error": "Cannot remove the organization owner"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Prevent self-removal
        if target_membership.user == request.user:
            return Response(
                {"error": "Cannot remove yourself. Use leave organization instead."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        removed_user = target_membership.user
        removed_email = removed_user.email

        # Delete membership
        target_membership.delete()

        # Clear current org if it was this one
        if removed_user.current_organization == org:
            # Find another org or set to None
            other_membership = Membership.objects.filter(user=removed_user).first()
            removed_user.current_organization = (
                other_membership.organization if other_membership else None
            )
            removed_user.save(update_fields=["current_organization"])

        # Notify the removed user
        Notification.objects.create(
            recipient=removed_user,
            type="removed_from_org",
            message=f"You were removed from {org.name}",
            target_url="/organizations",
        )

        return Response(
            {
                "message": "Member removed",
                "data": {
                    "email": removed_email,
                },
            }
        )


class OrganizationLeaveView(APIView):
    """Allow a user to leave an organization (cannot be performed by owner)."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Get user's membership
        membership = get_object_or_404(
            Membership,
            user=request.user,
            organization=org,
        )

        # Prevent owner from leaving
        if request.user == org.owner:
            return Response(
                {
                    "error": "Organization owner cannot leave. Transfer ownership or delete the organization instead."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Delete membership
        membership.delete()

        # Clear current org if it was this one
        if request.user.current_organization == org:
            # Find another org or set to None
            other_membership = Membership.objects.filter(user=request.user).first()
            request.user.current_organization = (
                other_membership.organization if other_membership else None
            )
            request.user.save(update_fields=["current_organization"])

        return Response(
            {
                "message": f"Successfully left {org.name}",
                "data": {
                    "organization_name": org.name,
                },
            }
        )


class OrganizationCloseView(APIView):
    """Close (delete) an organization. Only the owner can perform this action."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def delete(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Only the owner can close the organization
        if request.user != org.owner:
            return Response(
                {"error": "Only the organization owner can close the organization."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cannot delete personal organizations
        if org.is_personal:
            return Response(
                {"error": "Personal workspaces cannot be closed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify organization name for safety
        provided_name = request.data.get("name")
        if provided_name != org.name:
            return Response(
                {
                    "error": "Organization name does not match. Please enter the exact name to confirm."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        org_name = org.name

        # Clear current org for all members
        User = get_user_model()
        users_to_update = User.objects.filter(current_organization=org)
        for user in users_to_update:
            # Find another org for each user or set to None
            other_membership = (
                Membership.objects.filter(user=user).exclude(organization=org).first()
            )
            user.current_organization = (
                other_membership.organization if other_membership else None
            )
            user.save(update_fields=["current_organization"])

        # Delete the organization (cascade will delete memberships, invites, etc.)
        org.delete()

        return Response(
            {
                "message": f"Organization '{org_name}' has been closed",
                "data": {
                    "organization_name": org_name,
                },
            }
        )


class OrganizationTransferOwnershipView(APIView):
    """Transfer organization ownership to another member (owner only, irreversible)."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Only the owner can transfer ownership
        if request.user != org.owner:
            return Response(
                {"error": "Only the organization owner can transfer ownership."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cannot transfer personal workspaces (B2C mode)
        if org.is_personal:
            return Response(
                {"error": "Cannot transfer ownership of personal workspaces"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate request data
        new_owner_id = request.data.get("new_owner_id")
        confirm_organization_name = request.data.get("confirm_organization_name")

        if not new_owner_id:
            return Response(
                {"error": "new_owner_id is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not confirm_organization_name:
            return Response(
                {"error": "confirm_organization_name is required"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verify organization name matches
        if confirm_organization_name != org.name:
            return Response(
                {
                    "error": "Organization name does not match. Please enter the exact name to confirm."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Get the new owner user
        User = get_user_model()
        try:
            new_owner = User.objects.get(id=new_owner_id)
        except User.DoesNotExist:
            return Response(
                {"error": "User not found"},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Verify new owner is a member of the organization
        try:
            new_owner_membership = Membership.objects.get(
                user=new_owner, organization=org
            )
        except Membership.DoesNotExist:
            return Response(
                {"error": "User must be a member of the organization"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Cannot transfer to yourself
        if new_owner == request.user:
            return Response(
                {"error": "Cannot transfer ownership to yourself"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_owner = org.owner
        old_owner_name = (
            f"{old_owner.first_name} {old_owner.last_name}".strip() or old_owner.email
        )
        new_owner_name = (
            f"{new_owner.first_name} {new_owner.last_name}".strip() or new_owner.email
        )

        # Update organization owner
        org.owner = new_owner
        org.save(update_fields=["owner"])

        # Ensure new owner has admin role
        if new_owner_membership.role != Membership.ROLE_ADMIN:
            new_owner_membership.role = Membership.ROLE_ADMIN
            new_owner_membership.save(update_fields=["role"])

        # Create notifications for both parties
        Notification.objects.create(
            recipient=old_owner,
            type="ownership_transferred_from",
            message=f"You transferred ownership of {org.name} to {new_owner_name}",
            target_url=f"/organizations/{org.id}",
        )

        Notification.objects.create(
            recipient=new_owner,
            type="ownership_transferred_to",
            message=f"You are now the owner of {org.name} (transferred from {old_owner_name})",
            target_url=f"/organizations/{org.id}",
        )

        return Response(
            {
                "message": "Ownership transferred successfully",
                "data": {
                    "organization_id": str(org.id),
                    "organization_name": org.name,
                    "old_owner_id": str(old_owner.id),
                    "new_owner_id": str(new_owner.id),
                },
            }
        )


class OrganizationInviteRevokeView(APIView):
    """Revoke/cancel a pending organization invite (admin only)."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def delete(self, request, org_id, invite_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Check admin role
        membership = Membership.objects.get(user=request.user, organization=org)
        if membership.role != Membership.ROLE_ADMIN:
            return Response(
                {"error": "Only admins can revoke invites"},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Get pending invite
        invite = get_object_or_404(
            OrganizationInvite,
            id=invite_id,
            organization=org,
            status=OrganizationInvite.STATUS_PENDING,
        )

        invite.status = OrganizationInvite.STATUS_REVOKED
        invite.save(update_fields=["status"])

        return Response(
            {
                "message": "Invite revoked",
                "data": {
                    "id": str(invite.id),
                    "invited_email": invite.invited_email,
                },
            }
        )
