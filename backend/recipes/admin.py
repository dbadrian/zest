from django.utils.translation import gettext_lazy as _
from django.contrib import admin

from modeltranslation.admin import TranslationAdmin

from .models import (
    IngredientGroup,
    Ingredient,
    Instruction,
    InstructionGroup,
    RecipeCategory,
    Recipe,
)


@admin.register(RecipeCategory)
class RecipeCategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "name_plural")
    readonly_fields = ("id",)


class IngredientInline(admin.TabularInline):
    model = Ingredient


admin.site.register(Ingredient)


@admin.register(IngredientGroup)
class IngredientGroupAdmin(admin.ModelAdmin):
    inlines = [
        IngredientInline,
    ]

    def ingredient_display(self):
        return ", ".join([i.name for i in self.ingredients.all()])

    ingredient_display.short_description = _("Ingredients")

    list_display = ("id", "name", ingredient_display)


class InstructionInline(admin.TabularInline):
    model = Instruction


@admin.register(Instruction)
class InstructionAdmin(admin.ModelAdmin):
    list_display = ("id", "preview")


@admin.register(InstructionGroup)
class InstructionGroupAdmin(admin.ModelAdmin):
    inlines = [
        InstructionInline,
    ]


class IngredientGroupInline(admin.TabularInline):
    model = IngredientGroup


class InstructionGroupInline(admin.TabularInline):
    model = InstructionGroup


@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
    list_display = ("title", "recipe_id", "date_created")
    readonly_fields = ("id", "recipe_id", "original_recipe_id")
    inlines = [IngredientGroupInline, InstructionGroupInline]
