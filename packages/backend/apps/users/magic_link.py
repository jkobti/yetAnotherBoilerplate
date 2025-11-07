from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone

from .models import MagicLink

User = get_user_model()


@dataclass
class CreatedMagicLink:
    raw_token: str
    record: MagicLink


def _hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _generate_code(length: int = 8) -> str:
    """Return a numeric code of given length (leading zeros allowed)."""
    # 10^length possibilities; with 8 digits we have 100M space.
    return f"{secrets.randbelow(10**length):0{length}d}"  # zero-padded


def create_magic_link(
    email: str, *, ip: str = "", user_agent: str = ""
) -> CreatedMagicLink:
    """Create a MagicLink DB record with an 8-digit numeric code (hashed).

    The raw code is NOT stored; only its SHA256 hash is persisted.
    Collisions are extremely unlikely but we defensively retry if unique constraint hits.
    """
    email_norm = User.objects.normalize_email(email)
    user = User.objects.filter(email__iexact=email_norm).first()
    attempts = 0
    while True:
        raw_token = _generate_code(8)
        token_hash = _hash_token(raw_token)
        expires_at = timezone.now() + timedelta(
            minutes=int(settings.MAGIC_LINK_EXPIRY_MINUTES)
        )
        try:
            record = MagicLink.objects.create(
                email=email_norm,
                user=user,
                token_hash=token_hash,
                expires_at=expires_at,
                ip_address=ip,
                user_agent=user_agent[:1000],
            )
            break
        except Exception as err:  # pragma: no cover - extremely rare collision
            attempts += 1
            if attempts > 5:
                # Chain original error to distinguish collision retries from other failures.
                raise RuntimeError(
                    "Failed to generate unique magic code after 5 attempts"
                ) from err
    return CreatedMagicLink(raw_token=raw_token, record=record)


def send_magic_link(record: MagicLink, raw_token: str, *, request=None) -> None:
    """Send the magic link email (short code) via configured backend.

    Requires MAGIC_LINK_VERIFY_URL to be set to the frontend route that handles verification.
    We avoid backend URL fallback to prevent user confusion.
    """
    verify_base = (getattr(settings, "MAGIC_LINK_VERIFY_URL", "") or "").strip()
    if not verify_base:
        raise RuntimeError(
            "MAGIC_LINK_VERIFY_URL is not set. Configure an absolute frontend URL (e.g. https://app.example.com)."
        )
    if not (verify_base.startswith("http://") or verify_base.startswith("https://")):
        raise RuntimeError(
            f"MAGIC_LINK_VERIFY_URL must start with http:// or https:// (got: {verify_base!r})"
        )
    # Normalize: allow either direct /magic-verify or a base without it
    # Always prefer path param style for consistency with Flutter web route matching.
    base_clean = verify_base.rstrip("/")
    if base_clean.endswith("magic-verify"):
        verify_url = f"{base_clean}/{raw_token}"
    else:
        verify_url = f"{base_clean}/magic-verify/{raw_token}"
    subject = "Your sign-in link"
    text_body = (
        f"Hello,\n\nYour sign-in code is: {raw_token}\n"
        f"Or click to sign in: {verify_url}\n\n"
        f"Code/link expire in {settings.MAGIC_LINK_EXPIRY_MINUTES} minute(s) or after first use."
    )
    html_body = (
        f"<p>Hello,</p>"
        f"<p>Your sign-in code: <strong style='font-size:20px'>{raw_token}</strong></p>"
        f"<p>Or <a href='{verify_url}'>click here to sign in</a>.</p>"
        f"<p>Expires in {settings.MAGIC_LINK_EXPIRY_MINUTES} minute(s) or after first use.</p>"
    )
    from django.core.mail import send_mail

    send_mail(
        subject,
        text_body,
        getattr(settings, "DEFAULT_FROM_EMAIL", "no-reply@example.local"),
        [record.email],
        html_message=html_body,
        fail_silently=True,  # avoid raising dev errors if mail server absent
    )


def verify_magic_link(raw_token: str) -> User | None:
    """Verify a raw token, mark record used, and return the associated user.

    If no user existed at creation time, create a new one now (signup-on-first-use).
    Returns None if token invalid/expired/used.
    """
    token_hash = _hash_token(raw_token)
    now = timezone.now()
    ml = (
        MagicLink.objects.select_for_update()
        .filter(token_hash=token_hash, used_at__isnull=True, expires_at__gt=now)
        .first()
    )
    if not ml:
        return None
    # Resolve user (create lazily if needed) BEFORE deleting record
    user = ml.user
    if not user:
        user = User.objects.create_user(email=ml.email, password=None)
    # Hard delete for single-use cleanup (reduces table size, removes hash)
    ml.delete()
    return user
