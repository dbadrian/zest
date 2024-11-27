import logging

from django.http import Http404
from django.core.exceptions import ValidationError
from django.db.models import Q
from django.db.models import Prefetch, Exists, OuterRef, Subquery
from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.request import Request
from rest_framework.decorators import action
from rest_framework import status
from rest_framework import viewsets
from rest_framework.filters import OrderingFilter
from favorites.models import FavoriteRecipe
from recipes.serializers.recipe import ReadRecipeSerializerSerpy
from shared.permissions import IsOwnerOrReadOnly
from shared.utils.api import set_language_from_request
from shared.api import (
    FullResponseSerializeMixin,
    ReadWriteSerializerMixin,
    ReturnDictMixin,
)
from shared.filters import DynamicSearchFilter
from django_auto_prefetching import prefetch as auto_prefetch


from .filters import (
    LanguageFilter,
    MostRecentVersion,
    filter_by_languages,
    get_language_codes_from_request,
    sort_most_recent_versions,
)
from ..models import Recipe
from ..serializers import ReadRecipeSerializer, WriteRecipeSerializer

logger = logging.getLogger(__name__)


def add_query_params_to_context(context: dict, request: Request):
    context.update(
        {
            "servings": request.query_params.get("servings"),
            "to_metric": (
                False if request.query_params.get("to_metric") is None else True
            ),
            "lang": request.query_params.get("lang"),
        }
    )


@permission_classes([IsAuthenticated, IsOwnerOrReadOnly])
class RecipeViewSet(
    ReturnDictMixin,
    FullResponseSerializeMixin,
    ReadWriteSerializerMixin,
    viewsets.ModelViewSet,
):
    read_serializer_class = ReadRecipeSerializerSerpy
    write_serializer_class = WriteRecipeSerializer

    lookup_field = "recipe_id"
    filter_backends = [
        LanguageFilter,
        MostRecentVersion,
        DynamicSearchFilter,
        OrderingFilter,
    ]
    allowed_search_fields = {
        "title",
        "subtitle",
        # "owner_comment",
        # "source_name",
        # "source_url",
    }
    default_search_fields = {"title"}
    ordering_fields = [
        "title",
        "difficulty",
        "prep_time",
        "cook_time",
        "total_time",
        # "language",
        "date_created",
    ]

    def get_queryset(self):
        _ = set_language_from_request(self.request)

        # Get all recipes that are either `public` or owned by the user
        qs = Recipe.objects.filter(Q(private=False) | Q(owner=self.request.user))

        qs = qs.prefetch_related("tags")
        qs = qs.prefetch_related("categories")
        qs = qs.prefetch_related(
            "instruction_groups",
            "instruction_groups__instructions",
        )
        qs = qs.prefetch_related(
            "ingredient_groups",
            "ingredient_groups__ingredients",
            "ingredient_groups__ingredients__unit",
            "ingredient_groups__ingredients__food",
        )

        # qs = qs.filter(Q(private=False) | Q(owner=self.request.user))
        qs = qs.annotate(
            is_favorite=Exists(
                Subquery(FavoriteRecipe.objects.filter(recipe_id=OuterRef("recipe_id")))
            )
        )

        # Filter by specific user, or the owner itself
        if (user := self.request.query_params.get("user", None)) is not None:
            if user == "owner":
                # Special value; only return recipes created by the current
                # request making user
                qs = qs.filter(owner=self.request.user)
            else:
                # TODO: Should probably the user_id???
                try:
                    qs = qs.filter(owner__id=user)
                except ValidationError:
                    raise Http404

        # If the string matches `True` we only show recipes that have been favorited by the user.
        if (
            fav_only := self.request.query_params.get("favorites")
        ) is not None and fav_only == "True":
            # fav_ids = [r.recipe_id for r in FavoriteRecipe.objects.filter(user=self.request.user)]
            qs = qs.filter(is_favorite=True)

        # filter by categories
        if (categories := self.request.query_params.get("categories")) is not None:
            categories = [int(c) for c in categories.split(",")]
            qs = qs.filter(categories__id__in=categories).distinct()

        return qs

    def get_serializer_context(self):
        context = super().get_serializer_context()
        # Add additional query_parameters to context
        add_query_params_to_context(context, self.request)
        return context

    def destroy(self, request, *args, **kwargs):
        if recipe_id := kwargs.pop("recipe_id"):
            # TODO: Not sure if this fails if queryset is empty
            recipes = Recipe.objects.filter(recipe_id=recipe_id)
            recipes.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            return Response(status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=["post"])
    def add_to_favorites(self, request, recipe_id=None):
        if recipe_id is not None:
            fav_entry = FavoriteRecipe.objects.filter(recipe_id=recipe_id)
            if fav_entry.exists():
                return Response(status=status.HTTP_409_CONFLICT)
            else:
                FavoriteRecipe.objects.create(recipe_id=recipe_id, user=request.user)
                return Response(status=status.HTTP_201_CREATED)

        return Response(status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=["delete"])
    def remove_from_favorites(self, request, recipe_id=None):
        if recipe_id is not None:
            fav_entry = FavoriteRecipe.objects.filter(recipe_id=recipe_id)
            if fav_entry.exists():
                fav_entry.delete()
                return Response(status=status.HTTP_204_NO_CONTENT)
            else:
                return Response(status=status.HTTP_404_NOT_FOUND)

        return Response(status=status.HTTP_404_NOT_FOUND)


@permission_classes([IsAuthenticated])
class RecipeVersionListView(APIView):
    """
    Retrieve list of all versions of a specific recipe.
    """

    def get_object(self, recipe_id):
        try:
            return Recipe.objects.filter(recipe_id=recipe_id).order_by(
                "recipe_id", "-date_created"
            )
        except Recipe.DoesNotExist:
            raise Http404

    def get(self, request, recipe_id, format=None):
        lang = set_language_from_request(self.request)
        qs = self.get_object(recipe_id)
        # TODO: DO we want to filter by languages?
        # qs = filter_by_languages(qs, [lang])
        if qs.exists():
            serializer = self.get_serializer(qs, many=True)
            return Response(serializer.data)
        else:
            raise Http404

    def delete(self, request, recipe_id, format=None):
        recipes = self.get_object(recipe_id)
        if recipes.exists():
            recipes.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            return Response(status=status.HTTP_404_NOT_FOUND)

    def get_serializer_context(self):
        context = {}
        # Add additional query_parameters to context
        add_query_params_to_context(context, self.request)
        return context

    def get_serializer(self, *args, **kwargs):
        """
        Return the serializer instance that should be used for validating and
        deserializing input, and for serializing output.
        """
        serializer_class = ReadRecipeSerializer
        kwargs["context"] = self.get_serializer_context()
        return serializer_class(*args, **kwargs)
