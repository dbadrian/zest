"""
Professional reusable pagination system for FastAPI with SQLAlchemy.

Usage Pattern 1 (Simple - single query):
    from pagination import paginate, PaginationParams, PaginatedResponse
    from schemas import RecipeSchema

    @app.get("/recipes", response_model=PaginatedResponse[RecipeSchema])
    async def get_recipes(
        request: Request,
        db: AsyncSession = Depends(get_db),
        pagination: PaginationParams = Depends(get_pagination_params)
    ):
        query = select(Recipe)
        return await paginate(db, query, pagination, request)

Usage Pattern 2 (Efficient - two queries with eager loading):
    @app.get("/recipes", response_model=PaginatedResponse[RecipeSchema])
    async def get_recipes(
        request: Request,
        db: AsyncSession = Depends(get_db),
        pagination: PaginationParams = Depends(get_pagination_params)
    ):
        # Simple query for pagination
        simple_query = select(Recipe).order_by(Recipe.created_at.desc())

        # Complex query for eager loading
        def enrich_query(ids):
            return (
                select(Recipe)
                .where(Recipe.id.in_(ids))
                .options(
                    joinedload(Recipe.latest_revision).options(
                        selectinload(RecipeRevision.ingredient_groups)
                        .selectinload(IngredientGroup.ingredients)
                        .joinedload(Ingredient.unit),
                    )
                )
            )

        return await paginate(
            db, simple_query, pagination, request,
            enrich_query=enrich_query
        )

Response Format:
    {
        "pagination": {
            "total": 150,
            "total_pages": 8,
            "current_page": 2,
            "page_size": 20,
            "next": "/recipes?page=3&page_size=20",
            "previous": "/recipes?page=1&page_size=20"
        },
        "results": [...]
    }
"""

from typing import Any, Callable, Dict, Generic, List, TypeVar
from urllib.parse import urlencode

from fastapi import Query, Request
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import Select


from app.core.config import settings

# Type variable for generic pagination results
T = TypeVar("T")


class PaginationParams(BaseModel):
    """Query parameters for pagination."""

    page: int = Field(default=1, ge=1, description="Page number (1-indexed)")
    page_size: int = Field(
        default=settings.PAGINATION_DEFAULT_PAGE_SIZE,
        ge=1,
        le=settings.PAGINATION_MAX_PAGE_SIZE,
        description="Number of items per page",
    )

    @field_validator("page_size")
    @classmethod
    def validate_page_size(cls, v: int) -> int:
        """Validate page_size doesn't exceed maximum."""
        max_size = settings.PAGINATION_MAX_PAGE_SIZE

        if v > max_size:
            raise ValueError(f"page_size cannot exceed {max_size}")
        if v < 1:
            raise ValueError("page_size must be at least 1")
        return v

    @property
    def offset(self) -> int:
        """Calculate offset for database query."""
        return (self.page - 1) * self.page_size

    @property
    def limit(self) -> int:
        """Get limit for database query."""
        return self.page_size


class PaginationMeta(BaseModel):
    """Pagination metadata in response."""

    total: int = Field(description="Total number of items")
    total_pages: int = Field(description="Total number of pages")
    current_page: int = Field(description="Current page number")
    page_size: int = Field(description="Items per page")
    next: str | None = Field(default=None, description="URL to next page")
    previous: str | None = Field(default=None, description="URL to previous page")


class PaginatedResponse(BaseModel, Generic[T]):
    """Generic paginated response structure."""

    pagination: PaginationMeta
    results: List[T]


def _build_page_url(request: Request, page: int, page_size: int) -> str:
    """
    Build URL for a specific page while preserving other query parameters.

    Args:
        request: FastAPI request object
        page: Target page number
        page_size: Items per page

    Returns:
        Relative URL path with query parameters
    """
    # Get existing query params and update with new page/page_size
    params = dict(request.query_params)
    params["page"] = str(page)
    params["page_size"] = str(page_size)

    # Build query string
    query_string = urlencode(sorted(params.items()))

    # Return relative path
    return f"{request.url.path}?{query_string}"


async def paginate(
    db: AsyncSession,
    query: Select,
    params: PaginationParams,
    request: Request,
    enrich_query: Callable[[List[Any]], Select] | None = None,
) -> PaginatedResponse[T]:
    """
    Paginate a SQLAlchemy query with optional two-step enrichment.

    This function supports two patterns:

    Pattern 1 (Single Query):
        Execute one query with all joins/options included.

    Pattern 2 (Two Query - Recommended for complex eager loading):
        1. Execute simple query for pagination (fast COUNT, fast fetch)
        2. Execute complex query with joins on just the paginated IDs

    The two-query pattern is more efficient for deeply nested models because:
    - COUNT query remains fast (no joins)
    - Initial fetch is fast (no joins)
    - Complex joins only load data for the current page

    Args:
        db: Async database session
        query: SQLAlchemy Select statement (should be simple if using enrich_query)
        params: Pagination parameters from query string
        request: FastAPI request object for URL generation
        enrich_query: Optional function that takes a list of IDs and returns
                     a Select statement with eager loading options

    Returns:
        Dictionary with pagination metadata and results

    Example (Single Query):
        >>> query = select(Recipe).options(joinedload(Recipe.author))
        >>> result = await paginate(db, query, params, request)

    Example (Two Query - Efficient):
        >>> simple_query = select(Recipe).order_by(Recipe.created_at.desc())
        >>>
        >>> def enrich(ids):
        >>>     return (
        >>>         select(Recipe)
        >>>         .where(Recipe.id.in_(ids))
        >>>         .options(
        >>>             joinedload(Recipe.latest_revision).options(
        >>>                 selectinload(RecipeRevision.ingredient_groups)
        >>>                 .selectinload(IngredientGroup.ingredients)
        >>>             )
        >>>         )
        >>>     )
        >>>
        >>> result = await paginate(db, simple_query, params, request, enrich)
    """
    # Extract the main entity being queried (first FROM clause)
    main_entity = query.column_descriptions[0]["entity"]

    # Execute COUNT query on main entity only (no joins = fast)
    count_query = select(func.count()).select_from(main_entity)

    # Apply WHERE clauses from original query to count query
    if query.whereclause is not None:
        count_query = count_query.where(query.whereclause)

    count_result = await db.execute(count_query)
    total = count_result.scalar_one()

    # Calculate total pages
    total_pages = (total + params.page_size - 1) // params.page_size if total > 0 else 0

    # Handle edge case: requested page beyond available pages
    if params.page > total_pages and total_pages > 0:
        # Return empty results with correct pagination info
        return PaginatedResponse(
            pagination=PaginationMeta(
                total=total,
                total_pages=total_pages,
                current_page=params.page,
                page_size=params.page_size,
                next=None,
                previous=_build_page_url(request, total_pages, params.page_size)
                if total_pages > 0
                else None,
            ),
            results=[],
        )

    # Execute main query with pagination (simple, no joins yet)
    paginated_query = query.offset(params.offset).limit(params.limit)
    result = await db.execute(paginated_query)
    items = result.scalars().unique().all()

    # If enrich_query is provided, perform second query with complex joins
    if enrich_query is not None and items:
        # Extract IDs from the simple query results
        # Assume the entity has an 'id' attribute
        ids = [item.id for item in items]

        # Execute enriched query with all the complex joins
        enriched_query = enrich_query(ids)
        enriched_result = await db.execute(enriched_query)
        items = enriched_result.scalars().unique().all()

        # Maintain original order from pagination query
        # Create a mapping of id -> item
        id_to_item = {item.id: item for item in items}
        items = [id_to_item[id_] for id_ in ids if id_ in id_to_item]

    # Generate next/previous URLs
    next_url = None
    if params.page < total_pages:
        next_url = _build_page_url(request, params.page + 1, params.page_size)

    previous_url = None
    if params.page > 1:
        previous_url = _build_page_url(request, params.page - 1, params.page_size)

    # Build response
    return PaginatedResponse(
        pagination=PaginationMeta(
            total=total,
            total_pages=total_pages,
            current_page=params.page,
            page_size=params.page_size,
            next=next_url,
            previous=previous_url,
        ),
        results=items,
    )


# Convenience dependency for FastAPI routes
def get_pagination_params(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(
        settings.PAGINATION_DEFAULT_PAGE_SIZE,
        ge=1,
        le=settings.PAGINATION_MAX_PAGE_SIZE,
        description="Number of items per page",
    ),
) -> PaginationParams:
    """
    FastAPI dependency for extracting pagination parameters.

    Usage:
        @app.get("/items")
        async def get_items(
            pagination: PaginationParams = Depends(get_pagination_params)
        ):
            ...
    """

    return PaginationParams(page=page, page_size=page_size)
