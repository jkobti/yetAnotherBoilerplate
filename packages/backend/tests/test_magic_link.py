import pytest
from django.urls import reverse
from rest_framework.test import APIClient


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

    # Reuse attempt should fail
    resp3 = client.post(url_verify, {"token": raw_token}, format="json")
    assert resp3.status_code == 400
    assert resp3.data["error"] == "invalid_or_expired"


@pytest.mark.django_db
def test_magic_link_invalid_token(client: APIClient):
    url_verify = reverse("public_api:magic-verify")
    resp = client.post(url_verify, {"token": "totallyinvalid"}, format="json")
    assert resp.status_code == 400
    assert resp.data["error"] == "invalid_or_expired"
