import logging

from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.template.loader import render_to_string

from apps.organizations.models import OrganizationInvite

logger = logging.getLogger(__name__)


@shared_task
def send_org_invite_email(invite_id):
    """
    Send organization invitation email to invited user.
    Follows the same pattern as magic link email sending.
    """
    try:
        invite = OrganizationInvite.objects.select_related(
            "organization", "invited_by"
        ).get(id=invite_id)
    except OrganizationInvite.DoesNotExist:
        logger.error(f"OrganizationInvite {invite_id} not found")
        return

    if invite.status != OrganizationInvite.STATUS_PENDING:
        logger.info(f"Invite {invite_id} is not pending, skipping email")
        return

    # Build accept link using MAGIC_LINK_VERIFY_URL (same as magic link auth)
    frontend_base = getattr(settings, "MAGIC_LINK_VERIFY_URL", "http://localhost:8080")
    # Strip any path component to get just the origin
    if "/magic-verify" in frontend_base:
        frontend_base = frontend_base.rsplit("/magic-verify", 1)[0]
    accept_url = (
        f"{frontend_base}/invites/{invite.organization.id}/{invite.token_hash}/accept"
    )

    inviter_name = invite.invited_by.email if invite.invited_by else "An admin"
    org_name = invite.organization.name

    subject = f"You're invited to join {org_name}"

    text_body = (
        f"Hello,\n\n"
        f"{inviter_name} has invited you to join {org_name} on YetAnotherBoilerplate.\n\n"
        f"Click to accept: {accept_url}\n\n"
        f"This invitation expires in 7 days."
    )

    html_body = render_to_string(
        "organizations/invite_email.html",
        {
            "inviter_name": inviter_name,
            "org_name": org_name,
            "accept_url": accept_url,
        },
    )

    try:
        send_mail(
            subject,
            text_body,
            getattr(settings, "DEFAULT_FROM_EMAIL", "no-reply@example.local"),
            [invite.invited_email],
            html_message=html_body,
            fail_silently=True,
        )
        logger.info(
            f"Invitation email sent to {invite.invited_email} for org {invite.organization.id}"
        )
    except Exception as e:
        logger.error(f"Failed to send invite email for invite {invite_id}: {str(e)}")
        raise
