from django.urls import path
from rest_framework.routers import SimpleRouter

from .api import ShoppingListViewSet, ShoppingListSummaryView

router = SimpleRouter()
router.register("shopping_lists", ShoppingListViewSet, basename="ShoppingList")

urlpatterns = [
    path("shopping_lists/<uuid:recipe_id>/summary", ShoppingListSummaryView.as_view()),
] + router.urls
