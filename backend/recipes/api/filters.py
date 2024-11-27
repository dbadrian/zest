from typing import List

from rest_framework.filters import BaseFilterBackend
from shared.utils.api import set_language_from_request


def get_language_codes_from_request(request):
    # TODO: lc_filter is a bit shit term
    if (language_codes := request.query_params.get("lc_filter")) is not None:
        language_codes = language_codes.split(",")
    return language_codes


def filter_by_languages(queryset, language_codes: List[str]):
    return queryset.filter(language__in=language_codes) if language_codes is not None else queryset


def sort_most_recent_versions(queryset):
    return queryset.order_by(
        "recipe_id",
        "-date_created",
    )


class LanguageFilter(BaseFilterBackend):
    """
    Filter by language field
    """

    def filter_queryset(self, request, queryset, view):
        # lang = set_language_from_request(request)
        language_codes = get_language_codes_from_request(request)
        if language_codes:
            # filter for a specific language, but add all those, where not match can be found
            return filter_by_languages(queryset, language_codes)
        else:
            # TODO: maybe not the behavior we want (also specific to recipes, NOT GENERALISTIC!)
            # remove all translated copies -> original is groundtruth
            return queryset.filter(original_recipe_id__isnull=True)


class MostRecentVersion(BaseFilterBackend):
    """
    Filter that only gets the most recent
    """

    def filter_queryset(self, request, queryset, view):
        # TODO: Two calls, but not avoidable? with the ORM, I need to do everythin
        # in memory by converting the QS to an Iterable. Meh
        most_recent_version = sort_most_recent_versions(queryset).distinct("recipe_id")

        return queryset.filter(id__in=most_recent_version)
