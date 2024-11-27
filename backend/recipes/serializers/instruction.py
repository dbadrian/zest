import logging

from rest_framework import serializers
import drf_serpy as serpy

from ..models import Instruction, InstructionGroup
from ..utils import update_nested_positional_group

logger = logging.getLogger(__name__)


class ReadInstructionSerializerSerpy(serpy.Serializer):
    text = serpy.StrField()


class WriteInstructionSerializer(serializers.ModelSerializer):

    class Meta:
        model = Instruction
        fields = ("text",)
        extra_kwargs = {
            # "id": {"read_only": False, "required": False},
        }


class ReadInstructionGroupSerializerSerpy(serpy.Serializer):
    name = serpy.StrField()
    instructions = ReadInstructionSerializerSerpy(many=True)
    position = serpy.IntField()


class WriteInstructionGroupSerializer(serializers.ModelSerializer):
    instructions = WriteInstructionSerializer(many=True)

    class Meta:
        model = InstructionGroup
        fields = ("name", "instructions", "position")
        extra_kwargs = {
            # "id": {"read_only": False, "required": False},
        }

    def create(self, validated_data):
        logger.debug(f"Creating new InsGr from validated_data={validated_data}")
        if "id" in validated_data:
            logger.debug("`id` submitted for object creation. This is not allowed.")
            raise serializers.ValidationError(
                "`id` submitted for object creation. This is not allowed."
            )

        instructions_data = validated_data.pop("instructions")
        group = InstructionGroup.objects.create(**validated_data)

        for new_pos, instruction in enumerate(instructions_data, start=1):
            if "id" in instruction:
                logger.debug("`id` submitted for object creation. This is not allowed.")
                raise serializers.ValidationError(
                    "`id` submitted for object creation. This is not allowed."
                )
            instruction["position"] = new_pos
            instruction["group"] = group
            Instruction.objects.create(**instruction)

        return group

    def update(self, instance, validated_data):
        logger.debug(f"Updating InsGr from validated_data={validated_data}")
        # Update group first
        instance.name = validated_data.get("name", instance.name)
        instance.save()

        # Update inner elements
        instructions_update = validated_data.pop("instructions")
        update_nested_positional_group(
            instance,
            instructions_update,
            Instruction,
            "id",
            "position",
        )

        return instance
