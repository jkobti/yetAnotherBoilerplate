from __future__ import annotations

from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import AdminAudit


class PingView(APIView):
    permission_classes = [IsAdminUser]
    # Do not throttle admin endpoints by default; rely on RBAC and auditing.
    throttle_classes: list = []

    def get(self, request):
        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action="ping",
        )
        return Response({"ok": True})
