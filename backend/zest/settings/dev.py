"""
Development settings for zest project.
"""

import os

from .base import *  # noqa: F403

ACCOUNT_ADAPTER = 'users.account_adapter.NoNewUsersAccountAdapter'


DEBUG = 1
AUTH_MODE = os.environ.get("DJANGO_AUTH_MODE", default="session")

# Cors Settings
CORS_ORIGIN_ALLOW_ALL = True
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOWED_ORIGINS = [
    "http://0.0.0.0:8000",
    "http://localhost:8000",
    "http://127.0.0.1:8080",
    "http://10.0.2.2",
]
CSRF_TRUSTED_ORIGINS = [
    "http://0.0.0.0:8000",
    "http://localhost:8000",
    "http://127.0.0.1:8080",
    "http://0.0.0.0:1337",
    "http://localhost:1337",
    "http://127.0.0.1:1337",
    "http://10.0.2.2",
]

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

if AUTH_MODE == "session":
    REST_FRAMEWORK.update(  # noqa: F405
        {
            "DEFAULT_AUTHENTICATION_CLASSES": (
                "rest_framework.authentication.SessionAuthentication",
            )
        }
    )
    REST_USE_JWT = False
    REST_SESSION_LOGIN = True


SIMPLE_JWT["SLIDING_TOKEN_LIFETIME"] = timedelta(minutes=10000)
SIMPLE_JWT["ACCESS_TOKEN_LIFETIME"] = timedelta(minutes=10000)

MIDDLEWARE = [
    # "silk.middleware.SilkyMiddleware",
    "nplusone.ext.django.NPlusOneMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
] + MIDDLEWARE


REST_FRAMEWORK.update(  # noqa: F405
    {
        # "DEFAULT_THROTTLE_CLASSES": [
        #     "rest_framework.throttling.AnonRateThrottle",
        #     "rest_framework.throttling.UserRateThrottle",
        # ],
        # "DEFAULT_THROTTLE_RATES": {
        #     "anon": "500/day",
        #     "user": "10000/day",
        # },
        # "DEFAULT_RENDERER_CLASSES": [
        #     "rest_framework.renderers.JSONRenderer",
        # ]
    }
)
