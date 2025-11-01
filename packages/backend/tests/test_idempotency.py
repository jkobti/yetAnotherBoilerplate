import json

from django.test import Client


def test_idempotency_key_conflict_on_second_post(db):
    client = Client()
    key = "test-key-123"

    # First POST to a POST endpoint (JWT token obtain), expect not 409
    resp1 = client.post(
        "/api/auth/jwt/token/",
        data=json.dumps({"email": "x@example.com", "password": "bad"}),
        content_type="application/json",
        HTTP_IDEMPOTENCY_KEY=key,
    )
    assert resp1.status_code != 409

    # Second identical POST with same Idempotency-Key must return 409
    resp2 = client.post(
        "/api/auth/jwt/token/",
        data=json.dumps({"email": "x@example.com", "password": "bad"}),
        content_type="application/json",
        HTTP_IDEMPOTENCY_KEY=key,
    )
    assert resp2.status_code == 409, resp2.content
