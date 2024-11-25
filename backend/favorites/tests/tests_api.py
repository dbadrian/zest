import logging
from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework import status

from shared.tools_utest import basic_response_validation, get_api_client
from shared.translator import set_language


logger = logging.getLogger(__name__)
# pylint: disable=no-member

APIBASE = "/api/v1/"


class FavoritesApiTest(TestCase):
    """favorites.api.FavoritesViewSet"""

    def setUp(self):
        pass
