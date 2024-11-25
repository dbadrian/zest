from django.utils.translation import gettext_lazy as _
from django.db import models


class InstructionGroup(models.Model):
    """Groups several Instructions together. A recipe can
    have multipe instruction groups
    """

    name = models.CharField(max_length=150)
    recipe = models.ForeignKey("Recipe", related_name="instruction_groups", on_delete=models.CASCADE)
    position = models.PositiveSmallIntegerField(blank=True, null=True)

    class Meta:
        ordering = ["position"]
        verbose_name = _("InstructionGroup")
        verbose_name_plural = _("InstructionGroups")

    def __str__(self):
        return self.name


class Instruction(models.Model):
    text = models.TextField()
    group = models.ForeignKey(InstructionGroup, related_name="instructions", on_delete=models.CASCADE)
    position = models.PositiveSmallIntegerField(blank=True, null=True)

    class Meta:
        ordering = ["position"]
        verbose_name = _("Instruction")
        verbose_name_plural = _("Instructions")

    def __str__(self):
        return self.preview

    @property
    def preview(self):
        return _("Instruction: {preview} ...").format(preview=self.text[:50])
