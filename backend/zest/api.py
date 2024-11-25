from . import version

from django.contrib.auth.models import User
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import authentication, permissions


class InfoView(APIView):
    """
    View to provide some simple details
    """

    authentication_classes = []
    permission_classes = []

    def get(self, request, format=None):
        """
        Return information overview
        """
        build_version = getattr(version, "build_version", "git")
        if build_version.startswith("v"):
            build_version = build_version[1:]
        details = {
            "version": version.__version__,
            "build_version": build_version,
        }
        return Response(details)
