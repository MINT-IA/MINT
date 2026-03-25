"""
Analytics schemas for event tracking and analytics queries.
"""

from datetime import datetime
from typing import Optional, List, Dict
from pydantic import BaseModel, ConfigDict, field_validator


class AnalyticsEventCreate(BaseModel):
    """Schema for creating a single analytics event."""
    event_name: str
    event_category: str
    event_data: Optional[str] = None  # JSON string
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    screen_name: Optional[str] = None
    timestamp: Optional[datetime] = None
    app_version: Optional[str] = None
    platform: Optional[str] = None

    @field_validator('event_name')
    @classmethod
    def validate_event_name(cls, v: str) -> str:
        if not v or len(v.strip()) == 0:
            raise ValueError('event_name cannot be empty')
        return v.strip()

    @field_validator('event_category')
    @classmethod
    def validate_event_category(cls, v: str) -> str:
        valid_categories = ["navigation", "engagement", "conversion", "error", "system", "experiment"]
        if v not in valid_categories:
            raise ValueError(f'event_category must be one of {valid_categories}')
        return v


class AnalyticsEventBatch(BaseModel):
    """Schema for batch event ingestion."""
    events: List[AnalyticsEventCreate]

    @field_validator('events')
    @classmethod
    def validate_events(cls, v: List[AnalyticsEventCreate]) -> List[AnalyticsEventCreate]:
        if not v or len(v) == 0:
            raise ValueError('events list cannot be empty')
        if len(v) > 100:
            raise ValueError('cannot process more than 100 events at once')
        return v


class AnalyticsEventResponse(BaseModel):
    """Schema for analytics event response."""
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_name: str
    event_category: str
    event_data: Optional[str]
    session_id: Optional[str]
    user_id: Optional[str]
    screen_name: Optional[str]
    timestamp: datetime
    app_version: Optional[str]
    platform: Optional[str]


class AnalyticsEventBatchResponse(BaseModel):
    """Schema for batch event ingestion response."""
    events_stored: int
    message: str


class FunnelStepResponse(BaseModel):
    """Schema for funnel step query response."""
    step_name: str
    count: int
    conversion_rate: Optional[float] = None  # % from first step


class AnalyticsSummaryResponse(BaseModel):
    """Schema for analytics summary response."""
    total_events: int
    unique_sessions: int
    events_by_category: Dict[str, int]
    events_by_screen: Dict[str, int]
    date_range_start: datetime
    date_range_end: datetime


class FunnelQueryResponse(BaseModel):
    """Schema for funnel query response."""
    steps: List[FunnelStepResponse]
    date_range_start: datetime
    date_range_end: datetime
