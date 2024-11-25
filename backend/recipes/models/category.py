from django.db import models
from django.utils.translation import gettext_lazy as _


class RecipeCategory(models.Model):
    """General category of a recipe."""

    name = models.CharField(_("Name"), max_length=255, blank=False)
    name_plural = models.CharField(_("Name (plural)"), max_length=255, blank=True, null=True)

    class Meta:
        verbose_name = _("Recipe Category")
        verbose_name_plural = _("Recipe Categories")

    def __str__(self):
        return self.name

    # TODO: Return name if name_plural is not set?