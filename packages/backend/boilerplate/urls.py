from django.conf import settings
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path
from django.views.generic import RedirectView
from drf_spectacular.views import SpectacularAPIView, SpectacularRedocView


def health_view(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    # More specific admin API must come before the general Django admin route
    path("admin/api/", include("apps.admin_api.urls")),
    path("admin/", admin.site.urls),
    path("health/", health_view, name="health"),
]

if getattr(settings, "API_DOCS_ENABLED", False):
    urlpatterns += [
        # Default root redirects to API Docs when enabled
        path(
            "", RedirectView.as_view(pattern_name="redoc", permanent=False), name="root"
        ),
        path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
        path(
            "api/docs/",
            SpectacularRedocView.as_view(url_name="schema"),
            name="redoc",
        ),
        path("api/", include("apps.public_api.urls")),
    ]
else:
    # Without docs, land the root on a simple health/status endpoint
    urlpatterns += [
        path("", health_view, name="root"),
        path("api/", include("apps.public_api.urls")),
    ]

# (admin/api/ included above to ensure correct precedence)
