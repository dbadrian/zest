from django.urls import path
from rest_framework.routers import SimpleRouter

from .api import UnitViewSet

router = SimpleRouter()
router.register("units", UnitViewSet, basename="Unit")

urlpatterns = [] + router.urls
