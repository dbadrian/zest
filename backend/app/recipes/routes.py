from typing import List
from datetime import datetime, UTC
import json
from pathlib import Path

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    UploadFile,
    status,
    Request,
)
from pydantic import ValidationError
from sqlalchemy.orm import joinedload, selectinload
from sqlalchemy.orm import Session
from sqlalchemy import Select, exc, insert, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.auth import get_current_user
from app.auth.models import USER_ID_T, User
from app.core.config import APP_DIR
from app.core.depends import (
    DateFilterParams,
    SortParams,
    apply_date_filter,
    apply_sorting,
    date_filter_dependency,
    sort_dependency,
)
from app.core.pagination import (
    PaginatedResponse,
    PaginationMeta,
    PaginationParams,
    get_pagination_params,
    paginate,
)
from app.db import get_db
from app.recipes.associations import user_favorite_recipes
from app.recipes.gemini import create_recipe_from_file
from .models import (
    FoodCandidate,
    Recipe,
    RecipeRevision,
    Unit,
    InstructionGroup,
    IngredientGroup,
    Ingredient,
    RecipeCategories,
)  # SQLAlchemy models
from .schemas import (
    FoodCandidateRead,
    RecipeListView,
    RecipeRead,
    RecipeReadHeader,
    RecipeCreateUpdate,
    RecipeReadHistory,
    RecipeRevisionCreateUpdate,
    RecipeRevisionRead,
    RecipeCategoryRead,
    UnitRead,
    InstructionGroupIO,
    IngredientGroupRead,
)
from .search import get_meilisearch_service

router = APIRouter(prefix="/recipes", tags=["recipes"])


async def _create_recipe_revision(
    recipe_data: RecipeCreateUpdate, recipe: Recipe, db: AsyncSession
) -> RecipeRevision:
    content = recipe_data.content

    # Validate that all category IDs exist
    result = await db.execute(
        select(RecipeCategories).where(RecipeCategories.id.in_(content.categories))
    )
    categories = result.scalars().all()
    if len(categories) != len(content.categories):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more category IDs do not exist",
        )

    # Validate that all unit IDs exist
    unit_ids = [
        ing.unit_id
        for group in content.ingredient_groups
        for ing in group.ingredients
        if ing.unit_id is not None
    ]
    result = await db.execute(select(Unit).where(Unit.id.in_(unit_ids)))
    units = result.scalars().all()
    if len(units) != len(set(unit_ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more unit IDs do not exist",
        )

    # Create the initial RecipeRevision
    revision = RecipeRevision(
        # recipe_id=recipe.id,
        recipe=recipe,
        title=content.title,
        subtitle=content.subtitle,
        difficulty=content.difficulty,
        servings=content.servings,
        prep_time=content.prep_time,
        cook_time=content.cook_time,
        source_name=content.source_name,
        source_page=content.source_page,
        source_url=content.source_url,
        owner_comment=content.owner_comment,
        categories=categories,
        created_at=datetime.now(UTC),
    )

    # --- Ingredient groups and ingredients ---
    revision.ingredient_groups = [
        IngredientGroup(
            name=group.name,
            position=i,
            ingredients=[
                Ingredient(
                    comment=ing.comment,
                    food=ing.food,
                    amount_min=ing.amount_min,
                    amount_max=ing.amount_max,
                    unit_id=ing.unit_id,
                    position=j,
                )
                for j, ing in enumerate(group.ingredients)
            ],
        )
        for i, group in enumerate(content.ingredient_groups)
    ]

    # --- Instruction groups ---
    revision.instruction_groups = [
        InstructionGroup(
            name=group.name,
            instructions=group.instructions,
            position=i,
        )
        for i, group in enumerate(content.instruction_groups)
    ]

    return revision


async def _create_recipe(
    recipe_data: RecipeCreateUpdate,
    db: AsyncSession,
    owner_id: USER_ID_T,
) -> Recipe:
    # Create the Recipe (meta record)
    recipe = Recipe(
        owner_id=owner_id,
        is_draft=recipe_data.is_draft,
        is_private=recipe_data.is_private,
        language=recipe_data.language,
        created_at=datetime.now(UTC),
    )
    revision = await _create_recipe_revision(recipe_data, recipe, db)

    recipe.latest_revision = revision

    # --- Add to session and flush for IDs ---
    db.add(recipe)
    # IDs for recipe, revision, ingredient groups, ingredients are generated
    await db.flush()
    await db.refresh(revision)
    # Eagerly load all relationships for Pydantic conversion
    result = await db.execute(
        select(RecipeRevision)
        .where(RecipeRevision.id == revision.id)
        .options(
            selectinload(RecipeRevision.categories),
            selectinload(RecipeRevision.ingredient_groups)
            .selectinload(IngredientGroup.ingredients)
            .selectinload(Ingredient.unit),
            selectinload(RecipeRevision.instruction_groups),
            selectinload(RecipeRevision.recipe),
        )
    )
    revision = result.scalar_one()

    return recipe


async def _update_recipe(
    recipe: Recipe, recipe_data: RecipeCreateUpdate, db: AsyncSession
):
    revision = await _create_recipe_revision(recipe_data, recipe, db)

    recipe.latest_revision = revision
    recipe.is_draft = recipe_data.is_draft
    recipe.is_private = recipe_data.is_private
    recipe.language = recipe.language

    # --- Add to session and flush for IDs ---
    db.add(recipe)
    # IDs for recipe, revision, ingredient groups, ingredients are generated
    await db.flush()
    await db.refresh(revision)
    # Eagerly load all relationships for Pydantic conversion
    result = await db.execute(
        select(RecipeRevision)
        .where(RecipeRevision.id == revision.id)
        .options(
            selectinload(RecipeRevision.categories),
            selectinload(RecipeRevision.ingredient_groups)
            .selectinload(IngredientGroup.ingredients)
            .selectinload(Ingredient.unit),
            selectinload(RecipeRevision.instruction_groups),
            selectinload(RecipeRevision.recipe),
        )
    )
    revision = result.scalar_one()

    return recipe


def _get_recipe(for_write: bool = False, history: bool = False):
    async def _get_recipe(
        recipe_id: int,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user),
    ) -> Recipe:
        query = select(Recipe).filter(Recipe.id == recipe_id)

        if for_write:
            query = query.where(Recipe.owner_id == current_user.id)
        else:
            query = query.where(
                or_(Recipe.owner_id == current_user.id, Recipe.is_private.is_(False))
            )

        if history:
            query = query.options(
                joinedload(Recipe.revisions).options(
                    selectinload(RecipeRevision.ingredient_groups)
                    .selectinload(IngredientGroup.ingredients)
                    .joinedload(Ingredient.unit),
                    selectinload(RecipeRevision.instruction_groups),
                )
            )
        else:
            query = query.options(
                joinedload(Recipe.latest_revision).options(
                    selectinload(RecipeRevision.ingredient_groups)
                    .selectinload(IngredientGroup.ingredients)
                    .joinedload(Ingredient.unit),
                    selectinload(RecipeRevision.instruction_groups),
                )
            )

        result = await db.execute(query)
        recipe: Recipe | None = result.unique().scalar_one_or_none()
        if recipe is None:
            raise HTTPException(status_code=404, detail="Recipe not found")
        return recipe

    return _get_recipe


@router.get(
    "/units", response_model=PaginatedResponse[UnitRead], status_code=status.HTTP_200_OK
)
async def get_units(
    request: Request,
    pagination_params: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    query = select(Unit)
    results = await paginate(db, query, pagination_params, request)
    return results


@router.get(
    "/foods",
    response_model=PaginatedResponse[FoodCandidateRead],
    status_code=status.HTTP_200_OK,
)
async def get_foods(
    request: Request,
    pagination_params: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    initial_query = select(FoodCandidate)
    results = await paginate(
        db,
        initial_query,
        pagination_params,
        request,
    )
    return results


@router.get(
    "/foods/search",
    response_model=PaginatedResponse[FoodCandidateRead],
    status_code=status.HTTP_200_OK,
)
async def get_foods_search(
    request: Request,
    pagination_params: PaginationParams = Depends(),
    q: str = Query(..., description="Search query"),
    languages: list[str] | None = Query(None, description="Filter by languages"),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    search_service = get_meilisearch_service()

    # TODO: add highlights if desired
    attributes_to_highlight = None
    results = search_service.search_foods(
        query=q,
        languages=languages,
        limit=pagination_params.page_size,
        offset=(pagination_params.page - 1) * pagination_params.page_size,
        attributes_to_highlight=attributes_to_highlight,
    )
    # generate the final output
    ret = []
    for r in results["hits"]:
        ret.append(
            FoodCandidateRead(
                name=r["name"],
                description=r["description"],
                language=r["language"],
            )
        )
    # TODO: Bit too hacked, wrap it correctly
    pagination_meta = PaginationMeta(
        total=results["estimatedTotalHits"],
        current_page=pagination_params.page,
        page_size=pagination_params.page_size,
        total_pages=results["estimatedTotalHits"] // pagination_params.page_size,
        next=None,
        previous=None,
    )
    return PaginatedResponse(pagination=pagination_meta, results=ret)


@router.get(
    "/categories",
    response_model=PaginatedResponse[RecipeCategoryRead],
    status_code=status.HTTP_200_OK,
)
async def get_categories(
    request: Request,
    pagination_params: PaginationParams = Depends(),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
):
    initial_query = select(RecipeCategories)
    results = await paginate(
        db,
        initial_query,
        pagination_params,
        request,
    )
    return results


@router.get(
    "/multilingual",
    status_code=status.HTTP_200_OK,
)
async def get_multilingual(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    with open(APP_DIR.parent.joinpath("data", "multilingual.json")) as f:
        data = json.load(f)
        return data


@router.get(
    "",
    response_model=PaginatedResponse[RecipeRead],
    status_code=status.HTTP_200_OK,
)
async def get_recipes(
    request: Request,
    pagination_params: PaginationParams = Depends(),
    date_filter_params: DateFilterParams = Depends(date_filter_dependency(Recipe)),
    sorting_filter_params: SortParams = Depends(
        sort_dependency(Recipe, allowed_columns=["id", "updated_at", "created_at"])
    ),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    initial_query = select(Recipe).where(
        or_(Recipe.owner_id == current_user.id, Recipe.is_private.is_(False))
    )
    initial_query = apply_date_filter(initial_query, Recipe, date_filter_params)
    initial_query = apply_sorting(initial_query, Recipe, sorting_filter_params)

    fav_subquery = (
        select(user_favorite_recipes.c.recipe_id)
        .where(user_favorite_recipes.c.user_id == current_user.id)
        .subquery()
    )

    def _enrich(ids: list[int]) -> Select:
        stmt = select(Recipe).where(Recipe.id.in_(ids))
        stmt = stmt.options(
            selectinload(Recipe.latest_revision).selectinload(
                RecipeRevision.categories
            ),
            selectinload(Recipe.latest_revision)
            .selectinload(RecipeRevision.ingredient_groups)
            .selectinload(IngredientGroup.ingredients)
            .selectinload(Ingredient.unit),
            selectinload(Recipe.latest_revision).selectinload(
                RecipeRevision.instruction_groups
            ),
        )

        return stmt

    results = await paginate(db, initial_query, pagination_params, request, _enrich)

    # add favorited property in post to the found recipes
    # here we could do it via the database, but its difficult
    recipe_ids = [r.id for r in results.results]
    fav_rows = await db.execute(
        select(user_favorite_recipes.c.recipe_id).where(
            (user_favorite_recipes.c.user_id == current_user.id)
            & (user_favorite_recipes.c.recipe_id.in_(recipe_ids))
        )
    )
    fav_ids = {r[0] for r in fav_rows.all()}
    items = [
        RecipeRead.from_orm(r).copy(update={"is_favorited": False})
        for r in results.results
    ]
    results.results = items

    return results


@router.get(
    "/search",
    response_model=PaginatedResponse[RecipeListView],
    status_code=status.HTTP_200_OK,
)
async def search_recipes(
    q: str = Query(..., description="Search query"),
    languages: list[str] | None = Query(None, description="Filter by languages"),
    categories: list[str] | None = Query(None, description="Filter by categories"),
    difficulty: int | None = Query(None, ge=1, le=5),
    page_size: int = Query(20, ge=1, le=100),
    page: int = Query(0, ge=1),
    favorites_only: bool = Query(False, description="Filter favorites only"),
    highlight: bool = Query(False, description="Enable search term highlighting"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Search recipes with fuzzy matching and faceted filtering

    Example:
    GET /recipes/search?q=chicken%20pasta&languages=en&languages=de&difficulty=2&highlight=true
    """
    search_service = get_meilisearch_service()

    attributes_to_highlight = (
        ["title", "subtitle", "ingredients"] if highlight else None
    )

    results = search_service.search_recipes(
        query=q,
        languages=languages,
        categories=categories,
        difficulty=difficulty,
        owner_id=current_user.id,
        limit=page_size,
        offset=(page - 1) * page_size,
        attributes_to_highlight=attributes_to_highlight,
    )

    # use the recipe_ids to lookup which ones are favorited
    recipe_ids = [r["id"] for r in results["hits"]]
    fav_rows = await db.execute(
        select(user_favorite_recipes.c.recipe_id).where(
            (user_favorite_recipes.c.user_id == current_user.id)
            & (user_favorite_recipes.c.recipe_id.in_(recipe_ids))
        )
    )
    fav_ids = {r[0] for r in fav_rows.all()}

    # generate the final output
    recipes = []
    for r in results["hits"]:
        if favorites_only and r["id"] not in fav_ids:
            continue
        recipes.append(
            RecipeListView(
                id=r["id"],
                owner_id=r["owner_id"],
                created_at=r["created_at"],
                updated_at=r["updated_at"],
                is_private=r["is_private"],
                is_draft=r["is_draft"],
                title=r["title"],
                subtitle=r["subtitle"],
                language=r["language"],
                owner_comment=r["owner_comment"],
                prep_time=r["prep_time"],
                cook_time=r["cook_time"],
                servings=r["servings"],
                difficulty=r["difficulty"],
                categories=r["categories"],
                is_favorited=r["id"] in fav_ids,
            )
        )
    # TODO: Bit too hacked, wrap it correctly
    pagination_meta = PaginationMeta(
        total=results["estimatedTotalHits"],
        current_page=page,
        page_size=page_size,
        total_pages=results["estimatedTotalHits"] // page_size,
        next=None,
        previous=None,
    )
    return PaginatedResponse(pagination=pagination_meta, results=recipes)


@router.post("", response_model=RecipeRead, status_code=status.HTTP_201_CREATED)
async def create_recipe(
    recipe_data: RecipeCreateUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    recipe = await _create_recipe(
        db=db, recipe_data=recipe_data, owner_id=current_user.id
    )

    search_service = get_meilisearch_service()
    await search_service.index_recipe(recipe, db)

    return recipe


@router.put(
    "/{recipe_id}", response_model=RecipeRead, status_code=status.HTTP_201_CREATED
)
async def update_recipe(
    recipe_data: RecipeCreateUpdate,
    recipe: Recipe = Depends(_get_recipe(for_write=True)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    update = await _update_recipe(recipe, recipe_data, db)
    search_service = get_meilisearch_service()
    await search_service.index_recipe(recipe, db)

    recipe_id = update.id
    fav_rows = await db.execute(
        select(user_favorite_recipes.c.recipe_id).where(
            (user_favorite_recipes.c.user_id == current_user.id)
            & (user_favorite_recipes.c.recipe_id == recipe_id)
        )
    )
    found = fav_rows.scalar_one_or_none() is not None

    ret = RecipeRead.from_orm(recipe)
    ret.is_favorited = found
    return ret


@router.get("/{recipe_id}", response_model=RecipeRead, status_code=status.HTTP_200_OK)
async def get_recipe(
    recipe: Recipe = Depends(_get_recipe(for_write=False)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    recipe_id = recipe.id
    fav_rows = await db.execute(
        select(user_favorite_recipes.c.recipe_id).where(
            (user_favorite_recipes.c.user_id == current_user.id)
            & (user_favorite_recipes.c.recipe_id == recipe_id)
        )
    )
    found = fav_rows.scalar_one_or_none() is not None

    ret = RecipeRead.from_orm(recipe)
    ret.is_favorited = found
    return ret


@router.delete(
    "/{recipe_id}/favorites", response_model=RecipeRead, status_code=status.HTTP_200_OK
)
async def remove_recipe_favorite(
    recipe: Recipe = Depends(_get_recipe(for_write=False)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if recipe in current_user.favorite_recipes:
        current_user.favorite_recipes.remove(recipe)
    ret = RecipeRead.from_orm(recipe)
    ret.is_favorited = False  # we just assume it was done correctly...
    return ret


@router.post(
    "/{recipe_id}/favorites",
    response_model=RecipeRead,
    status_code=status.HTTP_200_OK,
)
async def add_recipe_favorite(
    recipe: Recipe = Depends(_get_recipe(for_write=False)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user.favorite_recipes.append(recipe)
    ret = RecipeRead.from_orm(recipe)
    ret.is_favorited = True  # we just assume it was done correctly...
    return ret


@router.delete(
    "/{recipe_id}", response_model=None, status_code=status.HTTP_204_NO_CONTENT
)
async def delete_recipe(
    recipe: Recipe = Depends(_get_recipe(for_write=True)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    search_service = get_meilisearch_service()
    await search_service.delete_recipe(recipe_id=recipe.id)
    await db.delete(recipe)


@router.get(
    "/{recipe_id}/versions",
    response_model=RecipeReadHistory,
    status_code=status.HTTP_200_OK,
)
async def get_recipe_versions(
    recipe: Recipe = Depends(_get_recipe(for_write=False, history=True)),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return recipe


@router.post("/from_file", response_model=RecipeRead, status_code=status.HTTP_200_OK)
async def get_recipe_from_pdf(
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not file:
        return {"message": "No upload file sent"}

    if Path(file.filename).suffix.lower() not in [
        ".pdf",
        ".png",
        ".jpg",
        ".jpeg",
        ".webp",
        ".heic",
        ".heif",
    ]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file format. Only supporting: pdf, png, jpg, jpeg, webp, heic, heif",
        )

    recipe_data = await create_recipe_from_file(file, db)
    recipe = await _create_recipe(
        db=db, recipe_data=recipe_data, owner_id=current_user.id
    )

    search_service = get_meilisearch_service()
    await search_service.index_recipe(recipe, db)

    return recipe
