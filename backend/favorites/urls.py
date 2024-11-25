from rest_framework.routers import SimpleRouter

from .api import FavoriteRecipeViewSet

router = SimpleRouter()
router.register("favorites", FavoriteRecipeViewSet, basename="Favorites")

urlpatterns = [] + router.urls
