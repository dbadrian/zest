from django.urls import path
from rest_framework.routers import SimpleRouter

from .api import FoodSynonymViewSet, FoodViewSet

router = SimpleRouter()
router.register("foods", FoodViewSet, basename="Food")
router.register("food_synonyms", FoodSynonymViewSet, basename="FoodSynonym")

urlpatterns = [] + router.urls
