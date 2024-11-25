# from django.urls import path
from rest_framework.routers import SimpleRouter

from .api import CustomUserViewSet

router = SimpleRouter()
router.register("users", CustomUserViewSet)

urlpatterns = router.urls
