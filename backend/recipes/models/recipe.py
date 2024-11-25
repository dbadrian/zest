import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.contrib.auth import get_user_model
from django.conf import settings

from tags.models import Tag
from .category import RecipeCategory


class Recipe(models.Model):

    class Difficulty(models.IntegerChoices):
        DIFFICULTY_NOT_SET = 0
        DIFFICULTY_EASY = 1
        DIFFICULTY_MEDIUM = 2
        DIFFICULTY_HARD = 3

    # Unique across DB
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Shared by all recipes, across versions and languages
    recipe_id = models.UUIDField(default=uuid.uuid4, editable=False, blank=False, null=False)
    # Points to the `some` version of the current (the id field -> unique to a version)
    original_recipe_id = models.UUIDField(default=None, blank=True, null=True)
    language = models.CharField(max_length=2, choices=settings.LANGUAGES, default=settings.LANGUAGES[0])

    date_created = models.DateTimeField(
        _("Date created"), editable=False, auto_now_add=True
    )
    owner = models.ForeignKey(get_user_model(), on_delete=models.PROTECT)

    # External Meta-Data
    title = models.CharField(_("Title"), max_length=255)
    subtitle = models.CharField(_("Subtitle"), max_length=255, blank=True)
    difficulty = models.PositiveSmallIntegerField(
        _("Difficulty"), blank=False, null=False, choices=Difficulty.choices, default=Difficulty.DIFFICULTY_NOT_SET
    )
    servings = models.PositiveSmallIntegerField(_("Servings"))
    prep_time = models.PositiveSmallIntegerField(
        _("Preparation time"), blank=True, null=True
    )
    cook_time = models.PositiveSmallIntegerField(
        _("Cooking time"), blank=True, null=True
    )
    tags = models.ManyToManyField(
        Tag,
        related_name="recipes",
        blank=True,
    )

    categories = models.ManyToManyField(
        RecipeCategory,
        related_name="recipes",
        blank=True,
    )

    source_name = models.CharField(
        _("Source name"), max_length=255, blank=True, null=True
    )
    source_page = models.PositiveSmallIntegerField(
        _("Source page"), blank=True, null=True
    )
    source_url = models.URLField(_("Source URL"), blank=True, null=True)

    # Content
    owner_comment = models.TextField(_("Comment"), blank=True, null=True)

    # Permission related
    private = models.BooleanField(_("Private"), blank=False, null=False, default=True)

    class Meta:
        verbose_name = _("Recipe")
        verbose_name_plural = _("Recipes")
        ordering = ["-date_created"]
        indexes = [
            models.Index(fields=["title"]),
            models.Index(fields=["owner"]),
            models.Index(fields=["subtitle"]),
        ]

    def __str__(self):
        return self.title

    def is_up_to_date(self):
        latest_id = (
            Recipe.objects.filter(  # pylint: disable=no-member
                recipe_id=self.recipe_id, original_recipe_id__isnull=True).latest("date_created").id)

        if self.original_recipe_id is None and latest_id == self.id:
            # original recipe and this version is the most up2date
            return True
        elif (self.original_recipe_id is not None and self.original_recipe_id == latest_id):
            # translation, but points to the most recent version of the original
            return True
        else:
            return False

    def is_translation(self):
        return self.original_recipe_id is not None
