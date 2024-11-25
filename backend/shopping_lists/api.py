import logging
from collections import defaultdict
from decimal import Decimal

from django.http import Http404
from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from django_auto_prefetching import prefetch as auto_prefetch

from shared.permissions import IsAdminOrOwnerOrReadOnly
from shared.utils.api import set_language_from_request
from shared.api import ReturnDictMixin

from .models import ShoppingList
from .serializers import ShoppingListSerializer

logger = logging.getLogger(__name__)


@permission_classes([IsAuthenticated, IsAdminOrOwnerOrReadOnly])
class ShoppingListViewSet(ReturnDictMixin, viewsets.ModelViewSet):
    serializer_class = ShoppingListSerializer
    def get_queryset(self):
            # Simply do the extra select_related / prefetch_related here
            # and leave the mixin to do the rest of the work
            queryset = ShoppingList.objects.all()
            return auto_prefetch(queryset, self.serializer_class)


@permission_classes([IsAuthenticated])
class ShoppingListSummaryView(APIView):
    """
    Retrieves summary of a shopping list (list of recipes)
    """

    def get_object(self, shopping_list_id):
        try:
            return ShoppingList.objects.get(id=shopping_list_id)
        except ShoppingList.DoesNotExist:
            raise Http404

    def _aggregate_ingredients(self, obj):
        # in the first pass, we need a unique key,
        # that is the food.name and unit
        ret = defaultdict(lambda: {"amount": Decimal(), "amount_max": Decimal()})
        for entry in obj.entries.all():
            for ingredient_group in entry.recipe.ingredient_groups.all():
                ings = ingredient_group.collect_ingredients()
                for k, v in ings.items():
                    ret[k]["amount"] += v["amount"]
                    ret[k]["amount_max"] += v["amount_max"]

        # second pass converts to a flat list
        # and dynamically add "amount_max" iff necessary
        ingredients = []
        for k, v in ret.items():
            e = {"name": k[0], "unit": k[1], "amount": v["amount"]}
            if v["amount"] < v["amount_max"]:
                e["amount_max"] = v["amount_max"]
            ingredients.append(e)

        return ingredients

    def _aggregate_recipes(self, obj):
        recipes = []
        for entry in obj.entries.all():
            recipes.append({"id": entry.recipe.id, "servings": entry.servings})
        return recipes

    def get(self, request, recipe_id, format=None):
        set_language_from_request(self.request)
        obj = self.get_object(recipe_id)

        res = {
            "ingredients": self._aggregate_ingredients(obj),
            "recipes": self._aggregate_recipes(obj),
        }

        return Response(res)
