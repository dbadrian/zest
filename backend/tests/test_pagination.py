"""
Comprehensive test suite for the pagination system.

Run with: pytest test_pagination.py -v
"""

import pytest
from typing import AsyncGenerator
from unittest.mock import Mock, AsyncMock, patch
from urllib.parse import parse_qs, urlparse

from fastapi import FastAPI, Depends, Request
from fastapi.testclient import TestClient
from httpx import AsyncClient
from pydantic import ValidationError
from sqlalchemy import Column, Integer, String, ForeignKey, create_engine, select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, relationship

from app.core.pagination import (
    PaginationParams,
    paginate,
    get_pagination_params,
    _build_page_url,
)
from app.core.config import settings
from app.db import engine, init_db
from app.recipes.constants import UnitSystem
from app.recipes.models import Unit


@pytest.fixture(scope="function", autouse=True)
async def prepare_database():
    # call your async DB init
    await init_db()
    yield


@pytest.fixture
async def populated_test_db(db_session: AsyncSession):
    """Populate database with test data."""
    # Create 50 test recipes
    units = [
        Unit(id=i, name=f"name{i}", unit_system=UnitSystem.METRIC) for i in range(1, 51)
    ]

    db_session.add_all(units)
    await db_session.flush()

    return db_session


class TestPaginationParams:
    """Test the PaginationParams model."""

    @pytest.mark.anyio
    async def test_default_values(self):
        """Test default pagination parameters."""
        params = PaginationParams()
        assert params.page == 1
        assert params.page_size == settings.PAGINATION_DEFAULT_PAGE_SIZE
        assert params.offset == 0
        assert params.limit == settings.PAGINATION_DEFAULT_PAGE_SIZE

    @pytest.mark.anyio
    async def test_custom_values(self):
        """Test custom pagination parameters."""
        params = PaginationParams(page=3, page_size=10)
        assert params.page == 3
        assert params.page_size == 10
        assert params.offset == 20  # (3-1) * 10
        assert params.limit == 10

    @pytest.mark.anyio
    async def test_page_must_be_positive(self):
        """Test that page must be >= 1."""
        with pytest.raises(ValidationError) as exc_info:
            PaginationParams(page=0)
        assert "greater than or equal to 1" in str(exc_info.value).lower()

        with pytest.raises(ValidationError):
            PaginationParams(page=-1)

    @pytest.mark.anyio
    async def test_page_size_must_be_positive(self):
        """Test that page_size must be >= 1."""
        with pytest.raises(ValidationError) as exc_info:
            PaginationParams(page_size=0)
        assert "greater than or equal" in str(exc_info.value).lower()

        with pytest.raises(ValidationError):
            PaginationParams(page_size=-5)

    @pytest.mark.anyio
    async def test_offset_calculation(self):
        """Test offset calculation for various pages."""
        assert PaginationParams(page=1, page_size=10).offset == 0
        assert PaginationParams(page=2, page_size=10).offset == 10
        assert PaginationParams(page=5, page_size=20).offset == 80
        assert PaginationParams(page=10, page_size=5).offset == 45


class TestBuildPageUrl:
    """Test URL building functionality."""

    @pytest.mark.anyio
    async def test_basic_url_building(self):
        """Test basic URL construction."""
        request = Mock(spec=Request)
        request.url.path = f"{settings.API_V1_STR}/recipes"
        request.query_params = {}

        url = _build_page_url(request, page=2, page_size=20)

        assert url.startswith(f"{settings.API_V1_STR}/recipes?")
        parsed = urlparse(url)
        params = parse_qs(parsed.query)

        assert params["page"] == ["2"]
        assert params["page_size"] == ["20"]

    @pytest.mark.anyio
    async def test_preserve_other_params(self):
        """Test that other query parameters are preserved."""
        request = Mock(spec=Request)
        request.url.path = f"{settings.API_V1_STR}/recipes"
        request.query_params = {
            "search": "pasta",
            "category": "italian",
            "page": "1",
            "page_size": "10",
        }

        url = _build_page_url(request, page=3, page_size=25)

        parsed = urlparse(url)
        params = parse_qs(parsed.query)

        assert params["page"] == ["3"]
        assert params["page_size"] == ["25"]
        assert params["search"] == ["pasta"]
        assert params["category"] == ["italian"]

    @pytest.mark.anyio
    async def test_url_encoding(self):
        """Test that special characters are properly encoded."""
        request = Mock(spec=Request)
        request.url.path = f"{settings.API_V1_STR}/recipes"
        request.query_params = {"search": "chicken & rice", "page": "1"}

        url = _build_page_url(request, page=2, page_size=10)

        # URL should be properly encoded
        assert "chicken+%26+rice" in url or "chicken%20%26%20rice" in url


class TestPaginateFunction:
    """Test the main paginate function with real database."""

    @pytest.mark.anyio
    async def test_first_page(self, populated_test_db: AsyncSession):
        """Test pagination on first page."""
        request = Mock(spec=Request)
        request.url.path = "/api/v1/recipes"
        request.query_params = {}

        query = select(Unit).order_by(Unit.id)
        params = PaginationParams(page=1, page_size=10)

        result = await paginate(populated_test_db, query, params, request)

        assert result.pagination.total == 50
        assert result.pagination.total_pages == 5
        assert result.pagination.current_page == 1
        assert result.pagination.page_size == 10
        assert result.pagination.previous is None
        assert result.pagination.next is not None
        assert len(result.results) == 10
        assert result.results[0].id == 1
        assert result.results[-1].id == 10
