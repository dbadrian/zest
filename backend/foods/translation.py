from modeltranslation.translator import TranslationOptions
from shared.translator import register

from .models import Food


@register(Food)
class FoodTranslationOptions(TranslationOptions):
    fields = ("name", "description")
    empty_values = None