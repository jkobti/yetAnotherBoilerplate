# Generated manually for OrganizationInvite model

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import uuid


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("organizations", "0002_b2b_b2c_organization_fields"),
    ]

    operations = [
        migrations.CreateModel(
            name="OrganizationInvite",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "invited_email",
                    models.EmailField(
                        db_index=True,
                        max_length=254,
                    ),
                ),
                (
                    "role",
                    models.CharField(
                        choices=[
                            ("admin", "Admin"),
                            ("member", "Member"),
                            ("billing", "Billing"),
                        ],
                        default="member",
                        max_length=20,
                    ),
                ),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("pending", "Pending"),
                            ("accepted", "Accepted"),
                            ("declined", "Declined"),
                            ("expired", "Expired"),
                            ("revoked", "Revoked"),
                        ],
                        default="pending",
                        max_length=20,
                    ),
                ),
                (
                    "token_hash",
                    models.CharField(
                        db_index=True,
                        max_length=64,
                        unique=True,
                    ),
                ),
                (
                    "created_at",
                    models.DateTimeField(auto_now_add=True),
                ),
                (
                    "expires_at",
                    models.DateTimeField(),
                ),
                (
                    "accepted_at",
                    models.DateTimeField(blank=True, null=True),
                ),
                (
                    "declined_at",
                    models.DateTimeField(blank=True, null=True),
                ),
                (
                    "accepted_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="accepted_invites",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "invited_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="sent_invites",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                (
                    "organization",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="invites",
                        to="organizations.organization",
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(
                        fields=["invited_email", "status"],
                        name="organizatio_invited_idx",
                    ),
                    models.Index(
                        fields=["organization", "status"],
                        name="organizatio_org_sta_idx",
                    ),
                ],
            },
        ),
        migrations.AddConstraint(
            model_name="organizationinvite",
            constraint=models.UniqueConstraint(
                condition=models.Q(("status", "pending")),
                fields=("organization", "invited_email"),
                name="unique_pending_invite_per_org",
            ),
        ),
    ]
