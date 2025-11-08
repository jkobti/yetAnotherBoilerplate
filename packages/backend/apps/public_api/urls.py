from django.urls import path
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
    TokenVerifyView,
)

from .views import (
    ActiveFeatureFlagsView,
    MagicLinkRequestView,
    MagicLinkVerifyView,
    MeView,
    PushRegisterView,
    RegisterView,
)

app_name = "public_api"

urlpatterns = [
    path("v1/me", MeView.as_view(), name="me"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("push/register/", PushRegisterView.as_view(), name="push-register"),
    path("features/", ActiveFeatureFlagsView.as_view(), name="featureflags-active"),
    # Magic link passwordless auth
    path("auth/magic/request/", MagicLinkRequestView.as_view(), name="magic-request"),
    path("auth/magic/verify/", MagicLinkVerifyView.as_view(), name="magic-verify"),
    # JWT Auth
    path("auth/jwt/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/jwt/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("auth/jwt/verify/", TokenVerifyView.as_view(), name="token_verify"),
]
