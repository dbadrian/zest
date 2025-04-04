# Generated by Django 5.1.4 on 2024-12-21 17:33

import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="FavoriteRecipe",
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
                ("recipe_id", models.UUIDField()),
            ],
            options={
                "verbose_name": "Favorite Recipe",
            },
        ),
    ]
