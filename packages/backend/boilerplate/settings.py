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
]

MIDDLEWARE = [
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
        "anon": "100/day",
        "user": "1000/day",
        # Used by admin endpoints via throttle_scope = 'admin'
        # Keep this tight by default to make abuse obvious in dev and tests.
        "admin": "2/minute",
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
    # Resend is not natively supported by django-anymail; use SMTP fallback
    "resend": "django.core.mail.backends.smtp.EmailBackend",
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
    # Use SMTP settings for Resend (or another provider offering SMTP relay)
    EMAIL_HOST = env("EMAIL_HOST", default="")
    EMAIL_PORT = env("EMAIL_PORT", default=587)
    EMAIL_HOST_USER = env("EMAIL_HOST_USER", default="")
    EMAIL_HOST_PASSWORD = env("EMAIL_HOST_PASSWORD", default="")
    EMAIL_USE_TLS = env("EMAIL_USE_TLS", default=True)

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
