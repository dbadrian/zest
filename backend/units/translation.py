from modeltranslation.translator import TranslationOptions
from shared.translator import register

from .models import Unit


@register(Unit)
class UnitTranslationOptions(TranslationOptions):
    fields = ("name", "name_plural", "abbreviation")
