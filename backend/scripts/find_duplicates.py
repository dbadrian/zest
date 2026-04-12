import asyncio
import json
from getpass import getpass
import aiohttp
from difflib import SequenceMatcher

LOGIN_URL = "https://zest.dbadrian.com/api/v1/auth/login"
RECIPE_URL = "https://zest.dbadrian.com/api/v1/recipes/"

# --- Login ---
async def login(session: aiohttp.ClientSession, username: str, password: str) -> str:
    payload = {"username": username, "password": password}
    headers = {"Content-Type": "application/x-www-form-urlencoded"}

    async with session.post(LOGIN_URL, data=payload, headers=headers) as resp:
        if resp.status != 200:
            text = await resp.text()
            raise RuntimeError(f"Login failed ({resp.status}): {text}")
        data = await resp.json()
        token = data.get("access_token") or data.get("token")
        if not token:
            raise RuntimeError("No access token in response")
        return token

# --- Fetch all recipes ---
async def fetch_recipes(session, token):
    headers = {"Authorization": f"Bearer {token}"}
    async with session.get(RECIPE_URL, headers=headers) as resp:
        if resp.status != 200:
            text = await resp.text()
            raise RuntimeError(f"Failed to fetch recipes ({resp.status}): {text}")
        return await resp.json()

# --- Duplicate detection ---
def are_duplicates(r1, r2, name_threshold=0.85, ingredients_threshold=0.7):
    """Returns True if two recipes are considered duplicates."""
    try:
        name1 = r1['latest_revision']["title"].lower()
        name2 = r2['latest_revision']["title"].lower()
        name_ratio = SequenceMatcher(None, name1, name2).ratio()
        
        # ingredients1 = " ".join(r1['latest_revision']["ingredients"]).lower()
        # ingredients2 = " ".join(r2['latest_revision']["ingredients"]).lower()
        # ingredients_ratio = SequenceMatcher(None, ingredients1, ingredients2).ratio()
        
        return name_ratio >= name_threshold #and ingredients_ratio >= ingredients_threshold
    except Exception:
        return False

async def main():
    username = input("Username: ")
    password = getpass("Password: ")

    async with aiohttp.ClientSession() as session:
        token = await login(session, username, password)
        print("✅ Login successful")

        recipes = await fetch_recipes(session, token)
        recipes = recipes['results']
        print(f"Fetched {len(recipes)} recipes from database")
        
        duplicates = []
        checked = set()
        
        for i, r1 in enumerate(recipes):
            for j, r2 in enumerate(recipes):
                if i >= j:  # Avoid double checking and self-check
                    continue
                pair_key = frozenset([i, j])
                if pair_key in checked:
                    continue
                if are_duplicates(r1, r2):
                    duplicates.append((r1['latest_revision']["title"], r2['latest_revision']["title"]))
                checked.add(pair_key)

        if duplicates:
            print("\n=== DUPLICATES FOUND ===")
            for n1, n2 in duplicates:
                print(f"- {n1}  ⇄  {n2}")
            print(f"\nTotal duplicate pairs: {len(duplicates)}")
        else:
            print("\nNo duplicates found.")

if __name__ == "__main__":
    asyncio.run(main())