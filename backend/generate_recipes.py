#!/usr/bin/evn python3


import argparse
from random import randint

import django
from tqdm import tqdm
from faker import Faker

django.setup()

from users.models import CustomUser
from units.models import Unit
from foods.models import Food
from recipes.models import Recipe, RecipeCategory, InstructionGroup, Instruction, IngredientGroup, Ingredient


fake = Faker()

languages = ["en", "de", "fr", "it"]
potential_owners = CustomUser.objects.all()
units = Unit.objects.all()
foods = Food.objects.all()
categories = list(RecipeCategory.objects.all())

def generate_random_recipes(n: int):
    recipes = []
    for _ in tqdm(range(n)):
        recipe = Recipe.objects.create(
            title=fake.text(max_nb_chars=50),
            subtitle=fake.text(max_nb_chars=50),
            difficulty=fake.random_int(min=0, max=3),
            servings=fake.random_int(min=1, max=10),
            prep_time=fake.random_int(min=0, max=360),
            cook_time=fake.random_int(min=0, max=360),
            owner=fake.random_element(potential_owners),
            language=fake.random_element(languages),
            source_name=fake.text(max_nb_chars=50),
            source_page=fake.random_int(min=1, max=100),
            private=fake.boolean(chance_of_getting_true=30),
            owner_comment=fake.text(max_nb_chars=100),
        )
            # categories=fake.random_elements(elements=categories, unique=True),
        recipe.categories.add(*fake.random_elements(elements=categories, unique=True))
        
        # generate instructions
        for i in range(fake.random_int(min=0, max=5)):
            ingr = InstructionGroup.objects.create(
                recipe=recipe,
                name=fake.text(max_nb_chars=50),
                position=i
            )
            for j in range(fake.random_int(min=1, max=10)):
                Instruction.objects.create(
                    group=ingr,
                    position=j,
                    text=fake.text(max_nb_chars=100),
                )
                
        # generate ingredients
        for i in range(fake.random_int(min=1, max=5)):
            ingr = IngredientGroup.objects.create(
                recipe=recipe,
                name=fake.text(max_nb_chars=50),
                position=i
            )
            for j in range(fake.random_int(min=1, max=10)):
                amount = randint(1,1000)/10.0
                Ingredient.objects.create(
                    group=ingr,
                    position=j,
                    amount=amount,
                    amount_max=(amount+randint(1,1000)/10.0) if fake.boolean(chance_of_getting_true=50) else None,
                    unit=fake.random_element(units),
                    food=fake.random_element(foods),
                    details=fake.text(max_nb_chars=40) if fake.boolean(chance_of_getting_true=50) else None,
                )
        
        recipe.save()
        
        # recipe.save()
        
    Recipe.objects.bulk_create(recipes)
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate random recipes")
    parser.add_argument("n", type=int, help="Number of recipes to generate")
    args = parser.parse_args()
    
    generate_random_recipes(n=args.n)