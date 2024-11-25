from django.utils.translation import gettext_lazy as _
from django.contrib import admin

from .models import ShoppingList, ShoppingListEntry


class ShoppingListEntrytInline(admin.TabularInline):
    model = ShoppingListEntry


@admin.register(ShoppingList)
class ShoppingListAdmin(admin.ModelAdmin):
    inlines = [
        ShoppingListEntrytInline,
    ]

    def recipe_names_display(self):
        return ", ".join([i.recipe.title for i in self.entries.all()])

    recipe_names_display.short_description = _("Recipes contained")

    list_display = ("title", recipe_names_display, "id")
