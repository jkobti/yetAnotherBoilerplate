from __future__ import annotations

from typing import Callable

from django.http import JsonResponse, HttpRequest, HttpResponse
from django.utils.deprecation import MiddlewareMixin

from apps.public_api.models import IdempotencyKey


class IdempotencyMiddleware(MiddlewareMixin):
    """Simple idempotency guard using the Idempotency-Key header.

    Behavior:
    - If header missing: pass through.
    - If present and (key, path, method) exists: return 409 conflict.
    - Else: record and continue.
    """

    def process_request(self, request: HttpRequest) -> HttpResponse | None:
        if request.method not in {"POST", "PUT", "PATCH"}:
            return None
        key = request.headers.get("Idempotency-Key")
        if not key:
            return None
        exists = IdempotencyKey.objects.filter(
            key=key, path=request.path, method=request.method
        ).exists()
        if exists:
            return JsonResponse(
                {
                    "type": "https://httpstatuses.com/409",
                    "title": "Idempotency key reused",
                    "status": 409,
                    "detail": "The provided Idempotency-Key has already been used for this request.",
                },
                status=409,
            )
        # request.user may not be set if AuthenticationMiddleware hasn't run yet
        django_user = getattr(request, "user", None)
        user_value = django_user if getattr(django_user, "is_authenticated", False) else None

        IdempotencyKey.objects.create(
            key=key,
            path=request.path,
            method=request.method,
            user=user_value,
        )
        return None
