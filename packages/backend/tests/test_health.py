from django.test import Client


def test_health_endpoint_returns_ok():
    client = Client()
    resp = client.get("/health/")
    assert resp.status_code == 200
    assert resp.json().get("status") == "ok"
