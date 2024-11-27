import logging

from rest_framework import serializers

from favorites.models import FavoriteRecipe
from recipes.models.recipe import Recipe

logger = logging.getLogger(__name__)


class FavoriteRecipeSerializer(serializers.ModelSerializer):

    class Meta:
        fields = ["id", "recipe_id", "user"]
        model = FavoriteRecipe
        extra_kwargs = {
            "id": {
                "read_only": True,
                "required": False
            },
            "recipe_id": {
                "required": False
            },
            "user": {
                "read_only": True,
                "required": False
            },
        }

    def validate_recipe_id(self, value):
        if not Recipe.objects.filter(recipe_id=value).exists():
            raise serializers.ValidationError('No recipe with exists with this recipe_id.')
        return value

    def create(self, validated_data):
        logger.debug(f"Creating new FavoriteEntry from validated_data={validated_data}")
        entry = FavoriteRecipe.objects.create(**validated_data, user=self.context["user"])
        return entry
