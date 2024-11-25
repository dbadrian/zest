import uuid
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.conf import settings


class Tag(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    text = models.CharField(_("Text"), max_length=settings.TAG_MAX_CHARS, unique=True, blank=False, null=False)

    def __str__(self):  # pragma: no cover
        return f"Tag[{self.text}]"

    class Meta:
        ordering = ["text"]
        verbose_name = _("Tag")
        verbose_name_plural = _("Tags")
