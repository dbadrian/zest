import os

from django.utils.translation import gettext_lazy as _

from .globals import BASE_DIR

#  Internationalization
# https://docs.djangoproject.com/en/3.1/topics/i18n/

LANGUAGE_CODE = "en-us"
USE_I18N = True
USE_L10N = True
USE_TZ = True
TIME_ZONE = "Europe/Berlin"
LOCALE_PATHS = [os.path.join(BASE_DIR, "locale")]
LANGUAGES = [
    ("de", _("German")),
    ("en", _("English")),
    ("fr", _("French")),
    ("it", _("Italian")),
    ("es", _("Spanish")),
    ("pt", _("Portuguese")),
    ("cs", _("Czech")),
    ("ja", _("Japanese")),

]
MODELTRANSLATION_FALLBACK_LANGUAGES = ("de", "en", "fr", "it", "es", "pt", "cs", "ja")
MODELTRANSLATION_DEFAULT_LANGUAGE = None
VALID_LANGUAGES = {abv for abv, _ in LANGUAGES}
