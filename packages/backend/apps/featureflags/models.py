from __future__ import annotations

import uuid

from django.db import models


class FeatureFlag(models.Model):
    """Simple global feature flag.

    For now flags are globally applied (no per-user targeting). A flag is considered
    active if ``enabled`` is True. Frontend clients fetch the list of enabled
    keys from ``/api/features/`` and gate UI accordingly.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    key = models.CharField(
        max_length=64,
        unique=True,
        help_text="Machine name used by clients (e.g. 'news_ticker').",
    )
    name = models.CharField(max_length=128, help_text="Human readable name.")
    description = models.TextField(blank=True)
    enabled = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("key",)

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.key} ({'on' if self.enabled else 'off'})"
