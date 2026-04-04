import asyncio
import json
from argparse import ArgumentParser
from pathlib import Path
from getpass import getpass

import aiohttp


LOGIN_URL = "https://zest.dbadrian.com/api/v1/auth/login"
RECIPE_URL = "https://zest.dbadrian.com/api/v1/recipes/"


async def login(session: aiohttp.ClientSession, username: str, password: str) -> str:
    payload = {
        "username": username,
        "password": password,
    }

    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }

    async with session.post(LOGIN_URL, data=payload, headers=headers) as resp:
        if resp.status != 200:
            text = await resp.text()
            raise RuntimeError(f"Login failed ({resp.status}): {text}")

        data = await resp.json()

        # Adjust depending on API response
        token = data.get("access_token") or data.get("token")
        if not token:
            raise RuntimeError("No access token in response")

        return token


async def send_recipe(session, token: str, recipe_str: str, filename: str):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    try:
        async with session.post(RECIPE_URL, data=recipe_str, headers=headers) as resp:
            text = await resp.text()
            if 200 <= resp.status < 300:
                return filename, True, resp.status, text
            else:
                return filename, False, resp.status, text
    except Exception as e:
        return filename, False, None, str(e)


async def main_async(json_files, username, password):
    async with aiohttp.ClientSession() as session:
        token = await login(session, username, password)
        print("✅ Login successful")

        tasks = [
            send_recipe(session, token, content, filename)
            for filename, content in json_files
        ]

        results = await asyncio.gather(*tasks)

        print("\n=== RESULTS ===")
        success = 0
        failure = 0

        for filename, ok, status, msg in results:
            if ok:
                print(f"[SUCCESS] {filename} (status={status})")
                success += 1
            else:
                print(f"[FAIL]    {filename} (status={status}) -> {msg}")
                failure += 1

        print("\nSummary:")
        print(f"  Success: {success}")
        print(f"  Failed:  {failure}")


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--username", required=True)

    args = parser.parse_args()

    assert args.input.exists() and args.input.is_dir(), "Input must be a directory"

    password = getpass("Password: ")

    # Load and validate JSON files (keep as string)
    json_files = []
    for path in args.input.glob("*.json"):
        try:
            content = path.read_text(encoding="utf-8")

            # Validate JSON without keeping parsed version
            json.loads(content)

            json_files.append((path.name, content))
        except json.JSONDecodeError as e:
            print(f"[INVALID JSON] {path.name}: {e}")
        except Exception as e:
            print(f"[ERROR] {path.name}: {e}")

    if not json_files:
        print("No valid JSON files found.")
        exit(1)

    asyncio.run(main_async(json_files, args.username, password))