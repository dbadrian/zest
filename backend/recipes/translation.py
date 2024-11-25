from modeltranslation.translator import TranslationOptions
from shared.translator import register

from .models.category import RecipeCategory


@register(RecipeCategory)
class RecipeCategoryTranslationOptions(TranslationOptions):
    fields = ("name", "name_plural")
