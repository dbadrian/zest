import json
import argparse
import asyncio
from pathlib import Path

from app.recipes.gemini import create_recipe_from_file


def convert_sets(obj):
    if isinstance(obj, dict):
        return {k: convert_sets(v) for k, v in obj.items()}
    elif isinstance(obj, set):
        return list(obj)
    elif isinstance(obj, list):
        return [convert_sets(i) for i in obj]
    return obj

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", type=Path, required=True)
    parser.add_argument("--output-folder", type=Path, required=True)
    args = parser.parse_args()
    
    
    assert args.output_folder.exists() and args.output_folder.is_dir()
    assert args.file.exists() and args.file.is_file()
    
    outfile = args.output_folder.joinpath(f"{args.file.name}.json")
    if outfile.exists() and outfile.is_file():
        print("already processed...skipping")
        exit()
    
    
    try:
        ret = asyncio.run(create_recipe_from_file(args.file))
    except Exception as e:
        print(e, "error occurred")
        log = args.output_folder.joinpath("failed")
        with open(log, "a") as f:
            f.write(f"{e} ??? {str(args.file)}\n")
        exit(1)
        
    js = ret.model_dump()
    
    
    with open(outfile, "w") as f:
        json.dump(js, f, indent=2, default=convert_sets)
