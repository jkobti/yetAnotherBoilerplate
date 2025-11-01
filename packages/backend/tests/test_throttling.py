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
            "user": "1000/day",
            "admin": "2/minute",
        },
        "DEFAULT_AUTHENTICATION_CLASSES": [
            "rest_framework_simplejwt.authentication.JWTAuthentication",
            "rest_framework.authentication.SessionAuthentication",
        ],
        "EXCEPTION_HANDLER": "boilerplate.exceptions.problem_details_handler",
    }
)

def test_admin_ping_throttle_exceeded(db):
    User = get_user_model()
    admin = User.objects.create_user(
        email="admin+throttle@example.com", password="testpass", is_staff=True
    )

    client = Client()
    assert client.login(username=admin.email, password="testpass")

    # First two requests OK
    r1 = client.get("/admin/api/ping")
    r2 = client.get("/admin/api/ping")
    assert r1.status_code == 200
    assert r2.status_code == 200

    # Third should be throttled
    r3 = client.get("/admin/api/ping")
    assert r3.status_code == 429
