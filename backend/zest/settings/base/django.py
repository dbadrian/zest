import os
from .globals import BASE_DIR

# https://docs.djangoproject.com/en/3.1/ref/contrib/sites/
SITE_ID = 1

# https://docs.djangoproject.com/en/3.1/ref/settings/#std:setting-SECRET_KEY
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
assert SECRET_KEY, "Secret was not set!"

# https://docs.djangoproject.com/en/3.1/ref/settings/#root-urlconf
ROOT_URLCONF = "zest.urls"

ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS").split(",")
assert ALLOWED_HOSTS, "ALLOWED_HOSTS shouldn't be empty."
# TODO: probably should have some assert here

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
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

WSGI_APPLICATION = "zest.wsgi.application"

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/3.1/howto/static-files/

STATIC_URL = "/static/"
# STATICFILES_DIRS = [str(BASE_DIR.joinpath('static'))]
STATIC_ROOT = str(BASE_DIR.joinpath("static"))
# STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.StaticFilesStorage'
# STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

STORAGES = {
    # "default": {
    #     "BACKEND": "example.storages.ExtendedFileSystemStorage",
    # },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"
    },
}


MEDIA_URL = "/media/"
MEDIA_ROOT = str(BASE_DIR.joinpath("media"))

FILE_UPLOAD_PERMISSIONS = 0o640  # TODO: Configure that correctly

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

SILKY_PYTHON_PROFILER = True
