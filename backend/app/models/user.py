from datetime import date
from typing import Optional

from pydantic import BaseModel, Field


class OnboardingIn(BaseModel):
    """Data collected across the 3 onboarding steps.

    (Fields will be finalized when we build the onboarding flow together.)
    """

    first_name: str
    last_name: str
    dob: Optional[date] = None
    email: Optional[str] = None
    preferences: list[str] = Field(default_factory=list)  # rent/buy/coliving/pg/...
    primary_goal: Optional[str] = None  # 'post' | 'search'


class GoalIn(BaseModel):
    goal: str  # 'post' | 'search'


class Profile(BaseModel):
    id: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    dob: Optional[date] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None
    primary_goal: Optional[str] = None
    onboarding_completed: bool = False
