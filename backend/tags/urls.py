from rest_framework.routers import SimpleRouter

from .api import TagViewSet

router = SimpleRouter()
router.register("tags", TagViewSet, basename="Tags")

urlpatterns = [] + router.urls
