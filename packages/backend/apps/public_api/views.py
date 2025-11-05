from __future__ import annotations

from django.contrib.auth import get_user_model
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import AnonRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from apps.notifications.models import DeviceToken


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        data = {
            "id": str(user.id),
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "is_staff": user.is_staff,
            "date_joined": user.date_joined.isoformat(),
        }
        return Response({"data": data})


User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    first_name = serializers.CharField(required=False, allow_blank=True)
    last_name = serializers.CharField(required=False, allow_blank=True)

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Email already registered")
        return value

    def create(self, validated_data):
        return User.objects.create_user(
            email=validated_data["email"],
            password=validated_data["password"],
            first_name=validated_data.get("first_name", ""),
            last_name=validated_data.get("last_name", ""),
        )


class RegisterView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [AnonRateThrottle]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        # Issue JWT tokens for convenience in demos
        refresh = RefreshToken.for_user(user)
        data = {
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": {
                "id": str(user.id),
                "email": user.email,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "is_staff": user.is_staff,
                "date_joined": user.date_joined.isoformat(),
            },
        }
        return Response(data, status=status.HTTP_201_CREATED)


class PushRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=512)
    platform = serializers.CharField(required=False, default=DeviceToken.PLATFORM_WEB)
    user_agent = serializers.CharField(required=False, allow_blank=True)


class PushRegisterView(APIView):
    """Register or update a push device token.

    - If authenticated, associates the token to the current user.
    - Idempotent on token: updates existing record with latest user/UA.
    """

    permission_classes = [AllowAny]
    throttle_classes = [AnonRateThrottle]

    def post(self, request):
        serializer = PushRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token = serializer.validated_data["token"].strip()
        platform = serializer.validated_data["platform"]
        ua = serializer.validated_data.get("user_agent", "")

        obj, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                "platform": platform or DeviceToken.PLATFORM_WEB,
                "user": request.user if request.user.is_authenticated else None,
                "user_agent": ua,
            },
        )
        return Response(
            {
                "created": created,
                "id": str(obj.id),
                "platform": obj.platform,
                "user": str(obj.user_id) if obj.user_id else None,
            }
        )
