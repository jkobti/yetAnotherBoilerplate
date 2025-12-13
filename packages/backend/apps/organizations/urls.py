from django.urls import path

from .views import (
    MembershipRoleUpdateView,
    MyPendingInvitesView,
    OrganizationCloseView,
    OrganizationCreateView,
    OrganizationDetailView,
    OrganizationInviteAcceptView,
    OrganizationInviteCreateView,
    OrganizationInviteListView,
    OrganizationInviteRevokeView,
    OrganizationLeaveView,
    OrganizationListView,
    OrganizationMembersView,
    OrganizationSwitchView,
)

app_name = "organizations"

urlpatterns = [
    path("", OrganizationListView.as_view(), name="list"),
    path("create/", OrganizationCreateView.as_view(), name="create"),
    path("my-invites/", MyPendingInvitesView.as_view(), name="my-invites"),
    path("<uuid:org_id>/", OrganizationDetailView.as_view(), name="detail"),
    path("<uuid:org_id>/switch/", OrganizationSwitchView.as_view(), name="switch"),
    path("<uuid:org_id>/leave/", OrganizationLeaveView.as_view(), name="leave"),
    path("<uuid:org_id>/close/", OrganizationCloseView.as_view(), name="close"),
    path("<uuid:org_id>/members/", OrganizationMembersView.as_view(), name="members"),
    path(
        "<uuid:org_id>/members/<uuid:membership_id>/",
        MembershipRoleUpdateView.as_view(),
        name="update-member-role",
    ),
    path(
        "<uuid:org_id>/invites/",
        OrganizationInviteListView.as_view(),
        name="list-invites",
    ),
    path(
        "<uuid:org_id>/invites/send/",
        OrganizationInviteCreateView.as_view(),
        name="create-invite",
    ),
    path(
        "<uuid:org_id>/invites/<uuid:invite_id>/revoke/",
        OrganizationInviteRevokeView.as_view(),
        name="revoke-invite",
    ),
    path(
        "<uuid:org_id>/invites/<str:token>/accept/",
        OrganizationInviteAcceptView.as_view(),
        name="accept-invite",
    ),
]
