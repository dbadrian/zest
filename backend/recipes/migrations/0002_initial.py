# Generated by Django 5.1.4 on 2024-12-21 17:33

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("recipes", "0001_initial"),
        ("tags", "0001_initial"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AddField(
            model_name="recipe",
            name="owner",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT, to=settings.AUTH_USER_MODEL
            ),
        ),
        migrations.AddField(
            model_name="recipe",
            name="tags",
            field=models.ManyToManyField(
                blank=True, related_name="recipes", to="tags.tag"
            ),
        ),
        migrations.AddField(
            model_name="instructiongroup",
            name="recipe",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="instruction_groups",
                to="recipes.recipe",
            ),
        ),
        migrations.AddField(
            model_name="ingredientgroup",
            name="recipe",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name="ingredient_groups",
                to="recipes.recipe",
            ),
        ),
        migrations.AddField(
            model_name="recipe",
            name="categories",
            field=models.ManyToManyField(
                blank=True, related_name="recipes", to="recipes.recipecategory"
            ),
        ),
        migrations.AddIndex(
            model_name="recipe",
            index=models.Index(fields=["title"], name="recipes_rec_title_9ebae8_idx"),
        ),
        migrations.AddIndex(
            model_name="recipe",
            index=models.Index(fields=["owner"], name="recipes_rec_owner_i_b10f49_idx"),
        ),
        migrations.AddIndex(
            model_name="recipe",
            index=models.Index(
                fields=["subtitle"], name="recipes_rec_subtitl_1d7adf_idx"
            ),
        ),
    ]