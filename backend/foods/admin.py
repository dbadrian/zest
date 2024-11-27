from django.utils.translation import gettext_lazy as _
from django.contrib import admin

from modeltranslation.admin import TranslationAdmin

from .models import Food, FoodNameSynonyms, MeasuredNutrient, Nutrient


@admin.register(Nutrient)
class NutrientAdmin(admin.ModelAdmin):
    list_display = ("name", "unit")


@admin.register(FoodNameSynonyms)
class FoodSynonymAdmin(admin.ModelAdmin):
    list_display = ("name", "food")


class MeasuredNutrientInline(admin.TabularInline):
    model = MeasuredNutrient


@admin.register(Food)
class FoodAdmin(TranslationAdmin):
    inlines = [
        MeasuredNutrientInline,
    ]

    list_display = ("id", "name")
