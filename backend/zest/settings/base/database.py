# Database
# https://docs.djangoproject.com/en/3.1/ref/settings/#databases
# https://testdriven.io/blog/dockerizing-django-with-postgres-gunicorn-and-nginx/
import os

DATABASES = {
    "default": {
        "ENGINE": os.environ.get("SQL_ENGINE"),
        "NAME": os.environ.get("SQL_DATABASE"),
        "USER": os.environ.get("SQL_USER"),
        "PASSWORD": os.environ.get("SQL_PASSWORD"),
        "HOST": os.environ.get("SQL_HOST"),
        "PORT": os.environ.get("SQL_PORT"),
    }
}
