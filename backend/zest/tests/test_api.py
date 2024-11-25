import logging
from django.test import TestCase

from shared.tools_utest import get_api_client, get

from ..version import __version__

# silence django warning
logger = logging.getLogger('django.request')
logger.setLevel(logging.ERROR)

logger = logging.getLogger(__name__)

URL = "info"


class InfoApiTest(TestCase):
    """ zest.api.InfoView """

    def test_post(self):
        """Valid object creation"""
        client = get_api_client()
        response = get(client, URL)
        data = response.data
        self.assertIn("version", data)
        self.assertIn("build_version", data)
        
        data["version"] = __version__

