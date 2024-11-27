from collections import defaultdict
import argparse
import json
from enum import Enum
import uuid
from pathlib import Path

SKIP_LANGS = {"fr", "it"}

# Used for deterministic pk generation
NAMESPACE_DNS_BYTES = b"k\xa7\xb8\x10\x9d\xad\x11\xd1\x80\xb4\x00\xc0O\xd40\xc8"
NAMESPACE_UUID = uuid.UUID(bytes=NAMESPACE_DNS_BYTES)


class Action(Enum):
    DELETE = 1


OVERRIDE = {
    "en:vanilla-seeds": {
        "de": {
            "name": "Vanillesamen (?)",
        },
    },
    "fr:compote-de-pommes": Action.DELETE,  # not easy to resolve automatically
    "en:canola": Action.DELETE,  # rapeseed also present, one is enough
    "fr:eau-minerale-naturelle-gazeifiee": Action.DELETE,  # alternative present
    "en:amino-acid": Action.DELETE,  # plural (more common?) also present
    "en:oligofructose": Action.DELETE,  # alternative present
    "en:fromage-blanc": {
        "de": {
            "url": "https://de.openfoodfacts.org/zutat/Frischk%C3%A4se",
            "name": "Fromage Blanc (~Frischk\u00e4se)",
        }
    },
    "en:calf-rennet": {
        "de": {
            "url": "https://de.openfoodfacts.org/zutat/lab",
            "name": "Kalbslab"
        }
    },
    "en:sorghum": {
        "de": {
            "url": "https://de.openfoodfacts.org/zutat/hirse",
            "name": "Sorghumhirse",
        }
    },
    "en:semi-skimmed-milk": {
        "de": {
            "url": "https://de.openfoodfacts.org/zutat/fettarme-milch",
            "name": "Fettarme Milch (ca. 1.8% fat)",
        }
    },
    "en:paprika": {
        "de": {
            "name": "Paprika (Pulver)",
            "url": "https://de.openfoodfacts.org/zutat/paprika",
        }
    },
    "en:bamboo-shoot-fiber": Action.DELETE,  # who cares
    "de:Steinpilz": Action.DELETE,
    "en:whipping-cream": Action.DELETE,
    "en:buttermilk-solids": Action.DELETE,
    "en:hydrolised-pea-protein": Action.DELETE,
    "en:salt": {
        "de": {
            "name": "Salz",
        }
    },
    "en:salmon": {
        "de": {
            "name": "Lachs",
        }
    },
    "en:kelp": {
        "de": {
            "name": "Kelp",
        }
    },
    "en:corn-molasses": {
        "de": {
            "name": "Molasse (Mais)",
        },
    },
    "en:cider-vinegar": {
        "de": {
            "name": "Apfelweinessig"
        },
    },
    "en:corn-syrup-solids": {
        "de": {
            "name": "Maissiruppulver",
        },
    },
    "en:white-rice-flour": {
        "de": {
            "name": "Reismehl (weiss)",
            "url": "https://de.openfoodfacts.org/zutat/reismehl",
        },
    },
    "en:oatmeal": Action.DELETE,
    "en:natural-sweet-lime-flavouring": {
        "de": {
            "name": "Nat\u00fcrliches Limettenaroma (suess)",
            "url": "https://de.openfoodfacts.org/zutat/Nat%C3%BCrliches%20Limettenaroma",
        },
    },
    "en:oily-fish": {
        "de": {
            "name": "Fettfisch",
            "url": "https://de.openfoodfacts.org/zutat/Fisch%C3%B6l",
        },
    },
    "en:radish": {
        "jp": {
            "name": "\u4E8C\u5341\u65E5\u5927\u6839",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E3%83%80%E3%82%A4%E3%82%B3%E3%83%B3",
        },
    },
    "en:coriander-powder": {
        "jp": {
            "name":
                "\u30b3\u30ea\u30a2\u30f3\u30c0\u30fc\u7C89",
            "url":
                "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E3%82%B3%E3%83%AA%E3%82%A2%E3%83%B3%E3%83%80%E3%83%BC",
        }
    },
    "en:green-chili-pepper": {
        "jp": {
            "name": "\u9752\u5510\u8F9B\u5B50",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E5%94%90%E8%BE%9B%E5%AD%90",
        },
    },
    "en:red-chili-pepper": {
        "jp": {
            "name": "\u8D64\u5510\u8F9B\u5B50",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E5%94%90%E8%BE%9B%E5%AD%90",
        }
    },
    "en:herbs-and-spices": {
        "jp": {
            "name": "\u30cf\u30fc\u30d6\u3068\u9999\u8F9B\u6599",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E3%83%8F%E3%83%BC%E3%83%96",
        }
    },
    "en:chia": Action.DELETE,
    "en:pork": {
        "jp": {
            "name": "\u8c5a",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E8%B1%9A%E8%82%89",
        }
    },
    "en:brown-sugar": {
        "jp": {
            "name": "\u9ED2\u7802\u7CD6",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E7%B2%97%E7%B3%96",
        },
    },
    "en:spice": {
        "jp": {
            "name": "\u9999\u8F9B\u6599",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E8%AA%BF%E5%91%B3%E6%96%99",
        }
    },
    "en:skimmed-milk": {
        "jp": {
            "name": "\u8131\u8102\u4E73",
        }
    },
    "en:poultry-broth": {
        "jp": {
            "name": "\u9CE5\u6C41",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E9%B6%8F%E6%B1%81",
        }
    },
    "en:palm-kernel-oil": {
        "jp": {
            "name": "\u30D1\u30FC\u30E0\u6838\u6CB9",
            "url": "https://jp.openfoodfacts.org/\u539f\u6750\u6599/%E3%83%91%E3%83%BC%E3%83%A0%E6%B2%B9",
        }
    },
    "en:palm-oil-and-fat": Action.DELETE,
    "en:palm-fat": Action.DELETE,
    "en:palm-kernel-oil-and-fat": Action.DELETE,
    "en:beef": {
        "es": {
            "name": "Carne de res",
            "url": "https://es.openfoodfacts.org/ingrediente/carne-de-vaca",
        }
    },
    "en:chicken-egg-yolk": {
        "es": {
            "name": "Yema de huevo de gallina"
        },
        "en": {
            "name": "chicken egg yolk"
        },
    },
    "en:alaskan-pollock-fillet": {
        "es": {
            "name": "Filete de abadejo de Alaska",
            "url": "https://es.openfoodfacts.org/ingrediente/abadejo-de-alaska",
        },
    },
    "en:crushed-tomato": {
        "es": {
            "name": "Tomate triturado",
            "url": "https://es.openfoodfacts.org/ingrediente/pure-de-tomate",
        }
    },
    "en:alcohol-vinegar": Action.DELETE,
    "en:cream": {
        "es": {
            "name": "Crema",
        },
    },
    "en:chicken-egg-yolk-powder": {
        "es": {
            "name": "Yema de huevo de gallina en polvo",
            "url": "https://es.openfoodfacts.org/ingrediente/yema-de-huevo-en-polvo",
        }
    },
    "en:pineapple-juice-from-concentrate": Action.DELETE,
    "en:yeast-powder": {
        "es": {
            "name": "Levadura en polvo (yeast)",
            "url": "https://es.openfoodfacts.org/ingrediente/levadura-en-polvo",
        }
    },
    "en:pork-skin": {
        "es": {
            "name": "Piel de cerdo",
        },
    },
    "en:lemon-zest": {
        "es": {
            "name": "Lim\u00F3n rallado",
        }
    },
    "en:atlantic-cod": {
        "es": {
            "name": "Bacalao atlántico",
            "url": "https://es.openfoodfacts.org/ingrediente/bacalao",
        }
    },
    "en:light-cream": {
        "es": {
            "name": "Crema ligera",
            "url": "https://es.openfoodfacts.org/ingrediente/nata-ligera",
        }
    },
    "en:skimmed-soft-white-cheese": Action.DELETE,
    "en:marsh-mallow": Action.DELETE,
    "en:cooked-lardoons": Action.DELETE,
    "en:beef-meat-extract": Action.DELETE,
    "en:belgian-endive": Action.DELETE,
    "en:carbonated-natural-mineral-water": {
        "es": {
            "name": "Agua mineral carbonatada (natural)"
        }
    }
}


def load_json_files(fn_files):
    combined = {}
    for file in fn_files:
        with open(file, "r") as f:
            combined.update(json.load(f))
    return combined


def convert_files_to_fixture(data):
    fixture = []
    for en_key, food in data.items():
        # In order to garantuee that we can more easily update the database
        # in the future, we generate "deterministic" uuids for each entry
        # based on the en_key (which is unique)
        pk = uuid.uuid5(NAMESPACE_UUID, en_key)

        tmp = {"model": "foods.food", "pk": str(pk), "fields": {"default_unit": None}}
        for lang, val in food.items():
            if lang not in SKIP_LANGS:
                if len(val["name"]) > 2 and val["name"][2] == ":":
                    val["name"] = val["name"][3:]
                    # handles special cases, where a different langauge is simply referenced,
                    # but we need to remove the lang code that leads the name in these instances
                tmp["fields"][f"name_{lang}"] = val["name"]

        # check if entry still has content after language filtering
        if len(tmp["fields"]) > len(["default_unit"]):
            fixture.append(tmp)
    return fixture


def save_fixture(fixture, path):
    with open(path, "w") as f:
        json.dump(fixture, f, indent=2)


def find_doubles(fixture):
    dirty = False
    doubles = defaultdict(set)
    for food in fixture:
        for key, value in food["fields"].items():
            if key in {"default_unit"}:
                continue
            if value not in doubles[key]:
                doubles[key].add(value)
            else:
                print("Double key found:", key, value)
                dirty = True
    return dirty


def apply_fixes(data):
    keys_to_delete = []
    for key, lang_sections in data.items():
        if key in OVERRIDE:
            value = OVERRIDE[key]
            if value == Action.DELETE:
                keys_to_delete.append(key)
            else:
                lang_sections.update(value)

    for key in keys_to_delete:
        data.pop(key, None)


def main(args):
    data = load_json_files(args.files)
    apply_fixes(data)
    print(f"Found {len(data)} food entries after filtering!")
    fixture = convert_files_to_fixture(data)
    if not find_doubles(fixture):
        save_fixture(fixture, args.out)
    else:
        print("found duplicates, not creating fixture output")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument(
        "--files",
        nargs="+",
        type=str,
        help="Json dicts (from openfood fact crawler) to convert to a Foods-fixture.",
    )
    parser.add_argument(
        "--out",
        "-o",
        type=Path,
        help="File to save processed json file to",
    )

    args = parser.parse_args()
    main(args)
