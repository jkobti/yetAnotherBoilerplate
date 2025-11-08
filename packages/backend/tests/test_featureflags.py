from django.contrib.auth import get_user_model
from django.test import Client

from apps.featureflags.models import FeatureFlag


def test_active_featureflags_endpoint(db):
    FeatureFlag.objects.create(key="news_ticker", name="News Ticker", enabled=True)
    FeatureFlag.objects.create(key="referral_banner", name="Referral", enabled=False)
    client = Client()
    resp = client.get("/api/features/")
    assert resp.status_code == 200, resp.content
    data = resp.json()
    assert "flags" in data
    assert "news_ticker" in data["flags"]
    assert "referral_banner" not in data["flags"]


def test_admin_crud_featureflags(db):
    User = get_user_model()
    admin = User.objects.create_superuser(
        email="admin@example.com", password="pass1234"
    )
    client = Client()
    assert client.login(username=admin.email, password="pass1234")

    # Create
    resp = client.post(
        "/admin/api/features",
        data={"key": "new_flag", "name": "New Flag", "enabled": True},
    )
    assert resp.status_code == 201, resp.content
    fid = resp.json()["id"]

    # Duplicate create should yield 400 with friendly error
    resp_dup = client.post(
        "/admin/api/features",
        data={"key": "new_flag", "name": "Another", "enabled": False},
    )
    assert resp_dup.status_code == 400
    body_dup = resp_dup.json()
    assert "key" in body_dup, body_dup
    assert "already exists" in body_dup["key"][0]

    # List
    resp = client.get("/admin/api/features")
    assert resp.status_code == 200
    assert any(f["key"] == "new_flag" for f in resp.json()["flags"])

    # Patch
    resp = client.patch(
        f"/admin/api/features/{fid}",
        data={"enabled": False},
        content_type="application/json",
    )
    assert resp.status_code == 200
    assert resp.json()["enabled"] is False

    # Delete
    resp = client.delete(f"/admin/api/features/{fid}")
    assert resp.status_code == 204
    assert not FeatureFlag.objects.filter(id=fid).exists()
