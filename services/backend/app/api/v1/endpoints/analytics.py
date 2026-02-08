"""
Analytics endpoints for event tracking and analytics queries.
"""

from datetime import datetime, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session
from sqlalchemy import func, distinct
from app.core.database import get_db
from app.models.analytics_event import AnalyticsEvent
from app.schemas.analytics import (
    AnalyticsEventCreate,
    AnalyticsEventBatch,
    AnalyticsEventBatchResponse,
    AnalyticsSummaryResponse,
    FunnelQueryResponse,
    FunnelStepResponse,
)

router = APIRouter()


@router.post("/events", response_model=AnalyticsEventBatchResponse, status_code=status.HTTP_201_CREATED)
def post_analytics_events(
    batch: AnalyticsEventBatch,
    db: Session = Depends(get_db),
) -> AnalyticsEventBatchResponse:
    """
    Batch analytics event ingestion endpoint.

    This endpoint accepts multiple analytics events at once for efficient bulk insertion.
    No authentication required - supports anonymous tracking with optional user_id linkage.

    Args:
        batch: Batch of analytics events to store
        db: Database session

    Returns:
        AnalyticsEventBatchResponse with count of events stored
    """
    events_to_add = []

    for event_data in batch.events:
        event = AnalyticsEvent(
            event_name=event_data.event_name,
            event_category=event_data.event_category,
            event_data=event_data.event_data,
            session_id=event_data.session_id,
            user_id=event_data.user_id,
            screen_name=event_data.screen_name,
            timestamp=event_data.timestamp if event_data.timestamp else datetime.utcnow(),
            app_version=event_data.app_version,
            platform=event_data.platform,
        )
        events_to_add.append(event)

    db.add_all(events_to_add)
    db.commit()

    return AnalyticsEventBatchResponse(
        events_stored=len(events_to_add),
        message=f"Successfully stored {len(events_to_add)} analytics events"
    )


@router.get("/summary", response_model=AnalyticsSummaryResponse)
def get_analytics_summary(
    days: int = 7,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db),
) -> AnalyticsSummaryResponse:
    """
    Get analytics summary with key metrics.

    Returns aggregated statistics including total events, unique sessions,
    and breakdowns by category and screen name.

    Args:
        days: Number of days to look back (default 7, ignored if start_date provided)
        start_date: Optional start date for custom range
        end_date: Optional end date for custom range (defaults to now)
        db: Database session

    Returns:
        AnalyticsSummaryResponse with summary statistics
    """
    # Determine date range
    if start_date:
        date_range_start = start_date
    else:
        date_range_start = datetime.utcnow() - timedelta(days=days)

    date_range_end = end_date if end_date else datetime.utcnow()

    # Base query with date filter
    base_query = db.query(AnalyticsEvent).filter(
        AnalyticsEvent.timestamp >= date_range_start,
        AnalyticsEvent.timestamp <= date_range_end
    )

    # Total events
    total_events = base_query.count()

    # Unique sessions (count distinct non-null session_ids)
    unique_sessions = db.query(func.count(distinct(AnalyticsEvent.session_id))).filter(
        AnalyticsEvent.timestamp >= date_range_start,
        AnalyticsEvent.timestamp <= date_range_end,
        AnalyticsEvent.session_id.isnot(None)
    ).scalar() or 0

    # Events by category
    category_counts = db.query(
        AnalyticsEvent.event_category,
        func.count(AnalyticsEvent.id)
    ).filter(
        AnalyticsEvent.timestamp >= date_range_start,
        AnalyticsEvent.timestamp <= date_range_end
    ).group_by(AnalyticsEvent.event_category).all()

    events_by_category = {category: count for category, count in category_counts}

    # Events by screen (only for non-null screen names)
    screen_counts = db.query(
        AnalyticsEvent.screen_name,
        func.count(AnalyticsEvent.id)
    ).filter(
        AnalyticsEvent.timestamp >= date_range_start,
        AnalyticsEvent.timestamp <= date_range_end,
        AnalyticsEvent.screen_name.isnot(None)
    ).group_by(AnalyticsEvent.screen_name).all()

    events_by_screen = {screen: count for screen, count in screen_counts}

    return AnalyticsSummaryResponse(
        total_events=total_events,
        unique_sessions=unique_sessions,
        events_by_category=events_by_category,
        events_by_screen=events_by_screen,
        date_range_start=date_range_start,
        date_range_end=date_range_end,
    )


@router.get("/funnel", response_model=FunnelQueryResponse)
def get_funnel_analysis(
    steps: str,
    days: int = 7,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db),
) -> FunnelQueryResponse:
    """
    Get funnel conversion analysis.

    Calculates conversion rates through a series of event steps.
    Steps parameter should be comma-separated event names.

    Args:
        steps: Comma-separated list of event names representing funnel steps
        days: Number of days to look back (default 7, ignored if start_date provided)
        start_date: Optional start date for custom range
        end_date: Optional end date for custom range (defaults to now)
        db: Database session

    Returns:
        FunnelQueryResponse with step counts and conversion rates

    Example:
        GET /analytics/funnel?steps=landing_view,onboarding_start,wizard_started,wizard_completed
    """
    # Parse steps
    step_names = [s.strip() for s in steps.split(',') if s.strip()]

    if not step_names:
        return FunnelQueryResponse(
            steps=[],
            date_range_start=datetime.utcnow(),
            date_range_end=datetime.utcnow(),
        )

    # Determine date range
    if start_date:
        date_range_start = start_date
    else:
        date_range_start = datetime.utcnow() - timedelta(days=days)

    date_range_end = end_date if end_date else datetime.utcnow()

    # Calculate counts for each step
    funnel_steps: List[FunnelStepResponse] = []
    first_step_count = None

    for step_name in step_names:
        count = db.query(func.count(distinct(AnalyticsEvent.session_id))).filter(
            AnalyticsEvent.event_name == step_name,
            AnalyticsEvent.timestamp >= date_range_start,
            AnalyticsEvent.timestamp <= date_range_end,
            AnalyticsEvent.session_id.isnot(None)
        ).scalar() or 0

        # Calculate conversion rate from first step
        conversion_rate = None
        if first_step_count is None:
            first_step_count = count
        elif first_step_count > 0:
            conversion_rate = round((count / first_step_count) * 100, 2)

        funnel_steps.append(FunnelStepResponse(
            step_name=step_name,
            count=count,
            conversion_rate=conversion_rate,
        ))

    return FunnelQueryResponse(
        steps=funnel_steps,
        date_range_start=date_range_start,
        date_range_end=date_range_end,
    )
