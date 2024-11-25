import logging
from typing import Any, Dict, List, Type, Union

from rest_framework import serializers
import drf_serpy as serpy

from favorites.models import FavoriteRecipe

from shared.serializers import (
    SerpyContextSerializer,
    NonNullModelSerializerMixin,
    NonNullModelSerializerMixinSerpy,
    SerpyDateTimeISOTZField,
    update_nested_field,
)
from tags.serializers import (
    ReadTagSerializerSerpy,
    TagSerializer,
    WriteRecipeTagSerializer,
)
from tags.models import Tag

from ..utils import (
    create_from_serializer,
)
from ..models import Recipe, RecipeCategory

from .ingredient import (
    ReadIngredientGroupSerializerSerpy,
    WriteIngredientGroupSerializer,
    ReadIngredientGroupSerializer,
)
from .instruction import (
    ReadInstructionGroupSerializerSerpy,
    WriteInstructionGroupSerializer,
)
from .category import (
    ReadRecipeCategorySerializer,
    ReadRecipeCategorySerializerSerpy,
    WriteRecipeCategorySerializer,
)

logger = logging.getLogger(__name__)


class ReadRecipeSerializerSerpy(
    NonNullModelSerializerMixinSerpy, SerpyContextSerializer
):

    id = serpy.StrField()
    recipe_id = serpy.StrField()
    original_recipe_id = serpy.StrField()
    language = serpy.StrField()
    date_created = SerpyDateTimeISOTZField()
    owner = serpy.MethodField()
    private = serpy.BoolField()
    title = serpy.StrField()
    subtitle = serpy.StrField()
    owner_comment = serpy.StrField()
    tags = ReadTagSerializerSerpy(many=True)
    categories = ReadRecipeCategorySerializerSerpy(many=True, required=False)
    difficulty = serpy.IntField()
    servings = serpy.IntField()
    prep_time = serpy.IntField()
    cook_time = serpy.IntField()
    total_time = serpy.MethodField()
    source_name = serpy.StrField()
    source_page = serpy.IntField()
    source_url = serpy.StrField()
    # "is_up_to_date",
    # "is_translation",
    is_translation = serpy.MethodField()
    ingredient_groups = ReadIngredientGroupSerializerSerpy(many=True)
    instruction_groups = ReadInstructionGroupSerializerSerpy(many=True)
    is_favorite = serpy.MethodField()

    name_plural = "recipes"

    def _set_servings_from_context(self, instance: Recipe):
        """If `servings` is not already set from a query param (cf. api view),
        then it sets servings to the default value, the field 'feeds'."""
        if self.context is None:
            self.context = {}

        if (servings := self.context.get("servings")) is None:
            # self.context["default_serving_size"] = instance.servings
            servings = instance.servings
        else:
            try:
                servings = int(servings)  # from walrus
                self.context["default_serving_size"] = instance.servings

            except ValueError:
                raise serializers.ValidationError(
                    {
                        "detail": "Query parameter `servings` should be an integer (literal)"
                    }
                )

            if servings <= 0:
                raise serializers.ValidationError(
                    {
                        "detail": "Query parameter `servings` should be a positive, non zero, integer"
                    }
                )

            # update instance
            instance.servings = servings

        # update context (will propagate down to other serializers)
        self.context["servings"] = servings

    def to_value(self, instance: Type[Any]) -> Union[Dict, List]:
        if isinstance(instance, list):
            if self.context is not None:
                self.context["servings"] = 1
            else:
                self.context = {"servings": 1}
        else:
            self._set_servings_from_context(instance)  # rescale recipe
        return super().to_value(instance)

    def get_owner(self, obj):
        return obj.owner_id

    def get_total_time(self, obj):
        """required for extra_kwargs 'total_time'"""
        prep_time = obj.prep_time if obj.prep_time else 0
        cook_time = obj.cook_time if obj.cook_time else 0
        return prep_time + cook_time

    # def get_is_up_to_date(self, obj):
    #     """required for extra_kwargs 'is_up_to_date'"""
    #     return obj.is_up_to_date()

    def get_is_translation(self, obj):
        """required for extra_kwargs 'is_translation'"""
        return obj.is_translation()

    def get_is_favorite(self, obj):
        # has to be accessed via method, as it is not  a field
        # but from query set annotation
        if (is_favorite := getattr(obj, "is_favorite", None)) is not None:
            return is_favorite
        else:
            return False


class ReadRecipeSerializer(NonNullModelSerializerMixin, serializers.ModelSerializer):
    instruction_groups = WriteInstructionGroupSerializer(many=True)  # FIXME
    ingredient_groups = ReadIngredientGroupSerializer(many=True)
    tags = TagSerializer(many=True, required=False)
    categories = ReadRecipeCategorySerializer(many=True, required=False)
    total_time = serializers.SerializerMethodField()
    # is_up_to_date = serializers.SerializerMethodField()
    is_translation = serializers.SerializerMethodField()
    # is_favorite = serializers.SerializerMethodField()
    is_favorite = serializers.BooleanField(read_only=True)

    class Meta:
        model = Recipe
        fields = (
            "id",
            "recipe_id",
            "original_recipe_id",
            "language",
            "date_created",
            "owner",
            "private",
            "title",
            "subtitle",
            "owner_comment",
            "tags",
            "categories",
            "difficulty",
            "servings",
            "prep_time",
            "cook_time",
            "total_time",
            "source_name",
            "source_page",
            "source_url",
            # "is_up_to_date",
            "is_translation",
            "ingredient_groups",
            "instruction_groups",
            "is_favorite",
        )
        extra_kwargs = {
            "owner": {"read_only": True, "required": False},
            "language": {"read_only": False, "required": True},
            "recipe_id": {"read_only": False, "required": False},
            "original_recipe_id": {"read_only": False, "required": False},
            "date_created": {"read_only": True},
            "is_up_to_date": {"read_only": True, "required": False},
            "is_translation": {"read_only": True, "required": False},
            "is_favorite": {"read_only": True, "required": False},
            "total_time": {"read_only": True, "required": False},
        }

    def _set_servings_from_context(self, instance: Recipe):
        """If `servings` is not already set from a query param (cf. api view),
        then it sets servings to the default value, the field 'feeds'."""
        if (servings := self.context.get("servings")) is None:
            servings = instance.servings
        else:
            try:
                servings = int(servings)
            except ValueError:
                raise serializers.ValidationError(
                    {
                        "detail": "Query parameter `servings` should be an integer (literal)"
                    }
                )

            if servings <= 0:
                raise serializers.ValidationError(
                    {
                        "detail": "Query parameter `servings` should be a positive, non zero, integer"
                    }
                )

            # update instance
            instance.servings = servings

        # update context (will propagate down to other serializers)
        self.context["servings"] = servings

    def to_representation(self, instance: Recipe):
        self._set_servings_from_context(instance)  # rescale recipe
        ret = super().to_representation(instance)
        return ret

    def get_total_time(self, obj):
        """required for extra_kwargs 'total_time'"""
        prep_time = obj.prep_time if obj.prep_time else 0
        cook_time = obj.cook_time if obj.cook_time else 0
        return prep_time + cook_time

    # def get_is_up_to_date(self, obj):
    #     """required for extra_kwargs 'is_up_to_date'"""
    #     return obj.is_up_to_date()

    def get_is_translation(self, obj):
        """required for extra_kwargs 'is_translation'"""
        return obj.is_translation()

    # def get_is_favorite(self, obj):
    #     """required for extra_kwargs 'is_favorite'"""
    #     if (req := self.context.get("request")) is not None and hasattr(req, "user"):
    #         # return FavoriteRecipe.objects.filter(recipe_id=obj.recipe_id, user=req.user).exists()
    #     else:
    #         return False


class WriteRecipeSerializer(NonNullModelSerializerMixin, serializers.ModelSerializer):
    instruction_groups = WriteInstructionGroupSerializer(many=True)
    ingredient_groups = WriteIngredientGroupSerializer(many=True)
    tags = WriteRecipeTagSerializer(many=True, required=False)
    categories = WriteRecipeCategorySerializer(many=True, required=False)

    class Meta:
        model = Recipe
        fields = (
            "id",
            "recipe_id",
            "original_recipe_id",
            "date_created",
            "owner",
            "language",
            "title",
            "subtitle",
            "owner_comment",
            "private",
            "tags",
            "difficulty",
            "servings",
            "categories",
            "prep_time",
            "cook_time",
            # "total_time",
            "source_name",
            "source_page",
            "source_url",
            "ingredient_groups",
            "instruction_groups",
            # "is_up_to_date",
            "is_translation",
        )
        extra_kwargs = {
            "unit": {
                "read_only": True,
            },
            "owner": {"read_only": True, "required": False},
            "language": {"read_only": False, "required": True},
            "recipe_id": {"read_only": False, "required": False},
            "original_recipe_id": {"read_only": False, "required": False},
            "date_created": {"read_only": True},
            "is_up_to_date": {"read_only": True, "required": False},
            "is_translation": {"read_only": True, "required": False},
            # "total_time": {"read_only": True, "required": False},
        }

    # Use this method for the custom field
    def _get_request_user(self):
        request = self.context.get("request", None)
        if request:
            return request.user

    def _copy_create_content(
        self, recipe, instruction_groups_data, ingredient_groups_data
    ):

        def add_group_and_position(data, recipe, group_name="group"):
            for new_pos, datum in enumerate(data, start=1):
                datum["position"] = new_pos
                datum[group_name] = recipe

        def _normalize_amounts(ingredient: dict, default_serving_size: int) -> None:
            ingredient["amount"] /= default_serving_size
            if ingredient.get("amount_max"):  # checks both existance and not none
                ingredient["amount_max"] /= default_serving_size

        # Update instruction groups
        add_group_and_position(instruction_groups_data, recipe, group_name="recipe")
        create_from_serializer(WriteInstructionGroupSerializer, instruction_groups_data)

        # Update ingredient groups
        add_group_and_position(ingredient_groups_data, recipe, group_name="recipe")
        # # Normalize ingredient amounts
        # for ingrp in ingredient_groups_data:
        #     for ingredient in ingrp["ingredients"]:
        #         _normalize_amounts(ingredient, recipe.servings)
        create_from_serializer(WriteIngredientGroupSerializer, ingredient_groups_data)

    def _create_or_copy(self, validated_data, recipe_id=None):
        self._created_recipe = (
            None  # reset? not sure if necessary but makes things easier down the road
        )
        instruction_groups_data = validated_data.pop("instruction_groups")
        ingredient_groups_data = validated_data.pop("ingredient_groups")
        tags = validated_data.pop("tags", None)
        categories = validated_data.pop("categories", None)

        # Set author=owner from context
        validated_data["owner"] = self._get_request_user()

        # Automatically add the original_recipe_id if this is a new language
        if recipe_id := validated_data.get("recipe_id"):
            original_recipe = Recipe.objects.filter(  # pylint: disable=no-member
                recipe_id=recipe_id, original_recipe_id__isnull=True
            ).latest("date_created")
            if validated_data["language"] != original_recipe.language:
                validated_data["original_recipe_id"] = original_recipe.id

        recipe = Recipe.objects.create(**validated_data)  # pylint: disable=no-member
        self._created_recipe = recipe
        self._copy_create_content(
            recipe, instruction_groups_data, ingredient_groups_data
        )

        # process tags here
        update_nested_field(
            recipe, tags, "tags", "recipes", field_class=Tag, copy_on_pk=True
        )
        update_nested_field(
            recipe,
            categories,
            "categories",
            "recipes",
            field_class=RecipeCategory,
            copy_on_pk=True,
        )

        return recipe

    def create(self, validated_data):
        logger.debug(f"Creating new Recipe from validated_data={validated_data}")
        try:
            return self._create_or_copy(validated_data)
        except:
            if self._created_recipe is not None:
                self._created_recipe.delete()

    def update(self, instance, validated_data):
        logger.debug(f"Copy-Update of Recipe from validated_data={validated_data}")
        try:
            return self._create_or_copy(validated_data)
        except:
            if self._created_recipe is not None:
                self._created_recipe.delete()
