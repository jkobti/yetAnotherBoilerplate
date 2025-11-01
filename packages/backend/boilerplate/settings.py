import os
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
if isinstance(ALLOWED_HOSTS, (list, tuple)) and len(ALLOWED_HOSTS) == 1:
    only = ALLOWED_HOSTS[0]
    if isinstance(only, str) and only.strip().startswith("["):
        try:
            parsed = ast.literal_eval(only)
            if isinstance(parsed, (list, tuple)):
                ALLOWED_HOSTS = [str(h).strip() for h in parsed]
        except Exception:
            pass
if isinstance(ALLOWED_HOSTS, (list, tuple)):
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
    "rest_framework",
    "drf_spectacular",
    # Local apps
    "apps.users",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
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

# DRF config (basic defaults)
REST_FRAMEWORK = {
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

# drf-spectacular config
SPECTACULAR_SETTINGS = {
    "TITLE": "yetAnotherBoilerplate API",
    "DESCRIPTION": "OpenAPI schema for the example backend.",
    "VERSION": "0.1.0",
}
