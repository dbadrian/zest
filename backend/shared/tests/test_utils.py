from django.test import TestCase
from django.db import IntegrityError, transaction

from ..utils.generic import contains_keys, to_list


class SharedUtilsTest(TestCase):
    """shared.utils"""

    def test_contains_keys_helper(self):
        a = {1: 2, "a": "?", "k233": 323, (2, "a", "223z"): "kk"}
        self.assertTrue(contains_keys(a, (1, "a", "k233", (2, "a", "223z"))))
        self.assertTrue(contains_keys(a, ("a", 1, (2, "a", "223z"), "k233")))
        self.assertTrue(contains_keys(a, ["a", 1, (2, "a", "223z"), "k233"]))
        self.assertTrue(contains_keys(a, ["a", (2, "a", "223z"), "k233"]))
        self.assertTrue(contains_keys(a, []))
        self.assertFalse(contains_keys(a, ["a", "isnotinthere", "k233"]))

    def test_to_list(self):
        val = to_list(231)
        self.assertTrue(isinstance(val, list))
        self.assertEqual(val, [231])

        val = to_list([231])
        self.assertTrue(isinstance(val, list))
        self.assertEqual(val, [231])

        val = to_list("asdsadsa")
        self.assertTrue(isinstance(val, list))
        self.assertEqual(val, ["asdsadsa"])

        val = to_list([213, 213, 21321, 12])
        self.assertTrue(isinstance(val, list))
        self.assertEqual(val, [213, 213, 21321, 12])

        val = to_list((213, 213, 21321, 12))
        self.assertTrue(isinstance(val, list))
        self.assertEqual(val, [213, 213, 21321, 12])

        # Order cant be garantueed -> count equal
        val = to_list({213, 22, 21321, 12})
        self.assertTrue(isinstance(val, list))
        self.assertCountEqual(val, [213, 22, 21321, 12])