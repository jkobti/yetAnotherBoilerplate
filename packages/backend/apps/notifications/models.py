from __future__ import annotations

import uuid

from django.conf import settings
from django.db import models


class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    message = models.TextField()
    type = models.CharField(max_length=64)
    read_at = models.DateTimeField(null=True, blank=True)
    target_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self) -> str:
        return f"Notification<{self.type}> to {self.recipient}"


class DeviceToken(models.Model):
    """Stores push notification device tokens.

    For web, tokens are WebPush (FCM) tokens associated with a browser instance.
    A token may or may not be associated with an authenticated user at the time
    of registration. It can be linked later on subsequent registrations.
    """

    PLATFORM_WEB = "web"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True
    )
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=16, default=PLATFORM_WEB)
    user_agent = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["platform"]),
            models.Index(fields=["created_at"]),
        ]
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover - representation only
        owner = self.user.email if self.user else "anon"
        return f"DeviceToken<{self.platform}> {owner}"
