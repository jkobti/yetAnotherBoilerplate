from __future__ import annotations

from django.conf import settings
from rest_framework import serializers, status
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.notifications.models import DeviceToken

from .models import AdminAudit

# Legacy (fallback): pyfcm using server key
try:
    from pyfcm import FCMNotification  # type: ignore
except Exception:  # pragma: no cover - optional dependency until installed
    FCMNotification = None

# Preferred: Firebase Admin SDK (HTTP v1) using service account
try:
    import json

    import firebase_admin
    from firebase_admin import credentials, initialize_app, messaging
except Exception:  # pragma: no cover - optional dependency until installed
    firebase_admin = None
    credentials = None
    messaging = None


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


class SendTestPushSerializer(serializers.Serializer):
    token = serializers.CharField(required=False)
    title = serializers.CharField(required=False, default="Hello from Admin")
    body = serializers.CharField(required=False, default="This is a test push")


class SendTestPushView(APIView):
    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def post(self, request):
        serializer = SendTestPushSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data.get("token")
        title = serializer.validated_data.get("title")
        body = serializer.validated_data.get("body")

        # Prefer HTTP v1 via Firebase Admin SDK
        v1_available = (
            firebase_admin is not None
            and credentials is not None
            and messaging is not None
        )
        sa_path = getattr(settings, "GOOGLE_APPLICATION_CREDENTIALS", "")
        sa_json = getattr(settings, "GOOGLE_SERVICE_ACCOUNT_JSON", "")

        if v1_available and (sa_path or sa_json):
            # Lazy init default app
            try:
                if not firebase_admin._apps:  # type: ignore[attr-defined]
                    if sa_json:
                        cred = credentials.Certificate(json.loads(sa_json))
                    else:
                        cred = credentials.Certificate(sa_path)
                    initialize_app(cred)
            except Exception as e:  # pragma: no cover
                return Response(
                    {"error": f"Failed to initialize Firebase Admin SDK: {e}"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )

            # Resolve target tokens
            if token:
                tokens = [token]
            else:
                tokens = list(
                    DeviceToken.objects.filter(platform=DeviceToken.PLATFORM_WEB)
                    .order_by("-created_at")
                    .values_list("token", flat=True)[:10]
                )
                if not tokens:
                    return Response(
                        {
                            "error": "No device tokens found. Register from the web app first."
                        },
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            results = []
            for t in tokens:
                try:
                    msg = messaging.Message(
                        token=t,
                        notification=messaging.Notification(title=title, body=body),
                        data={"source": "admin_test"},
                    )
                    resp = messaging.send(msg)
                    results.append({"token": t, "message_id": resp})
                except Exception as e:  # pragma: no cover
                    results.append({"token": t, "error": str(e)})

            AdminAudit.objects.create(
                user=request.user,
                path=request.path,
                method=request.method,
                action="push_send_test_v1",
            )
            return Response({"sent": True, "targets": len(tokens), "results": results})

        # Fallback to legacy server key (deprecated by Google). Useful if already configured.
        server_key = getattr(settings, "FCM_SERVER_KEY", None)
        if FCMNotification is None or not server_key:
            return Response(
                {
                    "error": (
                        "Push not configured. Provide GOOGLE_APPLICATION_CREDENTIALS or GOOGLE_SERVICE_ACCOUNT_JSON "
                        "for FCM HTTP v1 (recommended), or set FCM_SERVER_KEY to use legacy (deprecated)."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        push_service = FCMNotification(api_key=server_key)

        if token:
            result = push_service.notify_single_device(
                registration_id=token,
                message_title=title,
                message_body=body,
                data_message={"source": "admin_test"},
            )
            targets = 1
        else:
            tokens = list(
                DeviceToken.objects.filter(platform=DeviceToken.PLATFORM_WEB)
                .order_by("-created_at")
                .values_list("token", flat=True)[:10]
            )
            if not tokens:
                return Response(
                    {
                        "error": "No device tokens found. Register from the web app first."
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            result = push_service.notify_multiple_devices(
                registration_ids=tokens,
                message_title=title,
                message_body=body,
                data_message={"source": "admin_test"},
            )
            targets = len(tokens)

        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action="push_send_test_legacy",
        )

        return Response({"sent": True, "targets": targets, "result": result})
