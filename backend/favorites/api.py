import logging

from rest_framework import status
from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import mixins
from rest_framework.viewsets import GenericViewSet
from rest_framework.response import Response
from django_auto_prefetching import prefetch as auto_prefetch

from shared.api import ReturnDictMixin

from .models import FavoriteRecipe
from .serializers import FavoriteRecipeSerializer

logger = logging.getLogger(__name__)


@permission_classes([IsAuthenticated])
class FavoriteRecipeViewSet(
        ReturnDictMixin,
        mixins.CreateModelMixin,
        mixins.ListModelMixin,
        GenericViewSet,
):
    serializer_class = FavoriteRecipeSerializer

    def get_queryset(self):
        qs = FavoriteRecipe.objects.filter(user=self.request.user)
        return auto_prefetch(qs, self.serializer_class)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        # Add additional query_parameters to context
        context.update({"user": self.request.user})
        return context

    def destroy(self, request, *args, **kwargs):
        fav_entry = None
        if (pk := kwargs.get("pk")):
            fav_entry = FavoriteRecipe.objects.filter(pk=pk)
        elif (rid := kwargs.get("recipe_id")):
            fav_entry = FavoriteRecipe.objects.filter(recipe=rid)

        if fav_entry is not None and fav_entry.exists():
            fav_entry.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        else:
            return Response(status=status.HTTP_404_NOT_FOUND)
