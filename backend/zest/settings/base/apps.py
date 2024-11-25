# Application definition
import logging


INSTALLED_APPS = [
    "django.contrib.postgres",
    "modeltranslation",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "whitenoise.runserver_nostatic",
    "django.contrib.sites",
    # 3rd-party
    # "silk",
    # "nplusone.ext.django",
    "corsheaders",
    "rest_framework",
    "rest_framework.authtoken",
    "dj_rest_auth",
    "allauth",
    "allauth.account",
    "allauth.socialaccount",  # TODO: remove in future when 0.63.0 is supported by dj_rest_auth
    "dj_rest_auth.registration",
    # openapi
    "drf_spectacular",
    # "allauth.socialaccount",
    # "drf_yasg2",
    # local (ORDERED LIST)
    "users.apps.UsersConfig",
    "shared.apps.SharedConfig",
    "units.apps.UnitsConfig",
    "foods.apps.FoodsConfig",
    "tags.apps.TagsConfig",
    "recipes.apps.RecipesConfig",
    "favorites.apps.FavoritesConfig",
    "shopping_lists.apps.ShoppingListsConfig",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.locale.LocaleMiddleware",
    "django.middleware.common.CommonMiddleware",
    # "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    # "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "allauth.account.middleware.AccountMiddleware",
]

NPLUSONE_LOGGER = logging.getLogger("nplusone")
NPLUSONE_LOG_LEVEL = logging.WARN
