from __future__ import annotations

import uuid

from django.contrib.auth import get_user_model
from django.db import models


class AdminAudit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(get_user_model(), null=True, on_delete=models.SET_NULL)
    path = models.CharField(max_length=512)
    method = models.CharField(max_length=10)
    action = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)
