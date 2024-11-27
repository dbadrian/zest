import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.contrib.auth import get_user_model

from recipes.models import Recipe


class ShoppingList(models.Model):
    # Unique across DB
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(get_user_model(), on_delete=models.PROTECT)
    date_created = models.DateTimeField(
        _("Date created"), editable=False, auto_now_add=True
    )

    # Meta-Data
    title = models.CharField(_("Title"), max_length=255)
    comment = models.TextField(_("Comment"))

    # Content

    class Meta:
        verbose_name = _("Shopping list")
        verbose_name_plural = _("Shopping lists")
        ordering = ["-date_created"]

    def __str__(self):
        return self.title


class ShoppingListEntry(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    shopping_list = models.ForeignKey(ShoppingList, related_name="entries", on_delete=models.CASCADE)

    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE)
    servings = models.PositiveSmallIntegerField(_("Servings"), blank=False, null=False)
