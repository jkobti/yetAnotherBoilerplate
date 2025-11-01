from django.contrib import admin

from .models import APIKey, IdempotencyKey


@admin.register(APIKey)
class APIKeyAdmin(admin.ModelAdmin):
    list_display = ("id", "key_prefix", "organization", "expires_at", "last_used")
    search_fields = ("key_prefix", "organization__name")


@admin.register(IdempotencyKey)
class IdempotencyKeyAdmin(admin.ModelAdmin):
    list_display = ("id", "key", "method", "path", "user", "created_at")
    search_fields = ("key", "path", "user__email")
