from django.urls import path

from .views import (
    OrganizationCreateView,
    OrganizationDetailView,
    OrganizationListView,
    OrganizationMembersView,
    OrganizationSwitchView,
)

app_name = "organizations"

urlpatterns = [
    path("", OrganizationListView.as_view(), name="list"),
    path("create/", OrganizationCreateView.as_view(), name="create"),
    path("<uuid:org_id>/", OrganizationDetailView.as_view(), name="detail"),
    path("<uuid:org_id>/switch/", OrganizationSwitchView.as_view(), name="switch"),
    path("<uuid:org_id>/members/", OrganizationMembersView.as_view(), name="members"),
]
