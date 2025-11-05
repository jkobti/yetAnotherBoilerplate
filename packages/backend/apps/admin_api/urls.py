from django.urls import path

from .views import PingView, SendTestPushView

app_name = "admin_api"

urlpatterns = [
    path("ping", PingView.as_view(), name="ping"),
    path("push/send-test", SendTestPushView.as_view(), name="push-send-test"),
]
