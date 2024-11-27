from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import OrderingFilter
from rest_framework.decorators import permission_classes
from django_auto_prefetching import prefetch as auto_prefetch
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from django.views.decorators.vary import vary_on_cookie, vary_on_headers
from django.db.models import Value

from shared.api import ReturnDictMixin
from shared.filters import TrigramSearchFilter
from shared.utils.api import set_language_from_request

from .models import Unit
from .serializers import ReadUnitSerializer, ReadUnitSerializerSerpy, UnitSerializer


# @method_decorator(cache_page(60 * 60 * 2), "dispatch")
# @method_decorator(vary_on_cookie, "dispatch")
@permission_classes([IsAuthenticated])
class UnitViewSet(ReturnDictMixin, viewsets.ReadOnlyModelViewSet):
    serializer_class = ReadUnitSerializerSerpy

    filter_backends = [
        TrigramSearchFilter,
        # OrderingFilter,
    ]
    translated_search_fields = ["name", "name_plural", "abbreviation"]
    # search_fields = ["name"]  # , "name_plural", "abbreviation"]
    # ordering_fields = ["id", "name", "name_plural", "unit_system"]
    # ordering = ["id"]
    trigram_similarity = 0.1

    def get_queryset(self):
        set_language_from_request(self.request)
        qs = Unit.objects.all()
        # qs = qs.annotate(similarity=Value(1.0))  # pylint: disable=no-member
        # return auto_prefetch(qs, self.serializer_class)
        return qs
