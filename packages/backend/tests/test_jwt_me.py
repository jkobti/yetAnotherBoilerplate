import json

from django.contrib.auth import get_user_model
from django.test import Client


def test_jwt_obtain_and_me_endpoint(db):
    User = get_user_model()
    email = "user1@example.com"
    password = "testpass123"
    User.objects.create_user(email=email, password=password, is_active=True)

    client = Client()

    # Obtain JWT tokens
    resp = client.post(
        "/api/auth/jwt/token/",
        data=json.dumps({"email": email, "password": password}),
        content_type="application/json",
    )
    assert resp.status_code == 200, resp.content
    data = resp.json()
    assert "access" in data and "refresh" in data

    access = data["access"]

    # Call protected endpoint with Bearer token
    resp2 = client.get(
        "/api/v1/me",
        HTTP_AUTHORIZATION=f"Bearer {access}",
    )
    assert resp2.status_code == 200, resp2.content
    body = resp2.json()
    assert body["data"]["email"] == email
