from django.urls import path

from .views import PingView, SendTestPushView, UserDetailView, UsersListView

app_name = "admin_api"

urlpatterns = [
    path("ping", PingView.as_view(), name="ping"),
    path("users", UsersListView.as_view(), name="users-list"),
    path("users/<uuid:user_id>", UserDetailView.as_view(), name="user-detail"),
    path("push/send-test", SendTestPushView.as_view(), name="push-send-test"),
]
