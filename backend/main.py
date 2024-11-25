#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
# Loosely based on the Shiv tutorial

import os
from pathlib import Path
import sys
import json
from pprint import PrettyPrinter
import argparse

import django
import gunicorn.app.wsgiapp as wsgi

BASE_DIR = Path(__file__).resolve().parent
stderr_pp = PrettyPrinter(indent=4, stream=sys.stderr)


def load_env_file(p_env_file: Path = None) -> None:
    ENV_FILE = BASE_DIR.joinpath("env.json") if p_env_file is None else p_env_file
    if ENV_FILE.exists():
        print(f"Loading ENV_FILE from: {ENV_FILE}")
        with open(ENV_FILE) as f:
            env_file = json.load(f)
            stderr_pp.pprint(env_file)
            os.environ.update(env_file)
    else:
        raise RuntimeError("No environment file found aborting.")


def production(args, extra) -> None:
    # cf. https://shiv.readthedocs.io/en/latest/django.html
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "zest.settings.production")
    django.setup()

    # This is just a simple way to supply args to gunicorn
    sys.argv = [
        ".",
        "--config",
        str(BASE_DIR.joinpath("config", "gunicorn", "prod.py")),
    ]

    wsgi.run()


def dev(args, extra) -> None:
    # cf. https://shiv.readthedocs.io/en/latest/django.html
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "zest.settings.dev")
    django.setup()

    # This is just a simple way to supply args to gunicorn
    sys.argv = [".", "--config", str(BASE_DIR.joinpath("config", "gunicorn", "dev.py"))]

    wsgi.run()


def manage(args, extra) -> None:
    from django.core.management import execute_from_command_line

    print(args.args, extra, file=sys.stderr)
    execute_from_command_line(["."] + args.args + extra)


FUNCTION_MAP = {
    "manage": manage,
    "production": production,
    "dev": dev,
}


def main() -> None:

    parser = argparse.ArgumentParser(description="Zest")
    parser.add_argument("--env", type=Path, help="Path to `env.json`.")
    # parser.add_argument('command', choices=FUNCTION_MAP.keys())

    subparsers = parser.add_subparsers(dest="command", help="Mode to run")
    parser_manage = subparsers.add_parser("manage")
    parser_manage.add_argument("args", type=str, nargs="+")

    parser_production = subparsers.add_parser("production")
    parser_dev = subparsers.add_parser("dev")

    args, extra = parser.parse_known_args()

    load_env_file(args.env)

    # # run the respective mode
    FUNCTION_MAP[args.command](args, extra)

    # # load_env_file()
    # # if len(sys.argv) > 1:
    # #     try:
    # #         EXECUTE[sys.argv[1]]()
    # #     except KeyError:
    # #         print(f"Error: Unknown mode `{sys.argv[1]}` defined. Allowed are: [{', '.join(EXECUTE.keys())}]")
    # # else:
    # #     print(f"Error: No mode defined. Allowed are: [{', '.join(EXECUTE.keys())}]")


if __name__ == "__main__":
    main()
