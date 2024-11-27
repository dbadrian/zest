from typing import List
from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import viewsets
from rest_framework.filters import OrderingFilter, BaseFilterBackend
from rest_framework.request import Request
from rest_framework.response import Response
from django_auto_prefetching import prefetch as auto_prefetch
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from django.views.decorators.vary import vary_on_cookie, vary_on_headers
from shared.filters import TrigramSearchFilter
from django.db.models import Value

from .models import Food, FoodNameSynonyms
from .serializers import (
    ReadFoodSerializerSerpy,
    ReadFoodSynonymSerializerSerpy,
    WriteFoodSerializer,
    FoodSynonymSerializer,
)
from shared.permissions import IsAdminOrCreateOnly
from shared.utils.api import set_language_from_request
from shared.api import (
    ReadWriteSerializerMixin,
    ReturnDictMixin,
    TranslatedModelCreationMixin,
)


def add_query_params_to_context(context: dict, request: Request):
    context.update(
        {
            "lang": request.query_params.get("lang"),
        }
    )


def filter_by_list_of_pks(qs, request):
    # check if parameter "pks" exists, gets a list and then filters the queryset accordingly
    if (pks := request.query_params.get("pks")) is not None:
        pks = pks.split(",")
        return qs.filter(id__in=pks)
    else:
        return qs


@permission_classes([IsAuthenticated, IsAdminOrCreateOnly])
class FoodViewSet(
    ReturnDictMixin,
    TranslatedModelCreationMixin,
    ReadWriteSerializerMixin,
    viewsets.ModelViewSet,
):
    """
    retrieve:
    Return the given food.

    list:
    Return a list of all the existing foods.

    create:
    Create a new food instance.
    """

    read_serializer_class = ReadFoodSerializerSerpy
    write_serializer_class = WriteFoodSerializer

    filter_backends = [
        TrigramSearchFilter,
        # FullTextSearchFilter
        # OrderingFilter,
    ]
    translated_search_fields = ["name"]
    ordering_fields = ["name"]

    min_similarity = 0.1

    def get_queryset(self):
        _ = set_language_from_request(self.request)
        qs = Food.objects.all().annotate(similarity=Value(1.0))
        # # qs = auto_prefetch(qs, self.serializer_class)
        # if self.get_serializer_class() == ReadFoodSerializer:
        #     qs = qs.prefetch_related("synonyms")

        # check if parameters exists and get them
        return filter_by_list_of_pks(qs, self.request)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        # Add additional query_parameters to context
        add_query_params_to_context(context, self.request)
        return context


def filter_by_languages(queryset, language_codes: List[str]):
    return (
        queryset.filter(language__in=language_codes)
        if language_codes is not None
        else queryset
    )


def get_language_codes_from_request(request):
    # TODO: lc_filter is a bit shit term
    if (language_codes := request.query_params.get("lc_filter")) is not None:
        language_codes = language_codes.split(",")
    return language_codes


class LanguageFilterFoodCustomized(BaseFilterBackend):
    """
    Filter by language field customized for food search
    """

    def filter_queryset(self, request, queryset, view):
        # lang = set_language_from_request(request)
        language_codes = get_language_codes_from_request(request)
        if language_codes:
            # filter for a specific language, but add all those, where not match can be found
            return filter_by_languages(queryset, language_codes)
        return queryset


# @method_decorator(cache_page(60 * 60 * 2), 'dispatch')
# @method_decorator(vary_on_cookie, 'dispatch')
@permission_classes([IsAuthenticated, IsAdminOrCreateOnly])
class FoodSynonymViewSet(
    ReturnDictMixin,
    TranslatedModelCreationMixin,
    ReadWriteSerializerMixin,
    viewsets.ModelViewSet,
):
    """
    retrieve:
    Return the given food.

    list:
    Return a list of all the existing foods.

    create:WriteFoodSerializer
    Create a new food instance.
    """

    read_serializer_class = ReadFoodSynonymSerializerSerpy
    write_serializer_class = FoodSynonymSerializer

    filter_backends = [
        LanguageFilterFoodCustomized,
        TrigramSearchFilter,
        OrderingFilter,
    ]

    search_fields = ["name"]
    ordering_fields = ["name"]
    min_similarity = 0.1

    def get_queryset(self):
        # _ = set_language_from_request(self.request)
        # qs = FoodNameSynonyms.objects.all()
        qs = FoodNameSynonyms.objects.all().annotate(similarity=Value(1.0))
        # qs = qs.prefetch_related("food")
        # qs = auto_prefetch(qs, self.serializer_class)
        return qs

    def get_serializer_context(self):
        context = super().get_serializer_context()
        # Add additional query_parameters to context
        add_query_params_to_context(context, self.request)
        return context
