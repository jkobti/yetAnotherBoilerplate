from django.urls import path

from .views import MeView

app_name = "public_api"

urlpatterns = [
    path("v1/me", MeView.as_view(), name="me"),
]
