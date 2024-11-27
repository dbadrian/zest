import logging
from django.conf import settings
from django.test import TestCase
from rest_framework import status

from shared.tools_utest import get_api_client, post, get, delete
from ..models import Tag

# silence django warning
logger = logging.getLogger('django.request')
logger.setLevel(logging.ERROR)

logger = logging.getLogger(__name__)

URL = "tags/"


class TagApiTest(TestCase):
    """ tags.api.TagViewSet """

    TAGS = ["tag1", "tag2", "tag3"]

    def setUp(self):
        self.tags = [Tag.objects.create(text=tag) for tag in self.TAGS]

    def test_get_all_count_check(self):
        """Total count after set-up"""
        client = get_api_client()
        response = get(client, URL)
        self.assertEqual(response.data["pagination"]["total_results"], len(self.TAGS))

    def test_post(self):
        """Valid object creation"""
        client = get_api_client()
        response = post(client, "tags/", data={"text": "test1"})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        response = get(client, URL)
        self.assertEqual(response.data["pagination"]["total_results"], len(self.TAGS) + 1)

    def test_post_duplicate(self):
        """Duplicate creation"""
        client = get_api_client()
        response = post(client, URL, data={"text": "tag1"})
        _id = response.data["id"]
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        response = post(client, URL, data={"text": "tag1      "})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(_id, response.data["id"])  # same as above
        response = post(client, URL, data={"text": "           tag1      "})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(_id, response.data["id"])  # same as above


    def test_post_too_long(self):
        """Tag too long"""
        client = get_api_client()
        response = post(client, URL, data={"text": "a" * (settings.TAG_MAX_CHARS + 1)})
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_post_whitespace_conversion(self):
        """Whitespace to `-` conversion """
        client = get_api_client()
        response = post(client, URL, data={"text": "  tag  with whitespc ! "})
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["text"], "tag-with-whitespc-!")

    def test_delete_prohibitied(self):
        """Deleting is prohibited (not found, cause the route doesn't exists"""
        client = get_api_client()
        response = delete(client, URL, self.tags[0].id)
        self.assertIn(response.status_code, (status.HTTP_405_METHOD_NOT_ALLOWED, status.HTTP_404_NOT_FOUND))
