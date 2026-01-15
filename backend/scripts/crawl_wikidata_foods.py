#!/bin/python
import argparse
from collections import defaultdict
import copy
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
INGREDIENT_QUERY_URL = (
    "https://query.wikidata.org/bigdata/namespace/wdq/sparql?format=json&query={}"
)

PROP_OPENFOODFACT_CATEGORY = "P1821"
PROP_OPENFOODFACT_INGREDIENT = "P5930"
PROP_USDA = "P1978"
PROP_FOOD_INGREDIENT = "Q25403900"

SUPPORTED_LANGS = ["de", "en", "fr", "it", "es", "pt", "cs", "ja"]

HEADERS = {"User-Agent": "MyAppName/1.0 (your_email@example.com) Python requests"}


def exception_handler(request, exception):
    print("Request failed")


def crawl_wikidata():
    # get the intial list of ingredients by performing a query on the subclass "food ingredient"
    # print(INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_1)))
    with urllib.request.urlopen(
        INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_1))
    ) as req:
        ingredients_1 = json.loads(req.read())["results"]["bindings"]

    with urllib.request.urlopen(
        INGREDIENT_QUERY_URL.format(urllib.parse.quote(QUERY_2))
    ) as req:
        ingredients_2 = json.loads(req.read())["results"]["bindings"]

    reqs = []
    processed_qids = set()
    for item in ingredients_1 + ingredients_2:
        qid = item["item"]["value"].rsplit("/", 1)[1]
        if qid != PROP_FOOD_INGREDIENT and qid not in processed_qids:
            reqs.append(grequests.get(WIKIDATA_ENTRY_URL.format(qid), headers=HEADERS))
            processed_qids.add(qid)

    # reqs.append(grequests.get(WIKIDATA_ENTRY_URL.format("Q131528"), headers=HEADERS))
    # processed_qids.add("Q131528")
    wikidata_responses = []
    for resp in tqdm(grequests.imap(reqs, size=5), total=len(reqs)):
        if resp is not None:
            try:
                # should only ever be one item given how i request it...
                for (
                    k,
                    v,
                ) in resp.json()["entities"].items():
                    wikidata_responses.append(v)
            except Exception as e:
                print(e)

    return wikidata_responses


def build_fixtures(wikidata):
    food_fixtures = []
    food_synonym_fixtures = []
    duplicates = defaultdict(dict)
    for idx, entry in enumerate(wikidata):
        food_fixture = {
            "model": "FoodCandidate",
            "fields": {
                "description": None,
                # meta fields
                "wiki_id": entry["title"],
                "openfoodfacts_id": None,
                "usda_ndb_id": None,
            },
        }

        # first we build the multilingual names representation
        try:
            names_multilingual = {
                f"{lc}": entry["labels"][lc]["value"]
                for lc in SUPPORTED_LANGS
                if lc in entry["labels"]
            }
        except KeyError:
            continue

        # print(names_multilingual)

        # Check for duplicates
        keys_to_delete = []
        for lc, name in names_multilingual.items():
            fixed = True
            if name in duplicates[lc]:
                fixed = False
                if (aliases := entry["aliases"].get(lc)) is not None:
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
                duplicates[lc][names_multilingual[lc]] = entry["aliases"].get(lc)
            else:
                keys_to_delete.append(lc)

        names_multilingual = {
            k: v for k, v in names_multilingual.items() if k not in keys_to_delete
        }

        # # sadly, we also need to deal with the problem, where things
        # # clash  with the unique constraints if there is just one entry which also appears elsewhere
        # if len(names_multilingual) == 1:
        #     lc = next(iter(names_multilingual.keys()))
        #     # in this case search other languages as well
        #     for lang, entries in duplicates.items():
        #         if lang == lc:
        #             continue
        #         if names_multilingual[lc] in entries:
        #             print("found one more... ", names_multilingual[lc])
        #             keys_to_delete.append(lc)
        #             fixed = False
        #             break

        names_multilingual = {
            k: v for k, v in names_multilingual.items() if k not in keys_to_delete
        }
        if not names_multilingual:
            continue  # nothing to add...
        # names_multilingual.update({"name": None})
        # names_multilingual.update(
        #     {f"name_{lc}": None for lc in SUPPORTED_LANGS if f"name_{lc}" not in names_multilingual})

        # usda identifiers: there could be multiple listed...
        usda_nbd_ids = []
        for usda_entry in entry["claims"].pop(PROP_USDA, []):
            ndbid = usda_entry["mainsnak"]["datavalue"]["value"].lstrip("0")
            usda_nbd_ids += [str(ndbid)]
        if usda_nbd_ids:
            food_fixture["fields"].update({"usda_ndb_id": ",".join(usda_nbd_ids)})

        for lc, name in names_multilingual.items():
            if len(name) >= 128:
                print("skipping", name)
                continue
            fix_copy = copy.deepcopy(food_fixture)
            fix_copy["fields"]["id"] = len(food_fixtures) + 1
            fix_copy["fields"]["name"] = name
            fix_copy["fields"]["language"] = lc
            if lc in entry["descriptions"]:
                fix_copy["fields"]["description"] = entry["descriptions"][lc]["value"]
            food_fixtures.append(fix_copy)

        ## SYNONYMS FIXTURE
        for lc, aliases in entry["aliases"].items():
            if lc not in SUPPORTED_LANGS:
                continue

            for alias in aliases:
                if len(alias["value"]) >= 128:
                    print(alias["value"])
                    continue

                # if not isValidStartCharacter(alias["value"][0]):
                #     continue
                #
                # # prolly unncessary sanity check
                # if food_fixture["fields"]["id"] != food_fixtures[-1]["fields"]["id"]:
                #     print("misalignment of pk detected!")
                #     continue

                fix_copy = copy.deepcopy(food_fixture)
                fix_copy["fields"]["id"] = len(food_fixtures) + 1
                fix_copy["fields"]["name"] = alias["value"]
                fix_copy["fields"]["language"] = lc
                if lc in entry["descriptions"]:
                    # TODO: maybe the description will be very confusing as the term is different
                    fix_copy["fields"]["description"] = entry["descriptions"][lc][
                        "value"
                    ]
                food_fixtures.append(fix_copy)

                #
                # food_synonym_fixtures.append(
                #     {
                #         "model": "foods.foodnamesynonyms",
                #         "pk": str(uuid4()),
                #         "fields": {
                #             "food": food_fixture["pk"],
                #             "name": alias["value"],
                #             "language": lc,
                #         },
                #     }
                # )
    #
    # # filter shitty conflicting single entry food fixtures
    # conflicting_pks = []
    # conflicting_candidates = []
    # for fix in food_fixtures:
    #     fields = [v for k, v in fix["fields"].items() if k.startswith("name_")]
    #     if len(fields) == 1:
    #         conflicting_pks.append(fix["id"])
    #         conflicting_candidates.append(fields[0])
    #
    # pk_to_delete = []
    # for fix in food_fixtures:
    #     fields = [v for k, v in fix["fields"].items() if k.startswith("name_")]
    #     if len(fields) == 1:
    #         continue
    #
    #     for field in fields:
    #         try:
    #             idx = conflicting_candidates.index(field)
    #             pk_to_delete.append(conflicting_pks[idx])
    #         except:
    #             pass
    #
    # food_fixtures = [
    #     fixture for fixture in food_fixtures if fixture["id"] not in pk_to_delete
    # ]
    # food_synonym_fixtures = [
    #     fixture
    #     for fixture in food_synonym_fixtures
    #     if fixture["fields"]["food"] not in pk_to_delete
    # ]

    return food_fixtures, food_synonym_fixtures


def main(args):
    # first we get ingredients and lots of information about them from wikidata
    p_wikidata = args.folder.joinpath("wikidata.json")
    if args.force or not p_wikidata.exists():
        print("Crawling wikidata information from web...")

        wikidata = crawl_wikidata()
        print("Crawled:", len(wikidata))
        with open(args.folder.joinpath("wikidata.json"), "w") as f:
            json.dump(wikidata, f)
    else:
        print("Loading wikidata information for cached file...")
        with open(args.folder.joinpath("wikidata.json"), "r") as f:
            wikidata = json.load(f)

    food_fixtures, food_synonym_fixtures = build_fixtures(wikidata)
    print(f"Total of {len(food_fixtures)} fixtures created")
    with open(args.folder.joinpath("foods.json"), "w") as f:
        json.dump(food_fixtures, f, indent=2)
    with open(args.folder.joinpath("foods_synonyms.json"), "w") as f:
        json.dump(food_synonym_fixtures, f, indent=2)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Process OpenFoodData by crawling wikidata."
    )

    parser.add_argument(
        "--folder",
        "-f",
        type=Path,
        help="Output folder",
    )
    parser.add_argument(
        "--force", action="store_true", help="Do not load any stored files"
    )

    args = parser.parse_args()
    main(args)
