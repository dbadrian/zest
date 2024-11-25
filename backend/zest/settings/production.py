"""
Development settings for zest project.
"""

import os
from .base import *  # noqa: F403


def assert_set(var, name):
    if var is None or not var:
        raise AssertionError(f"Environment variable `{name}` was not set!")


DEBUG = 0  # production can never be a debug build!

# Cors Settings
CORS_ORIGIN_ALLOW_ALL = True
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOWED_ORIGINS = os.environ.get("CORS_ALLOWED_ORIGINS", "").split(",")
assert_set(CORS_ALLOWED_ORIGINS, "CORS_ALLOWED_ORIGINS")

# SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
# SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
CSRF_TRUSTED_ORIGINS = os.environ.get("CSRF_TRUSTED_ORIGINS", "").split(",")
assert_set(CSRF_TRUSTED_ORIGINS, "CSRF_TRUSTED_ORIGINS")

MEDIA_ROOT = os.environ.get("MEDIA_ROOT", "")
assert_set(MEDIA_ROOT, "MEDIA_ROOT")
STATIC_ROOT = os.environ.get("STATIC_ROOT", "")
assert_set(MEDIA_ROOT, "STATIC_ROOT")

EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_HOST = os.environ.get("EMAIL_HOST")
EMAIL_PORT = os.environ.get("EMAIL_PORT")
EMAIL_HOST_USER = os.environ.get("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = os.environ.get("EMAIL_HOST_PASSWORD")
EMAIL_USE_TLS = os.environ.get("EMAIL_USE_TLS")
EMAIL_USE_SSL = os.environ.get("EMAIL_USE_SSL")
EMAIL_TIMEOUT = os.environ.get("EMAIL_TIMEOUT")
EMAIL_SSL_KEYFILE = os.environ.get("EMAIL_SSL_KEYFILE")
EMAIL_SSL_CERTFILE = os.environ.get("EMAIL_SSL_CERTFILE")
# TODO: do asserts

AUTH_MODE = "jwt"

REST_FRAMEWORK.update(  # noqa: F405
    {
        "DEFAULT_THROTTLE_CLASSES": [
            "rest_framework.throttling.AnonRateThrottle",
            "rest_framework.throttling.UserRateThrottle",
        ],
        "DEFAULT_THROTTLE_RATES": {
            "anon": "500/day",
            "user": "10000/day",
        },
        "DEFAULT_RENDERER_CLASSES": [
            "rest_framework.renderers.JSONRenderer",
        ],
    }
)

# API Prefix
API_PREFIX = os.environ.get("API_PREFIX", "")

MIDDLEWARE = [
    # 'silk.middleware.SilkyMiddleware',
] + MIDDLEWARE
