from __future__ import annotations

from rest_framework import serializers

from .models import FeatureFlag


class FeatureFlagSerializer(serializers.ModelSerializer):
    def validate_key(self, value: str) -> str:
        v = value.strip()
        if not v:
            raise serializers.ValidationError("Key cannot be blank.")
        # Enforce simple charset (lowercase letters, digits, underscore, hyphen)
        import re

        if not re.fullmatch(r"[a-z0-9_\-]+", v):
            raise serializers.ValidationError(
                "Key must be lowercase alphanumeric plus '_' or '-'"
            )
        # Uniqueness (case-insensitive) check for friendlier error message
        from .models import FeatureFlag

        qs = FeatureFlag.objects.filter(key__iexact=v)
        if self.instance is None and qs.exists():
            raise serializers.ValidationError(
                "A feature flag with this key already exists."
            )
        if self.instance is not None and qs.exclude(id=self.instance.id).exists():
            raise serializers.ValidationError(
                "Another feature flag already uses this key."
            )
        return v

    class Meta:
        model = FeatureFlag
        fields = [
            "id",
            "key",
            "name",
            "description",
            "enabled",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
