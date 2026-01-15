import json
import argparse
from pathlib import Path
from tqdm import tqdm
import asyncio

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy import select
from sqlalchemy import Enum as SQLEnum
from app.db import Base
from app.core.config import settings

from app.auth import models
from app.recipes import models


def get_class_by_classname(classname: str):
    for mapper in Base.registry.mappers:
        if mapper.class_.__name__ == classname:
            return mapper.class_
    return None


def convert_enums_for_model(model_class, data: dict):
    """
    Converts any string values in `data` to the corresponding Enum member
    if the model column is an Enum.

    Returns a new dict ready to pass to model_class(**data).
    """
    result = data.copy()
    for col_name, col in model_class.__table__.c.items():
        # Only process if the column exists in the input dict
        if col_name in data and isinstance(col.type, SQLEnum):
            enum_class = col.type.enum_class
            # Convert string to enum, leave enum as-is
            value = data[col_name]
            if value is not None and not isinstance(value, enum_class):
                try:
                    result[col_name] = enum_class(value)
                except ValueError as e:
                    raise ValueError(
                        f"Invalid value '{value}' for enum {enum_class.__name__}"
                    ) from e
    return result


async def install_fixture(data):
    engine = create_async_engine(str(settings.SQLALCHEMY_DATABASE_URI))
    async_session = async_sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )

    last_model = ""
    ModelCls = None
    async with async_session() as db:
        for model_data in tqdm(data):
            model = model_data["model"]
            if not model:
                raise RuntimeError("No model class define. Invalid fixture")

            if model != last_model:
                last_model = model
                ModelCls = get_class_by_classname(model)
                if ModelCls is None:
                    raise RuntimeError("Couldn't find model in registry")
                print("got new model, and found it as well")
            if ModelCls is not None:
                model_data["fields"] = convert_enums_for_model(
                    ModelCls, model_data["fields"]
                )
                model_instance = ModelCls(**model_data["fields"])
                try:
                    db.add(model_instance)
                except:
                    print("key already exists")

        await db.commit()
        print("installed fixtures")


if __name__ == "__main__":
    parser = argparse.ArgumentParser("Zest Fixture Installer")
    parser.add_argument(
        "--fixture",
        type=Path,
        required=True,
        help="Path to the fixture file to install",
    )

    args = parser.parse_args()

    if not args.fixture.exists():
        print("Fixture file does not exist. Terminating")
        exit(1)

    with open(args.fixture, "r") as f:
        data = json.load(f)

    asyncio.run(install_fixture(data))
