from django.contrib.auth import get_user_model
from django.test import TestCase


class CustomUserTests(TestCase):
    """users.models.CustomUser"""

    def test_create_user(self):
        """Test regular (non-staff) user creation of custom model."""
        User = get_user_model()
        user = User.objects.create_user(username="recipeuser", email="user@ilikecooking.com", password="testpass123")

        self.assertEqual(user.username, "recipeuser")
        self.assertEqual(user.email, "user@ilikecooking.com")
        self.assertTrue(user.is_active)
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_create_superuser(self):
        """Test superuser creation of custom model."""
        User = get_user_model()
        admin_user = User.objects.create_superuser(
            username="mightyadmin",
            email="mightyadmin@recipemaster.com",
            password="testpass123",
        )
        self.assertEqual(admin_user.username, "mightyadmin")
        self.assertEqual(admin_user.email, "mightyadmin@recipemaster.com")
        self.assertTrue(admin_user.is_active)
        self.assertTrue(admin_user.is_staff)
        self.assertTrue(admin_user.is_superuser)
class AuthAPITest(TestCase):
    """Test the authentication API endpoints."""

    def test_create_user(self):
        """Test creating a new user. We except registration to be disabled!"""
        payload = {
            "username": "recipeuser",
            "email": "asd@asd.de",
            "password1": "testpass123",
            "password2": "testpass123",
        }
        res = self.client.post("/api/v1/auth/registration/", payload)
        self.assertEqual(res.status_code, 403)