from django.contrib import admin

from modeltranslation.admin import TranslationAdmin

from .models import Unit


@admin.register(Unit)
class UnitAdmin(TranslationAdmin):
    list_display = (
        "name",
        "abbreviation",
        "base_unit",
        "conversion_factor",
        "unit_system",
        "id",
    )
