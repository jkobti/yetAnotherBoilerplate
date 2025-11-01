from __future__ import annotations

import hashlib
import secrets
import uuid
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

from apps.organizations.models import Organization


class APIKey(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key_prefix = models.CharField(max_length=16, db_index=True)
    hashed_key = models.CharField(max_length=128, unique=True)
    organization = models.ForeignKey(Organization, on_delete=models.CASCADE)
    last_used = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["key_prefix"])]

    @staticmethod
    def _hash(raw_key: str) -> str:
        return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()

    @classmethod
    def create_key(
        cls,
        organization: Organization,
        prefix: str | None = None,
        ttl_days: int | None = None,
    ) -> tuple[APIKey, str]:
        prefix = prefix or secrets.token_urlsafe(8)[:8]
        raw_key = f"sk_{prefix}_{secrets.token_urlsafe(24)}"
        hashed = cls._hash(raw_key)
        expires_at = timezone.now() + timedelta(days=ttl_days) if ttl_days else None
        obj = cls.objects.create(
            key_prefix=prefix,
            hashed_key=hashed,
            organization=organization,
            expires_at=expires_at,
        )
        return obj, raw_key


class IdempotencyKey(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL
    )
    method = models.CharField(max_length=10)
    path = models.CharField(max_length=512)
    key = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=["key", "path", "method"]),
        ]
        unique_together = ("key", "path", "method")
