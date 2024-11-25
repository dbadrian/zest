import uuid

from django.db import models
from django.utils.translation import gettext_lazy as _
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

from recipes.models.recipe import Recipe


class FavoriteRecipe(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe_id = models.UUIDField(blank=False, null=False)
    # recipe = models.ForeignKey(Recipe, related_name="favorites", on_delete=models.PROTECT)
    user = models.ForeignKey(get_user_model(), related_name="+", on_delete=models.PROTECT)

    class Meta:
        verbose_name = _("Favorite Recipe")
        unique_together = ('recipe_id', 'user')

    def clean(self):
        if not Recipe.objects.filter(recipe_id=self.recipe.recipe_id).exists():
            raise ValidationError(f"No recipe with recipe_id='{self.recipe.recipe_id}' exists.")
