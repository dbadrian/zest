import cProfile
import json

# from tqdm import tqdm
# import pandas as pd
import time
from foods.models import *
from foods.serializers import *

from recipes.models import *
from recipes.serializers import *
from recipes.serializers.category import *
from recipes.serializers.ingredient import *


from recipes.serializers.instruction import (
    ReadInstructionSerializerSerpy,
    WriteInstructionSerializer,
)
from recipes.serializers.recipe import ReadRecipeSerializerSerpy
from units.models import *
from units.serializers import *


# import sprofile; sprofile.run()

models_to_profile = {
    # Food: [
    #     {"serializer": WriteFoodSerializer},
    #     {
    #         "serializer": ReadFoodSerializer,
    #         # "qs_op": lambda x: x.prefetch_related("synonyms"),
    #     },
    #     {"serializer": ReadFoodSerializerSerpy},
    #     {"serializer": UseFoodSerializer},
    #     {"serializer": UseFoodSerializerSerpy},
    # ],
    # FoodNameSynonyms: [
    #     {"serializer": FoodSynonymSerializer},
    #     {"serializer": ReadFoodSynonymSerializer},
    #     {"serializer": ReadFoodSynonymSerializerSerpy},
    # ],
    FoodNameSynonyms: [
        {"serializer": FoodSynonymSerializer, "ctx": {"search": "hack"}},
        {"serializer": ReadFoodSynonymSerializer, "ctx": {"search": "hack"}},
        {"serializer": ReadFoodSynonymSerializerSerpy, "ctx": {"search": "hack"}},
    ],
    # Unit: [
    #     {"serializer": UnitSerializer},
    #     {"serializer": ReadUnitSerializer},
    #     {"serializer": ReadUnitSerializerSerpy},
    #     {"serializer": UseUnitSerializer},
    # ],
    # RecipeCategory: [
    #     {"serializer": ReadRecipeCategorySerializer},
    #     {"serializer": ReadRecipeCategorySerializerSerpy},
    # ],
    # Ingredient: [
    #     {"serializer": ReadIngredientSerializer},
    #     {"serializer": ReadIngredientSerializerSerpy},
    # ],
    # IngredientGroup: [
    #     {"serializer": ReadIngredientGroupSerializer},
    #     {"serializer": ReadIngredientGroupSerializerSerpy},
    #     {"serializer": WriteIngredientGroupSerializer},
    # ],
    # Instruction: [
    #     {"serializer": ReadInstructionSerializerSerpy},
    #     {"serializer": WriteInstructionSerializer},
    # ],
    # InstructionGroup: [
    #     {"serializer": ReadInstructionGroupSerializerSerpy},
    #     {"serializer": WriteInstructionGroupSerializer},
    # ],
    Recipe: [
        # {"serializer": WriteRecipeSerializer},
        {"serializer": ReadRecipeSerializer},
        {
            "serializer": ReadRecipeSerializerSerpy,
            "prefetch": [
                "tags",
                "categories",
                "instruction_groups",
                "instruction_groups__instructions",
                "ingredient_groups",
                "ingredient_groups__ingredients",
                "ingredient_groups__ingredients__unit",
                "ingredient_groups__ingredients__food",
            ],
        },
    ],
}


def profile_objs(objs, serializer, ctx):
    for o in objs:
        # serializer(o).data
        serializer(o, context=ctx).data


def profile_configuration(obj_type, spec):
    collection_objects = obj_type.objects.all()
    if spec.get("prefetch", None) is not None:
        collection_objects = collection_objects.prefetch_related(*spec["prefetch"])
    if (qs_op := spec.get("qs_op", None)) is not None:
        collection_objects = qs_op(collection_objects)

    print(
        f"Profiling {collection_objects.count()} objects of type `{obj_type.__name__}` with {spec['serializer'].__name__}.."
    )

    # with cProfile.Profile() as pr:
    start = time.time()
    serializer = spec["serializer"]
    profile_objs(collection_objects, serializer, spec["ctx"] if "ctx" in spec else {})
    end = time.time()
    return {"total": end - start}


def run():
    stats = {}
    for obj_type, specs in models_to_profile.items():
        obj_t = obj_type.__name__
        stats[obj_t] = {}
        for spec in specs:
            stats[obj_t][spec["serializer"].__name__] = profile_configuration(
                obj_type, spec
            )

    with open(f"prof/prof_{time.strftime('%Y%m%d_%H%M%S')}.json", "w") as f:
        json.dump(stats, f, indent=2)


# import sprofile; sprofile.run()
