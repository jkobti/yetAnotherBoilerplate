from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class Organization(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        related_name="owned_organizations",
        on_delete=models.CASCADE,
    )
    members = models.ManyToManyField(
        settings.AUTH_USER_MODEL, through="Membership", related_name="organizations"
    )
    # True for auto-created personal workspaces (B2C mode); False for team orgs (B2B)
    is_personal = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:
        return self.name


class Membership(models.Model):
    ROLE_ADMIN = "admin"
    ROLE_MEMBER = "member"
    ROLE_BILLING = "billing"
    ROLE_CHOICES = [
        (ROLE_ADMIN, "Admin"),
        (ROLE_MEMBER, "Member"),
        (ROLE_BILLING, "Billing"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_MEMBER)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "organization")

    def __str__(self) -> str:
        return f"{self.user} @ {self.organization} ({self.role})"


class OrganizationInvite(models.Model):
    """Invitation for a user to join an organization with a specific role.

    Invitations are single-use tokens that grant a user access to an organization
    with a predetermined role (admin, member, billing). They can be sent via email
    and accepted via deep link or in-app acceptance.
    """

    STATUS_PENDING = "pending"
    STATUS_ACCEPTED = "accepted"
    STATUS_DECLINED = "declined"
    STATUS_EXPIRED = "expired"
    STATUS_REVOKED = "revoked"

    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_ACCEPTED, "Accepted"),
        (STATUS_DECLINED, "Declined"),
        (STATUS_EXPIRED, "Expired"),
        (STATUS_REVOKED, "Revoked"),
    ]

    ROLE_ADMIN = "admin"
    ROLE_MEMBER = "member"
    ROLE_BILLING = "billing"

    ROLE_CHOICES = [
        (ROLE_ADMIN, "Admin"),
        (ROLE_MEMBER, "Member"),
        (ROLE_BILLING, "Billing"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="invites",
    )
    invited_email = models.EmailField(db_index=True)
    invited_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name="sent_invites",
    )

    # The user who accepted the invite (null if not yet accepted)
    accepted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="received_invites",
    )

    # Role that will be assigned when invite is accepted
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_MEMBER)

    # Invitation status
    status = models.CharField(
        max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING
    )

    # Single-use token (hashed) for accepting via link
    token_hash = models.CharField(max_length=64, unique=True, db_index=True)

    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    accepted_at = models.DateTimeField(null=True, blank=True)
    declined_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("organization", "invited_email", "status")
        indexes = [
            models.Index(fields=["invited_email", "status"]),
            models.Index(fields=["organization", "status"]),
        ]
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"Invite {self.invited_email} → {self.organization} ({self.status})"
