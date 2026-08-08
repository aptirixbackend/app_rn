from datetime import date
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict


class PropertyDraftIn(BaseModel):
    """Step 1 of posting — basic details."""

    property_type: str
    purpose: str
    city: Optional[str] = None
    area: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    bhk: Optional[str] = None
    bathrooms: Optional[int] = None
    carpet_area: Optional[float] = None
    furnishing: Optional[str] = None
    floor_number: Optional[int] = None
    total_floors: Optional[int] = None
    property_age: Optional[str] = None
    facing: Optional[str] = None
    available_from: Optional[date] = None
    # Per-type extras (PG sharing/food/gender, plot dimensions, stay rules, …).
    attributes: Optional[dict[str, Any]] = None


class PropertyUpdateIn(BaseModel):
    """Partial update for later steps (amenities, media, pricing, location,
    edit, status changes). Accepts any column the app writes; the router
    filters to an allow-list before touching the database."""

    model_config = ConfigDict(extra="allow")
