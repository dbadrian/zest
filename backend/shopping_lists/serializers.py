import logging

from rest_framework import serializers
from rest_framework.exceptions import ValidationError

from shared.serializers import (
    NormalizedDecimalFieldMixin,
    NonNullModelSerializerMixin,
)
from .models import ShoppingList, ShoppingListEntry

logger = logging.getLogger(__name__)


class ShoppingListEntrySerializer(NonNullModelSerializerMixin, NormalizedDecimalFieldMixin,
                                  serializers.ModelSerializer):

    class Meta:
        model = ShoppingListEntry
        fields = ("id", "recipe", "servings")
        extra_kwargs = {
            "id": {
                "required": False
            },
        }


class ShoppingListSerializer(serializers.ModelSerializer):
    entries = ShoppingListEntrySerializer(many=True)

    # recipes = serializers.SerializerMethodField()

    class Meta:
        model = ShoppingList
        fields = ("id", "owner", "date_created", "title", "comment", "entries")

        extra_kwargs = {
            "id": {
                "read_only": True,
                "required": False
            },
            "date_created": {
                "read_only": True
            },
            "owner": {
                "required": False
            },
        }

    def create(self, validated_data):
        entries = validated_data.pop("entries")
        validated_data["owner"] = self.context["request"].user
        sl = ShoppingList.objects.create(**validated_data)  # pylint: disable=no-member
        for entry in entries:
            ShoppingListEntry.objects.create(  # pylint: disable=no-member
                shopping_list=sl, **entry)
        return sl

    def update(self, instance, validated_data):
        instance.title = validated_data.get("title", instance.title)
        instance.comment = validated_data.get("comment", instance.comment)
        instance.save()

        entries_to_keep = set()
        if (entries := validated_data.get("entries", None)):
            for entry in entries:
                if (eid := entry.get("id", None)):
                    # Check if object with this id exists (it should..)
                    # and then update the servings (cause thats the only thing of interest)
                    try:
                        obj = instance.entries.get(id=eid,)
                        entries_to_keep.add(eid)
                        obj.servings = entry.get("servings", obj.servings)
                        obj.save()
                    except ShoppingListEntry.DoesNotExist:  # pylint: disable=no-member
                        raise ValidationError(
                            {"message": "ShoppingListEntry submitted, but no object with that id exists."})
                else:
                    obj = ShoppingListEntry.objects.create(  # pylint: disable=no-member
                        shopping_list=instance, **entry)
                    entries_to_keep.add(obj.id)

        # Delete all those items no longer listed
        to_delete = ShoppingListEntry.objects.filter(  # pylint: disable=no-member
            id__in=instance.entries.all()).exclude(id__in=entries_to_keep)
        to_delete.delete()

        return instance
