from typing import Annotated
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

# from . import auth
from app.core.config import settings, SHOW_DOCS_IN_ENVS
from app.db import lifespan
from app.auth.auth import router as auth_router
from app.recipes.routes import router as recipe_router
from app.version import __version__

app_config = {}
if settings.ENVIRONMENT not in SHOW_DOCS_IN_ENVS:
    app_config["openapi_url"] = None  # set url for docs as null


app = FastAPI(**app_config, lifespan=lifespan)
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(recipe_router, prefix=settings.API_V1_STR)

BASE_DIR = Path(__file__)
static_dir = BASE_DIR.joinpath("..", "..", "static").resolve().absolute()
app.mount("/static", StaticFiles(directory=static_dir), name="static")


@app.get("/api/v1/info")
async def info() -> dict:
    return {"version": __version__}
