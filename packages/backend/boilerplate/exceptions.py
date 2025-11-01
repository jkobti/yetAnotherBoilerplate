from __future__ import annotations

from typing import Any

from rest_framework.views import exception_handler as drf_exception_handler
from rest_framework.response import Response


def problem_details_handler(exc: Exception, context: dict[str, Any]) -> Response | None:
    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    detail = response.data
    title = getattr(exc, "default_detail", "Error")
    status = response.status_code

    problem = {
        "type": "about:blank",
        "title": str(title),
        "status": status,
        "detail": detail if isinstance(detail, str) else None,
    }

    if isinstance(detail, dict):
        problem["errors"] = detail

    return Response(problem, status=status)
