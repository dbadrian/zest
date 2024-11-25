from collections import defaultdict
import argparse

import json
import time
import urllib.request
import tempfile
from pathlib import Path

from tqdm import tqdm

# https://world.openfoodfacts.org/allergens.json
# https://world.openfoodfacts.org/traces.json
# https://world.openfoodfacts.org/additives.json

URLS = {
    "en": "https://us.openfoodfacts.org/ingredients/{}.json",
    "de": "https://de.openfoodfacts.org/ingredients/{}.json",
    # "it": "https://it.openfoodfacts.org/ingredients/{}.json",
    # "fr": "https://fr.openfoodfacts.org/ingredients/{}.json",
    # "cz": "https://cz.openfoodfacts.org/ingredients/{}.json",
    # "jp": "https://jp.openfoodfacts.org/ingredients/{}.json",
    # "es": "https://es.openfoodfacts.org/ingredients/{}.json",
    # "pt": "https://pt.openfoodfacts.org/ingredients/{}.json",
}


def openurl(url, max_retries=10):
    tries = 0
    while True:
        try:
            with urllib.request.urlopen(url) as req:
                return json.loads(req.read())
        except urllib.error.HTTPError:
            tries += 1
            if tries == max_retries:
                exit()
            print("HTTP Error 504: Gateway Time-out")
            print("Gonna sleep a few secs and retry")
            time.sleep(5)


def download_and_decode_json_from_url(base_url):
    """
    Download and decode json from url
    """
    d = []
    for i in tqdm(range(1, 70), desc=f"Crawling {base_url[8:10]}"):
        url = base_url.format(i)
        # print(f"> Crawling {url}")
        tmp = openurl(url)
        if tmp["count"] == 0:
            break
        else:
            d = d + tmp["tags"]
    return d


def merge_ingredients(raw_dicts):
    ingredients = defaultdict(dict)
    meta = {}
    for lang, raw in raw_dicts.items():
        for entry in raw:
            key = entry.pop("id")
            # meta[key] = {
            #     "known": entry.pop("known", None),
            #     "products": entry.pop("products", None),
            #     "same_as": entry.pop("sameAs", None),
            # }
            ingredients[key][lang] = entry
    return ingredients, meta


def filter_single_occurances(ingredients):
    single_ingredients = defaultdict(dict)
    for key, entries_by_lang in ingredients.items():
        if len(entries_by_lang) < 2:
            single_ingredients[key] = ingredients[key]

    # drop all those keys now
    for key in single_ingredients.keys():
        ingredients.pop(key)

    return ingredients, single_ingredients


def save_json(folder, name, d):
    out = folder.joinpath(f"{name}.json")
    with open(out, "w") as f:
        json.dump(d, f, indent=2)


def save_filtered(folder, name, d, meta):

    known = {}
    unknown = {}

    for k, v in d.items():
        if next(iter(v.values()))["known"] == 1:
            known[k] = v
        else:
            unknown[k] = v

    with open(folder.joinpath(f"{name}_known.json"), "w") as f:
        json.dump(known, f, indent=2)

    with open(folder.joinpath(f"{name}_unknown.json"), "w") as f:
        json.dump(unknown, f, indent=2)


def drop_e_numbers(ingredients):
    """drop european food additive codes"""
    keys_to_drop = []
    for key in ingredients.keys():
        if len(key[4:]) >= 3 and key[3].lower() == "e" and key[4:7].isnumeric():
            keys_to_drop.append(key)

    for key in keys_to_drop:
        ingredients.pop(key)


def drop_false_translations(ingredients):
    """drop non translations: that is were the name is the same as the key incluing th
    the prepended `LC:` """
    keys_to_drop = []
    for key, lang_sections in ingredients.items():
        to_del = []
        for lang, values in lang_sections.items():
            if values["name"].lower().replace(
                    " ", "-") == key or values["name"][:3] in ["en:", "fr:", "de:", "es:", "it:", "jp:", "pt:"]:
                to_del.append(lang)
        for lang in to_del:
            lang_sections.pop(lang)

        if not ingredients[key]:
            # section is empty now
            keys_to_drop.append(key)

    for key in keys_to_drop:
        ingredients.pop(key)


def filter_alt_lang_duplicates(ingredients):
    # some ingredients are just duplicate of already other know ones.
    # typically same key just with different language identifier
    # normally "en:" is the primary key for really relevant things
    keys_to_drop = []
    for key, data in ingredients.items():
        lc, identifier = key.split(":", 1)
        if lc != "en" and f"en:{identifier}" in ingredients:
            keys_to_drop.append(key)

    for k in keys_to_drop:
        ingredients.pop(k)


def main(args):
    out_folder = args.folder
    out_folder.mkdir(exist_ok=True)
    raw_dicts = {lang: download_and_decode_json_from_url(url) for lang, url in URLS.items()}
    print("Merging")
    ingredients, meta = merge_ingredients(raw_dicts)

    print("Filtering")
    if not args.keep_e_numbers:
        drop_e_numbers(ingredients)

    drop_false_translations(ingredients)
    # ingredients, single_ingredients = filter_single_occurances(ingredients)
    filter_alt_lang_duplicates(ingredients)

    print("Saving")
    save_filtered(out_folder, "merged", ingredients, meta)
    # save_filtered(out_folder, "single_occurances", single_ingredients, meta)
    save_json(out_folder, "meta", meta)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument(
        "--folder",
        "-f",
        type=Path,
        help="Folder to save processed json files to",
    )
    parser.add_argument("--keep-e-numbers", "-ken", action="store_true")
    args = parser.parse_args()
    main(args)
