from __future__ import annotations

from django.conf import settings
from rest_framework import serializers, status
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.featureflags.models import FeatureFlag
from apps.featureflags.serializers import FeatureFlagSerializer
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


class UsersListView(APIView):
    """List users with their device token counts for push notification targeting."""

    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def get(self, request):
        from django.contrib.auth import get_user_model
        from django.db.models import Count

        User = get_user_model()
        queryset = User.objects.annotate(token_count=Count("devicetoken"))

        # Apply filters
        email_filter = request.query_params.get("email")
        if email_filter:
            queryset = queryset.filter(email__icontains=email_filter)

        is_active_filter = request.query_params.get("is_active")
        if is_active_filter is not None:
            queryset = queryset.filter(is_active=is_active_filter.lower() == "true")

        is_staff_filter = request.query_params.get("is_staff")
        if is_staff_filter is not None:
            queryset = queryset.filter(is_staff=is_staff_filter.lower() == "true")

        users = queryset.values(
            "id",
            "email",
            "first_name",
            "last_name",
            "is_active",
            "is_staff",
            "date_joined",
            "token_count",
        ).order_by("-date_joined", "email")

        return Response({"users": list(users)})


class SendTestPushSerializer(serializers.Serializer):
    token = serializers.CharField(required=False)
    user_ids = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        help_text="List of user IDs to notify",
    )
    title = serializers.CharField(required=False, default="Hello from Admin")
    body = serializers.CharField(required=False, default="This is a test push")


class SendTestPushView(APIView):
    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def post(self, request):
        serializer = SendTestPushSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data.get("token")
        user_ids = serializer.validated_data.get("user_ids")
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
            elif user_ids:
                # Send to specific users
                tokens = list(
                    DeviceToken.objects.filter(
                        user_id__in=user_ids, platform=DeviceToken.PLATFORM_WEB
                    ).values_list("token", flat=True)
                )
                if not tokens:
                    return Response(
                        {"error": "No device tokens found for selected users."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            else:
                # Default: send to last 10 tokens
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


class UserDetailView(APIView):
    """Get a single user's details."""

    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def get(self, request, user_id):
        from django.contrib.auth import get_user_model
        from django.db.models import Count
        from rest_framework.exceptions import NotFound

        User = get_user_model()
        try:
            user = (
                User.objects.filter(id=user_id)
                .annotate(token_count=Count("devicetoken"))
                .values(
                    "id",
                    "email",
                    "first_name",
                    "last_name",
                    "is_active",
                    "is_staff",
                    "is_superuser",
                    "date_joined",
                    "last_login",
                    "token_count",
                )
                .get()
            )
        except User.DoesNotExist:
            raise NotFound("User not found") from None

        return Response(user)

    def delete(self, request, user_id):
        from django.contrib.auth import get_user_model
        from django.db import transaction
        from rest_framework.exceptions import NotFound

        User = get_user_model()
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            raise NotFound("User not found") from None

        email = user.email

        # Log the audit before deletion
        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action=f"delete_user:{email}",
        )

        # Use transaction to ensure consistency
        try:
            with transaction.atomic():
                user.delete()
        except Exception as e:
            # Log the error but still return a meaningful response
            return Response(
                {"detail": f"Error deleting user: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response(
            {"detail": f"User {email} deleted successfully"}, status=status.HTTP_200_OK
        )


class FeatureFlagListCreateView(APIView):
    """List and create feature flags (admin-only)."""

    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def get(self, request):
        qs = FeatureFlag.objects.all().order_by("key")
        data = FeatureFlagSerializer(qs, many=True).data
        return Response({"flags": data})

    def post(self, request):
        ser = FeatureFlagSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        obj = ser.save()
        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action=f"featureflag_create:{obj.key}",
        )
        return Response(FeatureFlagSerializer(obj).data, status=status.HTTP_201_CREATED)


class FeatureFlagDetailView(APIView):
    """Retrieve, update, delete a feature flag."""

    permission_classes = [IsAdminUser]
    throttle_scope = "admin"

    def get_object(self, flag_id):
        from rest_framework.exceptions import NotFound

        try:
            return FeatureFlag.objects.get(id=flag_id)
        except FeatureFlag.DoesNotExist:  # pragma: no cover - simple path
            raise NotFound("Feature flag not found") from None

    def get(self, request, flag_id):
        obj = self.get_object(flag_id)
        return Response(FeatureFlagSerializer(obj).data)

    def patch(self, request, flag_id):
        obj = self.get_object(flag_id)
        ser = FeatureFlagSerializer(obj, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action=f"featureflag_update:{obj.key}",
        )
        return Response(FeatureFlagSerializer(obj).data)

    def delete(self, request, flag_id):
        obj = self.get_object(flag_id)
        key = obj.key
        obj.delete()
        AdminAudit.objects.create(
            user=request.user,
            path=request.path,
            method=request.method,
            action=f"featureflag_delete:{key}",
        )
        return Response(status=status.HTTP_204_NO_CONTENT)
