from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.filters import SearchFilter, OrderingFilter
from rest_framework.decorators import permission_classes
from django_auto_prefetching import prefetch as auto_prefetch

from shared.api import ReturnDictMixin
from shared.utils.api import set_language_from_request

from ..models import RecipeCategory
from ..serializers import ReadRecipeCategorySerializerSerpy


@permission_classes([IsAuthenticated])
class RecipeCategoryViewSet(ReturnDictMixin, viewsets.ReadOnlyModelViewSet):
    serializer_class = ReadRecipeCategorySerializerSerpy

    filter_backends = [
        SearchFilter,
        OrderingFilter,
    ]
    search_fields = ["name", "name_plural"]
    ordering_fields = ["name"]
    ordering = "id"

    def get_queryset(self):
        set_language_from_request(self.request)
        qs = RecipeCategory.objects.all()  # pylint: disable=no-member
        return auto_prefetch(qs, self.serializer_class)
