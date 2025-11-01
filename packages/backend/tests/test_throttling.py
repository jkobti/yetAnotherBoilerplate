from django.contrib.auth import get_user_model
from django.test import Client
from django.test.utils import override_settings


@override_settings(
    REST_FRAMEWORK={
        "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
        "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
        "PAGE_SIZE": 25,
        "DEFAULT_THROTTLE_CLASSES": [
            "rest_framework.throttling.AnonRateThrottle",
            "rest_framework.throttling.UserRateThrottle",
            "rest_framework.throttling.ScopedRateThrottle",
        ],
        "DEFAULT_THROTTLE_RATES": {
            "anon": "100/day",
            "user": "2/minute",
        },
        "DEFAULT_AUTHENTICATION_CLASSES": [
            "rest_framework_simplejwt.authentication.JWTAuthentication",
            "rest_framework.authentication.SessionAuthentication",
        ],
        "EXCEPTION_HANDLER": "boilerplate.exceptions.problem_details_handler",
    }
)
def test_user_me_throttle_exceeded(db):
    User = get_user_model()
    user = User.objects.create_user(
        email="user+throttle@example.com", password="testpass"
    )

    client = Client()
    assert client.login(username=user.email, password="testpass")

    # First two requests OK
    r1 = client.get("/api/v1/me")
    r2 = client.get("/api/v1/me")
    assert r1.status_code == 200
    assert r2.status_code == 200

    # Third should be throttled (UserRateThrottle @ 2/minute)
    r3 = client.get("/api/v1/me")
    assert r3.status_code == 429


@override_settings(
    REST_FRAMEWORK={
        "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
        "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
        "PAGE_SIZE": 25,
        "DEFAULT_THROTTLE_CLASSES": [
            "rest_framework.throttling.AnonRateThrottle",
            "rest_framework.throttling.UserRateThrottle",
            "rest_framework.throttling.ScopedRateThrottle",
        ],
        "DEFAULT_THROTTLE_RATES": {
            "anon": "100/day",
            "user": "2/minute",
        },
        "DEFAULT_AUTHENTICATION_CLASSES": [
            "rest_framework_simplejwt.authentication.JWTAuthentication",
            "rest_framework.authentication.SessionAuthentication",
        ],
        "EXCEPTION_HANDLER": "boilerplate.exceptions.problem_details_handler",
    }
)
def test_user_throttle_sets_retry_after_header(db):
    User = get_user_model()
    user = User.objects.create_user(
        email="user+headers@example.com", password="testpass"
    )

    client = Client()
    assert client.login(username=user.email, password="testpass")

    client.get("/api/v1/me")
    client.get("/api/v1/me")
    resp = client.get("/api/v1/me")
    assert resp.status_code == 429
    # Our problem-details handler should preserve DRF's throttling headers
    assert "Retry-After" in resp.headers
    body = resp.json()
    assert body.get("status") == 429
