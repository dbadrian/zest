from django.conf import settings
from rest_framework import serializers
import drf_serpy as serpy

from shared.utils.serializers import raise_validation_error
from .models import Tag


class ReadTagSerializerSerpy(serpy.Serializer):
    id = serpy.StrField()
    text = serpy.StrField()


class TagSerializer(serializers.ModelSerializer):

    text = serializers.CharField()

    class Meta:
        model = Tag
        fields = "__all__"

    def validate_text(self, value):
        if len(value) > settings.TAG_MAX_CHARS:
            raise_validation_error(
                f"Tag may not be longer than {settings.TAG_MAX_CHARS} characters."
            )
        return value

    def create(self, validated_data):
        # All tags are automatically converted to lower-case and whitespace is converted
        # to `-`
        text = validated_data["text"].lower()
        text = "-".join(text.split())

        tag = Tag.objects.filter(text=text).first()
        if tag:
            return tag

        validated_data["text"] = text
        return super().create(validated_data)

    def update(self, instance, validated_data):  # pragma: no cover
        raise NotImplementedError


class WriteRecipeTagSerializer(serializers.ModelSerializer):
    id = serializers.UUIDField()

    class Meta:
        fields = ("id",)
        model = Tag
        extra_kwargs = {"id": {"required": True}}
