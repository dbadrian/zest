import os

AUTH_USER_MODEL = "users.CustomUser"

AUTH_MODE = os.environ.get("DJANGO_AUTH_MODE", default="jwt")

# disables (or technically enables if chosen) the ability to create new users
# via the API. This is useful for when you want to manually create users


# Password validation
# https://docs.djangoproject.com/en/3.1/ref/settings/#auth-password-validators
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

AUTHENTICATION_BACKENDS = [
    # Needed to login by username in Django admin, regardless of `allauth`
    "django.contrib.auth.backends.ModelBackend",
    # `allauth` specific authentication methods, such as login by e-mail
    "allauth.account.auth_backends.AuthenticationBackend",
]


REST_AUTH = {
    "USE_JWT": True,
    "JWT_AUTH_HTTPONLY": False,
    "JWT_AUTH_RETURN_EXPIRATION": True,
}

# check environ variable to see if we want to allow new users to be created
# This only works because the custom adapter doesnt implement any other logic
# obviously adapt if you change the logic
ALLOW_NEW_USERS = os.environ.get("ALLOW_NEW_USERS", default="false")
if ALLOW_NEW_USERS.lower() == "false":
    ACCOUNT_ADAPTER = "users.account_adapter.NoNewUsersAccountAdapter"
    REST_AUTH["REGISTER_SERIALIZER"] = "users.registration.RegisterSerializer"

# REST_AUTH_SERIALIZERS = {
#     "JWT_SERIALIZER": "dj_rest_auth.serializers.JWTSerializerWithExpiration",
# }
