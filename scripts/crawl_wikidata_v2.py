#!/bin/python
import argparse
from collections import defaultdict
import json
from pathlib import Path
from typing import List
import urllib.request
import urllib
import time
from uuid import uuid4
import grequests
from tqdm import tqdm
from wikidata.client import Client

QUERY_1 = """
SELECT DISTINCT ?item ?itemLabel WHERE {
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE]". }
  {
    SELECT DISTINCT ?item WHERE {
      {
        ?item wdt:P366* wd:Q2095.
      }
      UNION
      {
        ?item wdt:P279*/wdt:P31* wd:Q25403900.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q25403900.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q13163235.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q207123.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q10943.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q42527.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q56274178.
      }
      # get rid of brands/trademark products
      MINUS {
        ?item p:P31 ?statement0.
        ?statement0 (ps:P31/(wdt:P279*)) wd:Q167270.
      }
      MINUS {
        ?item p:P31 ?statement0.
        ?statement0 (ps:P31/(wdt:P279*)) wd:Q16323605.
      }
    }
  }
}
"""

QUERY_2 = """
SELECT DISTINCT ?item ?itemLabel WHERE {
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE]". }
  {
    SELECT DISTINCT ?item WHERE {
      {
        ?item wdt:P31*/wdt:P279* wd:Q3314483.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q6097;
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q31839438;
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q60449655;
      }
      UNION
      {
        ?item wdt:P366* wd:Q60449655.
      }
      UNION
      {
        ?item wdt:P366* wd:Q898745.
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q7493597;
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q3687258;
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q13030962; # convenience food
      }
      UNION
      {
        ?item wdt:P31*/wdt:P279* wd:Q8195619; # human food
      }
      # get rid of brands/trademark products
      MINUS {
        ?item p:P31 ?statement0.
        ?statement0 (ps:P31/(wdt:P279*)) wd:Q167270.
      }
      MINUS {
        ?item p:P31 ?statement0.
        ?statement0 (ps:P31/(wdt:P279*)) wd:Q16323605.
      }
      MINUS { # gets rid of italian wines which cause too many conflcits right now
        ?item p:P279 ?statement0.
        ?statement0 (ps:P279/(wdt:P279*)) wd:Q1125341.
      }
    }
  }
}
"""

# https://www.wikidata.org/wiki/Q3687258 preserved food
# Q8195619

# SELECT ?food
# WHERE
# {
#   ?food wdt:P31/wdt:P279* wd:Q25403900.
# }

WIKIDATA_ENTRY_URL = "https://www.wikidata.org/wiki/Special:EntityData/{}.json"
INGREDIENT_QUERY_URL = "https://query.wikidata.org/bigdata/namespace/wdq/sparql?format=json&query={}"

PROP_OPENFOODFACT_CATEGORY = "P1821"
PROP_OPENFOODFACT_INGREDIENT = "P5930"
PROP_USDA = "P1978"
PROP_FOOD_INGREDIENT = "Q25403900"

SUPPORTED_LANGS = ["de", "en", "fr", "it", "es", "pt", "cs", "ja"]


def exception_handler(request, exception):
    print("Request failed")


def crawl_wikidata():
    # get the intial list of ingredients by performing a query on the subclass "food ingredient"
    print(INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_1)))
    with urllib.request.urlopen(INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_1))) as req:
        ingredients_1 = json.loads(req.read())["results"]["bindings"]

    with urllib.request.urlopen(INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_2))) as req:
        ingredients_2 = json.loads(req.read())["results"]["bindings"]

    reqs = []
    processed_qids = set()
    for item in ingredients_1 + ingredients_2:
        qid = item["item"]["value"].rsplit("/", 1)[1]
        if qid != PROP_FOOD_INGREDIENT and qid not in processed_qids:
            reqs.append(grequests.get(WIKIDATA_ENTRY_URL.format(qid)))
            processed_qids.add(qid)

    wikidata_responses = []
    for resp in tqdm(grequests.imap(reqs, size=50), total=len(reqs)):
        if resp is not None:
            try:
                # should only ever be one item given how i request it...
                for k, v, in resp.json()['entities'].items():
                    wikidata_responses.append(v)
            except Exception as e:
                print(e)

    return wikidata_responses


# def query_usda(usda_path: Path, wikidata_entries):
#     # load the usda resources
#     usda_raw = {}
#     for path in tqdm(usda_path, desc="Loading USDA Json"):
#         with open(path, 'r') as f:
#             usda_raw.update(json.load(f))

#     ndbid2entry = defaultdict(list)
#     for k in ['SRLegacyFoods', 'FoundationFoods']:
#         for entry in tqdm(usda_raw[k], desc=f"Processing {k}"):
#             ndbid = str(entry['ndbNumber'])
#             ndbid2entry[ndbid].append(entry)

#     qid2nutrients = {}
#     for entry in wikidata_entries:
#         # entry is a results dict...
#         for entry in usda_entries:


def load_units_from_fixture(path):
    units = {}
    with open(path, 'r') as f:
        units_raw = json.load(f)
        for unit in units_raw:
            if (abv := unit["fields"].get("abbreviation")) is not None:
                units[abv] = unit["pk"]


def build_fixtures(wikidata):
    food_fixtures = []
    food_synonym_fixtures = []
    duplicates = defaultdict(dict)
    for entry in wikidata:
        food_fixture = {
            "model": "foods.food",
            "pk": str(uuid4()),
            "fields": {
                # base fields
                "wiki_id": entry["title"],
                "openfoodfacts_key": None,
                "usda_nbd_ids": None,
            }
        }

        # first we build the multilingual names representation
        try:
            names_multilingual = {
                f"name_{lc}": entry["labels"][lc]["value"] for lc in SUPPORTED_LANGS if lc in entry["labels"]
            }
        except KeyError:
            continue

        # Check for duplicates
        keys_to_delete = []
        for lc, name in names_multilingual.items():
            fixed = True
            if name in duplicates[lc]:
                fixed = False
                if (aliases := entry["aliases"].get(lc.split("_")[1])) is not None:
                    for alias in aliases:
                        candidate = name + f" ({aliases[0]['value']})"
                        if candidate not in duplicates[lc]:
                            fixed = True
                            names_multilingual[lc] = name + f" ({aliases[0]['value']})"
                            break
                    # print("new name: ", names_multilinguagal[lc])
                else:
                    print("Can't resolve....", lc, name)
                    keys_to_delete.append(lc)

            if fixed:
                duplicates[lc][names_multilingual[lc]] = entry["aliases"].get(lc.split("_")[1])
            else:
                keys_to_delete.append(lc)

        names_multilingual = {k: v for k, v in names_multilingual.items() if k not in keys_to_delete}

        # sadly, we also need to deal with the problem, where things
        # clash  with the unique constraints if there is just one entry which also appears elsewhere
        if len(names_multilingual) == 1:
            lc = next(iter(names_multilingual.keys()))
            # in this case search other languages as well
            for lang, entries in duplicates.items():
                if lang == lc:
                    continue
                if names_multilingual[lc] in entries:
                    print("found one more... ", names_multilingual[lc])
                    keys_to_delete.append(lc)
                    fixed = False
                    break

        names_multilingual = {k: v for k, v in names_multilingual.items() if k not in keys_to_delete}

        names_multilingual = {k: v for k, v in names_multilingual.items() if k not in keys_to_delete}
        if not names_multilingual:
            continue  # nothing to add...
        # names_multilingual.update({"name": None})
        # names_multilingual.update(
        #     {f"name_{lc}": None for lc in SUPPORTED_LANGS if f"name_{lc}" not in names_multilingual})

        food_fixture["fields"].update(names_multilingual)

        # descriptions: again build multilingual
        if "descriptions" in entry:
            description_multilinguagal = {
                f"description_{lc}": entry["descriptions"][lc]["value"]
                for lc in SUPPORTED_LANGS
                if lc in entry["descriptions"]
            }
            food_fixture["fields"].update(description_multilinguagal)

        # usda identifiers: there could be multiple listed...
        usda_nbd_ids = []
        for usda_entry in entry["claims"].pop(PROP_USDA, []):
            ndbid = usda_entry["mainsnak"]["datavalue"]["value"].lstrip("0")
            usda_nbd_ids += [str(ndbid)]
        if usda_nbd_ids:
            food_fixture["fields"].update({"usda_nbd_ids": ",".join(usda_nbd_ids)})

        food_fixtures.append(food_fixture)

        ## SYNONYMS FIXTURE
        for lc, aliases in entry["aliases"].items():
            if lc not in SUPPORTED_LANGS:
                continue

            for alias in aliases:
                if len(alias["value"]) >= 150:
                    continue

                # if not isValidStartCharacter(alias["value"][0]):
                #     continue

                # prolly unncessary sanity check
                if food_fixture["pk"] != food_fixtures[-1]["pk"]:
                    print("misalignment of pk detected!")
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

    # filter shitty conflicting single entry food fixtures
    conflicting_pks = []
    conflicting_candidates = []
    for fix in food_fixtures:
        fields = [v for k, v in fix["fields"].items() if k.startswith("name_")]
        if len(fields) == 1:
            conflicting_pks.append(fix["pk"])
            conflicting_candidates.append(fields[0])

    pk_to_delete = []
    for fix in food_fixtures:
        fields = [v for k, v in fix["fields"].items() if k.startswith("name_")]
        if len(fields) == 1:
            continue

        for field in fields:
            try:
                idx = conflicting_candidates.index(field)
                pk_to_delete.append(conflicting_pks[idx])
            except:
                pass

    food_fixtures = [fixture for fixture in food_fixtures if fixture["pk"] not in pk_to_delete]
    food_synonym_fixtures = [
        fixture for fixture in food_synonym_fixtures if fixture["fields"]["food"] not in pk_to_delete
    ]

    return food_fixtures, food_synonym_fixtures


def main(args):
    # first we get ingredients and lots of information about them from wikidata
    p_wikidata = args.folder.joinpath("wikidata.json")
    if args.force or not p_wikidata.exists():
        print("Crawling wikidata information from web...")

        wikidata = crawl_wikidata()
        print("Crawled:", len(wikidata))
        with open(args.folder.joinpath("wikidata.json"), 'w') as f:
            json.dump(wikidata, f)
    else:
        print("Loading wikidata information for cached file...")
        with open(args.folder.joinpath("wikidata.json"), 'r') as f:
            wikidata = json.load(f)

    # next we extract the relevant information and crawl some info from the USDA nutrition database where applicable
    # query_usda(args.usda, wikidata)

    # units = load_units_from_fixture(args.units)

    food_fixtures, food_synonym_fixtures = build_fixtures(wikidata)
    print(f"Total of {len(food_fixtures)} fixtures created")
    with open(args.folder.joinpath("foods.json"), 'w') as f:
        json.dump(food_fixtures, f, indent=2)
    with open(args.folder.joinpath("foods_synonyms.json"), 'w') as f:
        json.dump(food_synonym_fixtures, f, indent=2)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process OpenFoodData by crawling wikidata.")

    parser.add_argument(
        "--folder",
        "-f",
        type=Path,
        help="Output folder",
    )

    parser.add_argument(
        "--units",
        type=Path,
        help="Path to units fixture",
        required=True,
    )

    parser.add_argument(
        "--usda",
        type=Path,
        nargs="+",
        help="USDA json files",
        required=True,
    )

    parser.add_argument("--force", action="store_true", help="Do not load any stored files")

    args = parser.parse_args()
    main(args)
