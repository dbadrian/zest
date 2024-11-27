from django.contrib import admin

from .models import FavoriteRecipe


@admin.register(FavoriteRecipe)
class UnitAdmin(admin.ModelAdmin):
    list_display = ("id", 'recipe_id', "user")
