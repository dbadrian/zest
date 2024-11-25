from django.utils import translation
from django.db.models.functions import Least
from django.contrib.postgres.search import (
    TrigramSimilarity,
    TrigramWordSimilarity,
    TrigramStrictWordSimilarity,
    TrigramDistance,
    SearchVector,
    SearchQuery,
    SearchRank,
)

from re import search
from rest_framework.filters import SearchFilter

from shared.language import get_active_language


class DynamicSearchFilter(SearchFilter):

    def get_search_fields(self, view, request):
        if (search_fields := request.GET.get("search_fields", None)) is not None:
            return view.allowed_search_fields.intersection(
                set(search_fields.split(","))
            )
        else:
            return view.default_search_fields


class TrigramSearchFilter(SearchFilter):

    def get_translated_search_fields(self, view, request):
        """
        Search fields are obtained from the view, but the request is always
        passed to this method. Sub-classes can override this method to
        dynamically change the search fields based on request content.
        """
        return getattr(view, "translated_search_fields", None)

    # def get_trigram_similarity(self, view, request):
    #     if (sim := request.query_params.get("similarity")) is not None:
    #         return sim
    #     return getattr(view, "trigram_similarity", 0.3)

    def filter_queryset(self, request, queryset, view):
        # trigram_similarity = self.get_trigram_similarity(view, request)
        search_fields = self.get_search_fields(view, request)
        translated_search_fields = self.get_translated_search_fields(view, request)
        search_terms = self.get_search_terms(request)
        # inspired by
        # https://medium.com/@dumanov/powerfull-and-simple-search-engine-in-django-rest-framework-cb24213f5ef5
        if search_terms is None and translated_search_fields is None:
            return queryset

        conditions = []

        if translated_search_fields is not None:
            lc, _ = get_active_language()
            for search_term in search_terms:
                conditions.extend(
                    [
                        # TrigramSimilarity(f"{field}_{lc}", search_term)
                        # TrigramWordSimilarity(search_term, f"{field}_{lc}")
                        TrigramDistance(f"{field}_{lc}", search_term)
                        for field in translated_search_fields
                    ]
                )
        print(">>>>>", conditions)

        if search_fields is not None:
            for search_term in search_terms:
                conditions.extend(
                    [
                        # TrigramSimilarity(field, search_term)
                        # TrigramWordSimilarity(search_term, field)
                        TrigramDistance(field, search_term)
                        for field in search_fields
                    ]
                )

        print(search_fields, search_terms)
        if len(conditions) > 1:
            return (
                queryset.annotate(similarity=Least(*conditions))
                # .filter(similarity__gte=trigram_similarity)
                # .filter(similarity__lte=0.7)
                .order_by("similarity")
            )
        elif len(conditions) == 1:
            return (
                queryset.annotate(similarity=conditions[0])
                # .filter(similarity__lte=trigram_similarity)
                .order_by("similarity")
            )
        else:
            return queryset
