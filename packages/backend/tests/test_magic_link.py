from datetime import timedelta

import pytest
from django.urls import reverse  # type: ignore
from django.utils import timezone  # type: ignore
from rest_framework.test import APIClient  # type: ignore

from apps.users.models import MagicLink


@pytest.mark.django_db
def test_magic_link_request_and_verify(client: APIClient, settings):
    settings.DEBUG = True
    settings.MAGIC_LINK_DEBUG_ECHO_TOKEN = True
    settings.MAGIC_LINK_VERIFY_URL = (
        "https://example.com"  # required for send_magic_link
    )
    email = "newuser@example.com"
    url_request = reverse("public_api:magic-request")
    resp = client.post(url_request, {"email": email}, format="json")
    assert resp.status_code == 202
    raw_token = resp.data.get("debug_token")
    assert raw_token, "Debug token should be present in DEBUG mode"
    assert (
        len(raw_token) == 8 and raw_token.isdigit()
    ), "Token should be 8-digit numeric"

    url_verify = reverse("public_api:magic-verify")
    resp2 = client.post(url_verify, {"token": raw_token}, format="json")
    assert resp2.status_code == 200
    assert "access" in resp2.data and "refresh" in resp2.data
    assert resp2.data["user"]["email"] == email

    # Reuse attempt should fail (record deleted)
    resp3 = client.post(url_verify, {"token": raw_token}, format="json")
    assert resp3.status_code == 400
    assert resp3.data["error"] == "invalid_or_expired"


@pytest.mark.django_db
def test_magic_link_expiry(client: APIClient, settings):
    """Token should expire after configured minutes (simulate by manual expiry)."""
    settings.DEBUG = True
    settings.MAGIC_LINK_DEBUG_ECHO_TOKEN = True
    settings.MAGIC_LINK_VERIFY_URL = "https://example.com"
    settings.MAGIC_LINK_EXPIRY_MINUTES = 5
    email = "expiretest@example.com"
    url_request = reverse("public_api:magic-request")
    resp = client.post(url_request, {"email": email}, format="json")
    assert resp.status_code == 202
    raw_token = resp.data.get("debug_token")
    assert raw_token
    # Force expiry by setting expires_at in the past
    ml = MagicLink.objects.first()
    ml.expires_at = timezone.now() - timedelta(seconds=1)
    ml.save(update_fields=["expires_at"])
    url_verify = reverse("public_api:magic-verify")
    resp2 = client.post(url_verify, {"token": raw_token}, format="json")
    assert resp2.status_code == 400
    assert resp2.data["error"] == "invalid_or_expired"


@pytest.mark.django_db
def test_magic_link_just_before_expiry(client: APIClient, settings):
    """Verifies token still works moments before expiry boundary."""
    settings.DEBUG = True
    settings.MAGIC_LINK_DEBUG_ECHO_TOKEN = True
    settings.MAGIC_LINK_VERIFY_URL = "https://example.com"
    settings.MAGIC_LINK_EXPIRY_MINUTES = 5
    email = "boundary@example.com"
    url_request = reverse("public_api:magic-request")
    resp = client.post(url_request, {"email": email}, format="json")
    assert resp.status_code == 202
    raw_token = resp.data.get("debug_token")
    # Set expiry to 2 seconds from now, still valid
    ml = MagicLink.objects.first()
    ml.expires_at = timezone.now() + timedelta(seconds=2)
    ml.save(update_fields=["expires_at"])
    url_verify = reverse("public_api:magic-verify")
    resp2 = client.post(url_verify, {"token": raw_token}, format="json")
    assert resp2.status_code == 200
    assert "access" in resp2.data


@pytest.mark.django_db
def test_magic_link_invalid_token(client: APIClient):
    url_verify = reverse("public_api:magic-verify")
    resp = client.post(url_verify, {"token": "totallyinvalid"}, format="json")
    assert resp.status_code == 400
    assert resp.data["error"] == "invalid_or_expired"
