from django.urls import path
from rest_framework.routers import SimpleRouter

from .recipe import RecipeViewSet, RecipeVersionListView
from .recipe_categories import RecipeCategoryViewSet

router = SimpleRouter()

router.register("recipe_categories", RecipeCategoryViewSet, basename="Recipe_Category")
router.register("recipes", RecipeViewSet, basename="Recipe")
urlpatterns = [
    path("recipes/<uuid:recipe_id>/versions", RecipeVersionListView.as_view()),
] + router.urls
