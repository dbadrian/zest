from datetime import datetime
from fastapi import Query, Depends, HTTPException
from typing import Literal, Optional, Type, Dict
from pydantic import BaseModel, Field
from sqlalchemy.orm import DeclarativeMeta
from sqlalchemy import DateTime, asc, desc, Column


class SortParams(BaseModel):
    sort_by: str | None = Field(None, description="Column to sort by")
    order: Literal["asc", "desc"] = Field("desc", description="Sort order")


def sort_dependency(
    model,
    default_sort: str = "id",
    allowed_columns: list[str] | None = None,
):
    def dependency(params: SortParams = Depends()):
        sort_by = params.sort_by or default_sort

        # Column existence
        if not hasattr(model, sort_by):
            valid_cols = allowed_columns or [c.key for c in model.__table__.columns]
            raise HTTPException(
                status_code=400,
                detail=f"Invalid sort_by '{sort_by}'. Valid columns: {valid_cols}",
            )

        # Allowed column whitelist
        if allowed_columns and sort_by not in allowed_columns:
            raise HTTPException(
                status_code=400,
                detail=f"Sorting by '{sort_by}' is not allowed. Allowed: {allowed_columns}",
            )

        return SortParams(sort_by=sort_by, order=params.order)

    return dependency


def apply_sorting(stmt, model, params: SortParams):
    if not params or not params.sort_by:
        return stmt

    column = getattr(model, params.sort_by)
    return stmt.order_by(asc(column) if params.order == "asc" else desc(column))


class DateFilterParams(BaseModel):
    date_from: datetime | None = Field(
        None, description="Return items newer than this datetime (ISO 8601)"
    )
    date_column: Literal["updated_at", "created_at"] = Field(
        "updated_at",
        description="Datetime column to filter on (e.g. created_at, updated_at)",
    )


def date_filter_dependency(model):
    def dependency(params: DateFilterParams = Depends()):
        # No filtering requested → safe no-op
        if params.date_from is None:
            return params

        # Cross-field validation
        if params.date_column is None:
            raise HTTPException(
                status_code=400,
                detail="date_column is required when date_from is provided",
            )

        if not hasattr(model, params.date_column):
            valid = [
                c.key for c in model.__table__.columns if isinstance(c.type, DateTime)
            ]
            raise HTTPException(
                status_code=400,
                detail=f"Invalid date_column '{params.date_column}'. Valid: {valid}",
            )

        column = getattr(model, params.date_column)
        if not isinstance(column.property.columns[0].type, DateTime):
            raise HTTPException(
                status_code=400,
                detail=f"Column '{params.date_column}' is not a datetime column",
            )

        return params

    return dependency


def apply_date_filter(stmt, model, params: DateFilterParams):
    if params.date_from is None:
        return stmt

    column = getattr(model, params.date_column)
    return stmt.where(column >= params.date_from)
