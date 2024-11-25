import logging

from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import mixins
from rest_framework.filters import SearchFilter, OrderingFilter
from rest_framework.viewsets import GenericViewSet
from django_auto_prefetching import prefetch as auto_prefetch

from shared.utils.api import set_language_from_request
from shared.api import ReturnDictMixin

from .models import Tag
from .serializers import TagSerializer

logger = logging.getLogger(__name__)


@permission_classes([IsAuthenticated])
class TagViewSet(
        ReturnDictMixin,
        mixins.CreateModelMixin,
        mixins.ListModelMixin,
        GenericViewSet,
):
    serializer_class = TagSerializer
    queryset = Tag.objects.all()

    serializer_class = TagSerializer

    filter_backends = [
        SearchFilter,
        OrderingFilter,
    ]
    search_fields = ["^text"]
    ordering_fields = ["text"]
    ordering = ["text"]

    def get_queryset(self):
        _ = set_language_from_request(self.request)
        qs = Tag.objects.all()
        return auto_prefetch(qs, self.serializer_class)
