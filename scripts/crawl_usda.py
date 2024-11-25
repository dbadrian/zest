#!/bin/python
import argparse
from collections import defaultdict
import json
from pathlib import Path
from uuid import uuid4

from tqdm import tqdm

# Various Properties we are interested in
PROP_OPENFOODFACT_CATEGORY = "P1821"
PROP_OPENFOODFACT_INGREDIENT = "P5930"
PROP_USDA = "P1978"

SUPPORTED_LANGS = ["de", "en", "fr", "it", "es", "pt", "cs", "ja"]


def isValidStartCharacter(c):
    return c not in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '(', ')', '!', ':', '/', '[', ']', '{', '}']


def main(args):
    # load the usda resources
    usda_raw = {}
    for path in tqdm(args.usda, desc="Loading USDA Json"):
        with open(path, 'r') as f:
            usda_raw.update(json.load(f))

    ndbid2entry = defaultdict(list)
    for k in ['SRLegacyFoods', 'FoundationFoods']:
        for entry in tqdm(usda_raw[k], desc=f"Processing {k}"):
            ndbid = str(entry['ndbNumber'])
            ndbid2entry[ndbid].append(entry)

    print("Loading Wikidata")
    with open(args.input, 'r') as f:
        wikidata_raw = json.load(f)

    print("Loading OpenFoodFacts")
    with open(args.off, 'r') as f:
        off_raw = json.load(f)

    # k: the Q number of wiki data
    # v: [ USDA numbers ..]
    foods = []
    for openfoodfact_key, in raw.items():
        wiki_data = wikidata_raw[openfoodfact_key]
        food = {
            'openfoodfacts': openfoodfact_key,
            "wiki_id": wiki_data["title"],
            "labels": wiki_data["labels"],  # multilingual names
            "aliases": wiki_data["aliases"],  # multilingual synonmys
            "description": wiki_data["descriptions"],  # multilingual descriptions
            "usda": []
        }

        usda_entries = wiki_data["claims"].pop(PROP_USDA, [])
        for entry in usda_entries:
            try:
                ndbid = entry["mainsnak"]["datavalue"]["value"].lstrip("0")
                # print(ndbid)
                if ndbid not in ndbid2entry:
                    print("could not ndbid")

                food["usda"].append(ndbid2entry[ndbid])
            except KeyError:
                print(wiki_data["title"], entry)

        foods.append(food)

    # with open(args.out, 'w') as f:
    #     json.dump(foods, f, indent=2)

    nutrients = []
    for food in foods:
        usda = food["usda"]
        for entry in usda:
            for subentry in entry:
                for nutrient in subentry["foodNutrients"]:
                    nutrients.append({
                        "id": nutrient["nutrient"]["id"],
                        "name": nutrient["nutrient"]["name"],
                        "unitName": nutrient["nutrient"].get("unitName", None),
                    })

    # with open(str(args.out + ".nutrients.json", 'w') as f:
    #     json.dump(nutrients, f, indent=2)

    # generate nutrient fixtures

    # load the django units fixture which we will use later
    # to convert the string to the appropriate id
    units = {}
    with open(args.units, 'r') as f:
        units_raw = json.load(f)
        for unit in units_raw:
            if (abv := unit["fields"].get("abbreviation")) is not None:
                units[abv] = unit["pk"]

    nutrients_fixtures = []
    for nutrient in nutrients:
        nutrients_fixtures.append({
            "model": "foods.Nutrient",
            "pk": nutrient["id"],  # we duplicate the official usda one...
            "fields": {
                "name": nutrient["name"],  # we duplicate the official usda one...
                "unit": units[nutrient["unitName"]]
                        if nutrient["unitName"] is not None else None  # we duplicate the official usda one...
            }
        })

    # with open(str(args.out) + ".nutrients_fixtures.json", 'w') as f:
    #     json.dump(nutrients_fixtures, f, indent=2)

    # generate food, synonomys, and nutrients fixtures
    food_fixtures = []
    food_synonym_fixtures = []
    measure_nutrient_fixtures = []

    duplicates = defaultdict(set)
    synomyms = {}
    for food in foods:
        food_fixture = {
            "model": "foods.food",
            "pk": str(uuid4()),
            "fields": {
                "wiki_id": food["wiki_id"],
                "openfoodfacts_key": ",".join(food["openfoodfacts"]) if food["openfoodfacts"] else None,
                "usda_nbd_ids": None,
            }
        }
        names_multilinguagal = {
            f"name_{lc}": food["labels"][lc]["value"] for lc in SUPPORTED_LANGS if lc in food["labels"]
        }

        # check if english key is not starting with alpha character -> prolly we dont care since its likea chemical compound
        if "name_en" in names_multilinguagal and not isValidStartCharacter(names_multilinguagal["name_en"][0]):
            continue

        # if food["openfoodfacts"] and food["openfoodfacts"][0][:2] == "en":
        #     if "name_en" in names_multilinguagal:
        #         if food["openfoodfacts"][0][3:].replace("-", " ") != names_multilinguagal["name_en"]:
        #             print(food["openfoodfacts"][0][3:].replace("-", " "), "---", names_multilinguagal["name_en"])
        #     else:
        #         print("meep")
        #     names_multilinguagal["name_en"] = food["openfoodfacts"][0][3:].replace("-", " ")

        keys_to_delete = []
        for lc, name in names_multilinguagal.items():
            if name in duplicates[lc]:
                print("ohshit....", name)

                if (aliases := food["aliases"].get(lc.split("_")[1])) is not None:
                    names_multilinguagal[lc] = name + f" ({aliases[0]['value']})"
                    print("new name: ", names_multilinguagal[lc])
                else:
                    keys_to_delete.append(lc)

            duplicates[lc].add(names_multilinguagal[lc])

        for k in keys_to_delete:
            names_multilinguagal.pop(k)
        if not names_multilinguagal:
            continue  # nothing to add...

        description_multilinguagal = {
            f"description_{lc}": food["description"][lc]["value"] for lc in SUPPORTED_LANGS if lc in food["description"]
        }
        food_fixture["fields"].update(names_multilinguagal)
        food_fixture["fields"].update(description_multilinguagal)

        usda_nbd_ids = []
        for entry in food["usda"]:
            usda_nbd_ids += [str(se['ndbNumber']) for se in entry]
        if usda_nbd_ids:
            food_fixture["fields"].update({"usda_nbd_ids": ",".join(usda_nbd_ids)})

        food_fixtures.append(food_fixture)

        for lc, aliases in food["aliases"].items():
            if lc in SUPPORTED_LANGS:
                for alias in aliases:
                    if len(alias["value"]) >= 150:
                        continue

                    if not isValidStartCharacter(alias["value"][0]):
                        continue

                    # for some reason we didnt that the fixture???
                    if food_fixture["pk"] != food_fixtures[-1]["pk"]:
                        continue

                    food_synonym_fixtures.append({
                        "model": "foods.foodnamesynonyms",
                        "pk": str(uuid4()),
                        "fields": {
                            "food": food_fixture["pk"],
                            "name": alias["value"],
                            "language": lc,
                        }
                    })

    with open(args.out.joinpath("foods.json"), 'w') as f:
        json.dump(food_fixtures, f, indent=2)
    with open(args.out.joinpath("foods_synonyms.json"), 'w') as f:
        json.dump(food_synonym_fixtures, f, indent=2)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process OpenFoodData by crawling wikidata.")

    parser.add_argument(
        "--units",
        type=Path,
        help="Path to units fixture",
        required=True,
    )

    parser.add_argument(
        "--input",
        "-i",
        type=Path,
        help="Raw Wikidata Input File",
        required=True,
    )

    parser.add_argument(
        "--usda",
        type=Path,
        nargs="+",
        help="USDA json files",
        required=True,
    )

    parser.add_argument(
        "--off",
        type=Path,
        help="Merged and filtered OpenFoodFact json file",
        required=True,
    )

    parser.add_argument(
        "--out",
        "-o",
        type=Path,
        help="Folder to output fixtures and all",
        required=True,
    )

    args = parser.parse_args()
    main(args)
