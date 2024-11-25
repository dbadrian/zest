from django.contrib.auth import get_user_model
from rest_framework.decorators import permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework import viewsets

from .serializers import CustomUserSerializer


@permission_classes([IsAuthenticated])
class CustomUserViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = get_user_model().objects.all()
    serializer_class = CustomUserSerializer
