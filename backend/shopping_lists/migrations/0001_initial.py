# Generated by Django 5.1.4 on 2024-12-21 17:33

import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="ShoppingList",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                (
                    "date_created",
                    models.DateTimeField(
                        auto_now_add=True, verbose_name="Date created"
                    ),
                ),
                ("title", models.CharField(max_length=255, verbose_name="Title")),
                ("comment", models.TextField(verbose_name="Comment")),
            ],
            options={
                "verbose_name": "Shopping list",
                "verbose_name_plural": "Shopping lists",
                "ordering": ["-date_created"],
            },
        ),
        migrations.CreateModel(
            name="ShoppingListEntry",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("servings", models.PositiveSmallIntegerField(verbose_name="Servings")),
            ],
        ),
    ]
