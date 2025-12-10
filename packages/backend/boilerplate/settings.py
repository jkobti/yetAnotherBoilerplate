import ast
from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent

# Environment
env = environ.Env(
    DEBUG=(bool, True),
    SECRET_KEY=(str, "dev-insecure-secret-key"),
    ALLOWED_HOSTS=(list, ["*"]),
    API_DOCS_ENABLED=(bool, True),
    # Application mode: "b2c" (personal workspace auto-created) or "b2b" (explicit org creation)
    APP_MODE=(str, "b2c"),
    FCM_SERVER_KEY=(str, ""),
    GOOGLE_APPLICATION_CREDENTIALS=(str, ""),  # path to service account JSON (HTTP v1)
    GOOGLE_SERVICE_ACCOUNT_JSON=(str, ""),  # alternatively, raw JSON string
    # Magic link auth settings
    RESEND_API_KEY=(str, ""),
    # IMPORTANT: MAGIC_LINK_VERIFY_URL MUST be an absolute URL to the frontend route that handles verification.
    # Example: https://app.example.com or https://app.example.com/auth
    # The code will append /magic-verify?token=... if you supply only the base. If you point directly
    # to a page that already ends with /magic-verify it will just add ?token=.
    # It MUST start with http:// or https://. Empty value will raise at runtime when sending a magic link.
    MAGIC_LINK_VERIFY_URL=(str, ""),
    # Shorter default (5 minutes) reduces window for brute force on 8-digit codes.
    MAGIC_LINK_EXPIRY_MINUTES=(int, 5),
    MAGIC_LINK_DEBUG_ECHO_TOKEN=(
        bool,
        True,
    ),  # include raw token in response when DEBUG
)
# Load .env if present at project root (packages/backend/.env)
env_file = BASE_DIR / ".env"
if env_file.exists():
    environ.Env.read_env(env_file)

DEBUG = env("DEBUG")
SECRET_KEY = env("SECRET_KEY")
ALLOWED_HOSTS = env("ALLOWED_HOSTS")
# Normalize ALLOWED_HOSTS for cases like ALLOWED_HOSTS=["*"] coming from .env
if isinstance(ALLOWED_HOSTS, list | tuple) and len(ALLOWED_HOSTS) == 1:
    only = ALLOWED_HOSTS[0]
    if isinstance(only, str) and only.strip().startswith("["):
        try:
            parsed = ast.literal_eval(only)
            if isinstance(parsed, list | tuple):
                ALLOWED_HOSTS = [str(h).strip() for h in parsed]
        except Exception:
            pass
if isinstance(ALLOWED_HOSTS, list | tuple):
    ALLOWED_HOSTS = [str(h).strip() for h in ALLOWED_HOSTS]
API_DOCS_ENABLED = env("API_DOCS_ENABLED")

# Application mode: "b2c" or "b2b"
# - b2c: Personal workspace auto-created on registration, team features hidden
# - b2b: Users must explicitly create/join organizations, full team UI
APP_MODE = env("APP_MODE").lower()
if APP_MODE not in ("b2c", "b2b"):
    raise ValueError(f"APP_MODE must be 'b2c' or 'b2b', got '{APP_MODE}'")

FCM_SERVER_KEY = env("FCM_SERVER_KEY")

# Resolve GOOGLE_APPLICATION_CREDENTIALS path relative to BASE_DIR if not absolute
_gac = env("GOOGLE_APPLICATION_CREDENTIALS")
if _gac and not _gac.startswith("/"):
    GOOGLE_APPLICATION_CREDENTIALS = str(BASE_DIR / _gac)
else:
    GOOGLE_APPLICATION_CREDENTIALS = _gac

GOOGLE_SERVICE_ACCOUNT_JSON = env("GOOGLE_SERVICE_ACCOUNT_JSON")

# Applications
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # 3rd party
    "corsheaders",
    "rest_framework",
    "drf_spectacular",
    "anymail",
    "rest_framework_simplejwt",
    # Optional: enable refresh token blacklist/rotation
    "rest_framework_simplejwt.token_blacklist",
    # Local apps
    "apps.users",
    "apps.organizations",
    "apps.notifications",
    "apps.public_api",
    "apps.admin_api",
    "apps.featureflags",
    "django_prometheus",
]

MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "corsheaders.middleware.CorsMiddleware",  # must be high in the chain
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    # Ensure idempotency runs after auth so request.user is available
    "boilerplate.middleware.IdempotencyMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]

ROOT_URLCONF = "boilerplate.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "boilerplate.wsgi.application"
ASGI_APPLICATION = "boilerplate.asgi.application"

# Database: default to SQLite for local dev; override via DATABASE_URL
DATABASES = {
    "default": env.db(
        "DATABASE_URL",
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
    )
}

# Auth: custom user model
AUTH_USER_MODEL = "users.User"

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Internationalization
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# DRF config: schema, pagination, throttling, errors
REST_FRAMEWORK = {
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 25,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
        "rest_framework.throttling.ScopedRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "1000/minute",
        "user": "5000/minute",
        # Used by admin endpoints via throttle_scope = 'admin'
        "admin": "500/minute",
    },
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        # Keep session auth for admin site/dev browsable API
        "rest_framework.authentication.SessionAuthentication",
    ],
    "EXCEPTION_HANDLER": "boilerplate.exceptions.problem_details_handler",
}

# drf-spectacular config
SPECTACULAR_SETTINGS = {
    "TITLE": "yetAnotherBoilerplate API",
    "DESCRIPTION": "OpenAPI schema for the example backend.",
    "VERSION": "0.1.0",
}

# Email / Anymail
EMAIL_PROVIDER = env("EMAIL_PROVIDER", default="console").lower()
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default="no-reply@example.local")

ANYMAIL = {
    # per-provider API keys are read from env in provider-specific settings below
}

_EMAIL_BACKENDS = {
    "console": "django.core.mail.backends.console.EmailBackend",
    "smtp": "django.core.mail.backends.smtp.EmailBackend",
    "mailgun": "anymail.backends.mailgun.EmailBackend",
    "postmark": "anymail.backends.postmark.EmailBackend",
    "sendgrid": "anymail.backends.sendgrid.EmailBackend",
    # Resend supported via anymail since v10.2
    "resend": "anymail.backends.resend.EmailBackend",
}

EMAIL_BACKEND = _EMAIL_BACKENDS.get(EMAIL_PROVIDER, _EMAIL_BACKENDS["console"])

# Provider-specific environment variables (optional)
if EMAIL_PROVIDER == "mailgun":
    ANYMAIL.update(
        {
            "MAILGUN_API_KEY": env("MAILGUN_API_KEY", default=""),
            "MAILGUN_SENDER_DOMAIN": env("MAILGUN_DOMAIN", default=""),
        }
    )
elif EMAIL_PROVIDER == "postmark":
    ANYMAIL.update(
        {
            "POSTMARK_SERVER_TOKEN": env("POSTMARK_SERVER_TOKEN", default=""),
        }
    )
elif EMAIL_PROVIDER == "sendgrid":
    ANYMAIL.update(
        {
            "SENDGRID_API_KEY": env("SENDGRID_API_KEY", default=""),
        }
    )
elif EMAIL_PROVIDER == "resend":
    # Anymail Resend backend settings
    ANYMAIL.update(
        {
            "RESEND_API_KEY": env("RESEND_API_KEY", default=""),
            # Optional: provide signing secret if using webhooks
            "RESEND_SIGNING_SECRET": env(
                "RESEND_SIGNING_SECRET", default=""
            ),  # leave blank if unused
        }
    )

# Magic Link settings (plain values; logic in apps.users.magic_link)
RESEND_API_KEY = env("RESEND_API_KEY")
MAGIC_LINK_VERIFY_URL = env("MAGIC_LINK_VERIFY_URL")
MAGIC_LINK_EXPIRY_MINUTES = env("MAGIC_LINK_EXPIRY_MINUTES")
MAGIC_LINK_DEBUG_ECHO_TOKEN = env("MAGIC_LINK_DEBUG_ECHO_TOKEN")

# (Idempotency middleware already included above in correct order)

# SimpleJWT settings
from datetime import timedelta  # noqa: E402

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": False,
    "BLACKLIST_AFTER_ROTATION": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
    # Use the custom user's primary key field
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "sub",
}

# CORS (allow Flutter web dev server by default in DEBUG)
try:
    # env may not have these keys; keep defaults sensible for dev
    CORS_ALLOW_ALL_ORIGINS = env.bool("CORS_ALLOW_ALL_ORIGINS", default=DEBUG)
except Exception:  # pragma: no cover - env helper guards
    CORS_ALLOW_ALL_ORIGINS = DEBUG

# If not allowing all, permit localhost:* during development for convenience
if not CORS_ALLOW_ALL_ORIGINS:
    CORS_ALLOWED_ORIGIN_REGEXES = env.list(
        "CORS_ALLOWED_ORIGIN_REGEXES",
        default=[r"^http://localhost:\\d+$", r"^http://127\\.0\\.0\\.1:\\d+$"],
    )

# Celery Configuration
CELERY_BROKER_URL = env("CELERY_BROKER_URL", default="redis://localhost:6379/0")
CELERY_RESULT_BACKEND = env("CELERY_RESULT_BACKEND", default="redis://localhost:6379/0")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
