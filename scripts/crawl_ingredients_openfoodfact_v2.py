from collections import defaultdict
import argparse

import json
import time
import urllib.request
import tempfile
from pathlib import Path

# https://world.openfoodfacts.org/allergens.json
# https://world.openfoodfacts.org/traces.json
# https://world.openfoodfacts.org/additives.json

URLS = {
    "en": "https://us.openfoodfacts.org/ingredients/{}.json",
    "de": "https://de.openfoodfacts.org/ingredients/{}.json",
    "it": "https://it.openfoodfacts.org/ingredients/{}.json",
    "fr": "https://fr.openfoodfacts.org/ingredients/{}.json",
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
    for i in range(1, 100):
        url = base_url.format(i)
        print(f"> Crawling {url}")
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
            meta[key] = {
                "known": entry.pop("known", None),
                "products": entry.pop("products", None),
                "same_as": entry.pop("sameAs", None),
            }
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
    out = folder.joinpath(f"{name}_known.json")
    with open(out, "w") as f:
        json.dump({k: v for k, v in d.items() if meta[k]["known"] == 1}, f, indent=2)

    out = folder.joinpath(f"{name}_unknown.json")
    with open(out, "w") as f:
        json.dump({k: v for k, v in d.items() if meta[k]["known"] == 0}, f, indent=2)


def drop_e_numbers(ingredients):
    """drop european food additive codes"""
    keys_to_drop = []
    for key in ingredients.keys():
        if key[3].lower() == "e" and len(key[4:]) >= 3 and key[4:7].isnumeric():
            keys_to_drop.append(key)

    for key in keys_to_drop:
        ingredients.pop(key)


def drop_false_translations(ingredients):
    """drop non translations"""
    keys_to_drop = []
    for key, lang_sections in ingredients.items():
        to_del = []
        for lang, values in lang_sections.items():
            if values["name"].lower().replace(" ", "-") == key:
                to_del.append(lang)
        for lang in to_del:
            lang_sections.pop(lang)

        if not ingredients[key]:
            # section is empty now
            keys_to_drop.append(key)

    for key in keys_to_drop:
        ingredients.pop(key)


def main(args):
    out_folder = args.folder
    out_folder.mkdir(exist_ok=True)

    for lang, url in URLS.items():
        d = download_and_decode_json_from_url(url)
        save_json(out_folder, f"raw_{lang}", d)


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
