#!/bin/python
import argparse
from collections import defaultdict
import json
from pathlib import Path
from typing import List
import urllib.request
import time
import grequests
from tqdm import tqdm
from wikidata.client import Client

wikidata_base = "https://www.wikidata.org/wiki/Special:EntityData/{}.json"
wikidata_search = "https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srsearch={}"

# all the properties relate to some food topic
food_related_props = [
    "P628", "P652", "P789", "P868", "P1034", "P1820", "P1821", "P1978", "P2371", "P2542", "P2658", "P2665", "P2759",
    "P2760", "P2904", "P2905", "P3895", "P3902", "P3904", "P4030", "P4543", "P4618", "P4637", "P4695", "P4696", "P4729",
    "P4849", "P4850", "P4851", "P4852", "P4853", "P5456", "P5930", "P6088", "P6089", "P6767", "P7971", "P8266", "P8431",
    "P8858", "P9031", "P9056", "P9057", "P9066", "P9557", "P9769", "P9840", "P9854", "P9894", "P9925", "P10172",
    "P10584", "P11217", "P11773"
]

# animal product: Q629103
# meat: Q10990
# fruit: Q3314483
# vegetable: Q11004
# spice: Q42527
# food powder: Q56274178
# food ingredient: Q25403900
# food: Q2095
# ingredient: Q10675206
# dish: Q746549
# tea: Q6097
# herbal tea: Q379932
# cheese: Q10943
# nut: Q3320037
# nut: Q11009

PRIMARY_FOOD_SUBCLASSES = ['Q25403900', 'Q2095', 'Q10675206', 'Q56274178']
EXTA_FOOD_SUBCLASSES = [
    "Q629103", "Q10990", "Q3314483", "Q11004", "Q42527", "Q746549", "Q6097", "Q379932", "Q10943", "Q3320037", "Q11009"
]

# instance of: P31
SUBCLASS_OF = "P279"


def exception_handler(request, exception):
    print("Request failed")


def crawl_wikidata(qids: List[str]):
    reqs = [grequests.get(wikidata_base.format(qid)) for qid in qids]

    wikidata_responses = {}
    for resp in tqdm(grequests.imap(reqs, size=20), total=len(reqs)):
        if resp is not None:
            try:
                # should only ever be one item given how i request it...
                for k, v, in resp.json()['entities'].items():
                    for offkey in qids[k]:
                        # wikidata_responses.append((k, list(wikidata_qids[k]), v))
                        wikidata_responses[offkey] = v

            except Exception as e:
                print(e)

    print("Crawled:", len(wikidata_responses), "/", len(qids))
    return wikidata_responses


def main(args):
    wikidata_qids = defaultdict(set)
    entries_without_wikidata_qids = []
    with open(args.input, 'r') as f:
        raw = json.load(f)
        for k, entry in raw.items():
            e = next(iter(entry.values()))
            if (links := e.pop("sameAs", None)) is not None:
                wikidata_qids[links[0].split("wikidata.org/wiki/")[1]].add(k)
            else:
                entries_without_wikidata_qids.append(k)

    # # crawl those where we know what they are...
    # wikidata_responses = crawl_wikidata(wikidata_qids)
    # with open(args.out, 'w') as f:
    #     json.dump(wikidata_responses, f)

    K_TOP_HITS = 50  # how many top hits to query and search
    for k in tqdm(entries_without_wikidata_qids):
        for lc, entry in raw[k].items():
            print(lc, entry)
            with urllib.request.urlopen(wikidata_search.format(urllib.parse.quote(entry["name"]))) as req:
                res = json.loads(req.read())
                print("Found", len(res["query"]["search"]))
                if not res["query"]["search"]:
                    continue

                reqs = [
                    grequests.get(wikidata_base.format(entry["title"])) for entry in res["query"]["search"][:K_TOP_HITS]
                ]

                candidates = defaultdict(int)
                for resp in tqdm(grequests.imap(reqs, size=min(20, len(reqs))), total=len(reqs)):
                    if resp is not None:
                        try:
                            # should only ever be one item given how i request it...
                            for (wiki_id, data) in resp.json()['entities'].items():

                                # first we check if is subclass of food/food ingredient
                                if (subclass_claims := data["claims"].get(SUBCLASS_OF)) is not None:
                                    for scl in subclass_claims:
                                        if scl["mainsnak"]["datavalue"]["value"]["id"] in PRIMARY_FOOD_SUBCLASSES:
                                            candidates[wiki_id] += 50
                                        if scl["mainsnak"]["datavalue"]["value"]["id"] in EXTA_FOOD_SUBCLASSES:
                                            candidates[wiki_id] += 10
                                        # for ref in scl["references"]:
                                        #     for prop, data in ref.items():
                                        #         if prop in FOOD_SUBCLASSES:
                                        #             candidates[wiki_id] += 10

                                # now we count the amount of claims that are food related
                                for claim_id, value in data["claims"].items():
                                    if claim_id in food_related_props:
                                        candidates[wiki_id] += 1

                        except Exception as e:
                            print(e)
                if candidates:
                    print(
                        f"top candidate for {k}: https://www.wikidata.org/wiki/{max(candidates, key=candidates.get)} with score of {max(candidates.values())}"
                    )
                else:
                    print("No candidate found.")


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Process OpenFoodData by crawling wikidata.")
    parser.add_argument(
        "--folder",
        "-f",
        type=Path,
        help="Folder to save processed json files to",
    )
    parser.add_argument(
        "--input",
        "-i",
        type=Path,
        help="Raw OpenFoodFact Input Files",
    )

    parser.add_argument(
        "--out",
        "-o",
        type=Path,
        help="Wikidata data",
    )

    args = parser.parse_args()
    main(args)
