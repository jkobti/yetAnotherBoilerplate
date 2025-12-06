from __future__ import annotations

from django.db import transaction
from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.organizations.models import Membership, Organization


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

        return Response(
            {
                "message": "Switched to organization",
                "data": {
                    "id": str(org.id),
                    "name": org.name,
                    "is_personal": org.is_personal,
                },
            }
        )


class OrganizationMembersView(APIView):
    """List members of an organization (requires admin role)."""

    permission_classes = [IsAuthenticated]

    def get(self, request, org_id):
        org = get_object_or_404(Organization, id=org_id, members=request.user)

        # Check if user has admin role
        membership = Membership.objects.get(user=request.user, organization=org)
        if membership.role not in [Membership.ROLE_ADMIN, Membership.ROLE_BILLING]:
            return Response(
                {"error": "Admin access required"},
                status=status.HTTP_403_FORBIDDEN,
            )

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
