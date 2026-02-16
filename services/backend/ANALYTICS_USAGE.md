# Analytics API Usage Guide

## Overview

Sprint S4 implements a privacy-first analytics system for tracking user behavior and app usage in the MINT Swiss fintech app. The system supports anonymous tracking with optional user linkage, batch event ingestion, and comprehensive analytics queries.

## API Endpoints

### 1. POST /api/v1/analytics/events - Batch Event Ingestion

Post multiple analytics events in a single request. No authentication required.

**Request Body:**
```json
{
  "events": [
    {
      "event_name": "screen_view",
      "event_category": "navigation",
      "screen_name": "home",
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "platform": "ios",
      "app_version": "1.0.0"
    },
    {
      "event_name": "wizard_started",
      "event_category": "conversion",
      "screen_name": "wizard",
      "session_id": "550e8400-e29b-41d4-a716-446655440000",
      "event_data": "{\"step\": 1}",
      "platform": "ios"
    }
  ]
}
```

**Event Categories:**
- `navigation` - Screen views, navigation events
- `engagement` - User interactions, button clicks
- `conversion` - Significant milestones (wizard completion, profile creation)
- `error` - Error tracking

**Response:**
```json
{
  "events_stored": 2,
  "message": "Successfully stored 2 analytics events"
}
```

**Validation Rules:**
- `event_name` cannot be empty
- `event_category` must be one of: navigation, engagement, conversion, error
- Maximum 100 events per batch
- Events list cannot be empty

### 2. GET /api/v1/analytics/summary - Analytics Summary

Get aggregated statistics and key metrics.

**Query Parameters:**
- `days` (int, default=7) - Number of days to look back
- `start_date` (datetime, optional) - Custom start date
- `end_date` (datetime, optional) - Custom end date

**Example Request:**
```bash
GET /api/v1/analytics/summary?days=30
```

**Response:**
```json
{
  "total_events": 1523,
  "unique_sessions": 245,
  "events_by_category": {
    "navigation": 892,
    "engagement": 487,
    "conversion": 112,
    "error": 32
  },
  "events_by_screen": {
    "home": 245,
    "wizard": 178,
    "profile": 143,
    "budget": 89
  },
  "date_range_start": "2025-01-08T10:00:00",
  "date_range_end": "2025-02-07T10:00:00"
}
```

### 3. GET /api/v1/analytics/funnel - Funnel Analysis

Calculate conversion rates through a series of event steps.

**Query Parameters:**
- `steps` (string, required) - Comma-separated list of event names
- `days` (int, default=7) - Number of days to look back
- `start_date` (datetime, optional) - Custom start date
- `end_date` (datetime, optional) - Custom end date

**Example Request:**
```bash
GET /api/v1/analytics/funnel?steps=landing_view,onboarding_start,wizard_started,wizard_completed
```

**Response:**
```json
{
  "steps": [
    {
      "step_name": "landing_view",
      "count": 1000,
      "conversion_rate": null
    },
    {
      "step_name": "onboarding_start",
      "count": 750,
      "conversion_rate": 75.0
    },
    {
      "step_name": "wizard_started",
      "count": 500,
      "conversion_rate": 50.0
    },
    {
      "step_name": "wizard_completed",
      "count": 400,
      "conversion_rate": 40.0
    }
  ],
  "date_range_start": "2025-01-31T10:00:00",
  "date_range_end": "2025-02-07T10:00:00"
}
```

The `conversion_rate` is calculated as percentage from the first step.

## Privacy-First Design

The analytics system is designed with privacy in mind:

1. **Anonymous Tracking**: Events use `session_id` (anonymous UUID) rather than user identifiable information
2. **Optional User Linkage**: `user_id` is optional and only used when user is authenticated
3. **No PII Storage**: Events do not store email, names, or other personal identifiable information
4. **Client-Side Control**: Mobile app controls what data is sent

## Database Schema

**Table: `analytics_events`**

| Column | Type | Nullable | Indexed | Description |
|--------|------|----------|---------|-------------|
| id | INTEGER | No | Primary Key | Auto-increment ID |
| event_name | VARCHAR | No | Yes | Event identifier (e.g., "screen_view") |
| event_category | VARCHAR | No | Yes | Category: navigation, engagement, conversion, error |
| event_data | TEXT | Yes | No | JSON string with additional event data |
| session_id | VARCHAR | Yes | Yes | Anonymous session UUID |
| user_id | VARCHAR | Yes | Yes | Optional user ID (foreign key to users.id) |
| screen_name | VARCHAR | Yes | Yes | Screen/page name |
| timestamp | DATETIME | No | Yes | Event timestamp (UTC) |
| app_version | VARCHAR | Yes | No | App version string |
| platform | VARCHAR | Yes | No | Platform: ios, android, web |

**Indexes:**
- event_name, event_category, session_id, user_id, screen_name, timestamp (all indexed for fast queries)

## Example Usage Scenarios

### Scenario 1: Track User Journey (Anonymous)

```python
import requests
import uuid

session_id = str(uuid.uuid4())

# User lands on app
requests.post("http://localhost:8000/api/v1/analytics/events", json={
    "events": [
        {
            "event_name": "app_opened",
            "event_category": "navigation",
            "session_id": session_id,
            "platform": "ios",
            "app_version": "1.0.0"
        }
    ]
})

# User views home screen
requests.post("http://localhost:8000/api/v1/analytics/events", json={
    "events": [
        {
            "event_name": "screen_view",
            "event_category": "navigation",
            "screen_name": "home",
            "session_id": session_id,
            "platform": "ios"
        }
    ]
})

# User starts wizard
requests.post("http://localhost:8000/api/v1/analytics/events", json={
    "events": [
        {
            "event_name": "wizard_started",
            "event_category": "conversion",
            "screen_name": "wizard",
            "session_id": session_id,
            "platform": "ios"
        }
    ]
})
```

### Scenario 2: Track Authenticated User Actions

```python
# After user logs in
user_id = "550e8400-e29b-41d4-a716-446655440000"

requests.post("http://localhost:8000/api/v1/analytics/events", json={
    "events": [
        {
            "event_name": "profile_updated",
            "event_category": "engagement",
            "user_id": user_id,
            "session_id": session_id,
            "screen_name": "profile",
            "platform": "ios"
        }
    ]
})
```

### Scenario 3: Batch Multiple Events

```python
# Send multiple events at once (e.g., on app close or periodic flush)
requests.post("http://localhost:8000/api/v1/analytics/events", json={
    "events": [
        {
            "event_name": "screen_view",
            "event_category": "navigation",
            "screen_name": "budget",
            "session_id": session_id
        },
        {
            "event_name": "simulator_used",
            "event_category": "engagement",
            "event_data": "{\"type\": \"pillar_3a\", \"amount\": 7056}",
            "session_id": session_id
        },
        {
            "event_name": "report_generated",
            "event_category": "conversion",
            "session_id": session_id
        }
    ]
})
```

### Scenario 4: Query Analytics Dashboard

```python
# Get summary for last 30 days
response = requests.get("http://localhost:8000/api/v1/analytics/summary?days=30")
summary = response.json()

print(f"Total Events: {summary['total_events']}")
print(f"Unique Sessions: {summary['unique_sessions']}")
print(f"Navigation Events: {summary['events_by_category']['navigation']}")

# Analyze wizard completion funnel
response = requests.get(
    "http://localhost:8000/api/v1/analytics/funnel",
    params={
        "steps": "wizard_started,wizard_step_2,wizard_step_3,wizard_completed",
        "days": 7
    }
)
funnel = response.json()

for step in funnel['steps']:
    rate = step['conversion_rate'] if step['conversion_rate'] else "N/A"
    print(f"{step['step_name']}: {step['count']} users ({rate}% conversion)")
```

## Testing

The implementation includes 19 comprehensive tests covering:

- Anonymous event tracking
- Authenticated user events
- Batch event ingestion
- Event validation (empty names, invalid categories, batch limits)
- Analytics summary queries
- Funnel analysis with conversion rates
- Date range filtering
- Privacy compliance
- Session-based aggregation

Run tests:
```bash
cd services/backend
python3 -m pytest tests/test_analytics.py -v
```

All 115 tests pass (96 existing + 19 new analytics tests).

## Files Created/Modified

### New Files:
- `/services/backend/app/models/analytics_event.py` - Analytics event database model
- `/services/backend/app/schemas/analytics.py` - Pydantic schemas for analytics
- `/services/backend/app/api/v1/endpoints/analytics.py` - Analytics API endpoints
- `/services/backend/tests/test_analytics.py` - Comprehensive test suite

### Modified Files:
- `/services/backend/app/api/v1/router.py` - Added analytics router
- `/services/backend/app/models/__init__.py` - Added AnalyticsEvent import
- `/services/backend/app/main.py` - Added AnalyticsEvent to startup imports
- `/services/backend/tests/conftest.py` - Added AnalyticsEvent to test setup and cleanup

## Performance Considerations

1. **Indexes**: All frequently queried columns are indexed (event_name, event_category, session_id, user_id, screen_name, timestamp)
2. **Batch Ingestion**: Events should be batched client-side and sent in groups (max 100 per request)
3. **Date Range Queries**: Always include date range filters for better query performance
4. **Session-Based Aggregation**: Funnel analysis uses `distinct(session_id)` for accurate unique user counts

## Future Enhancements

Potential future improvements:
- Add authentication requirement for summary/funnel endpoints (admin-only)
- Implement data retention policies (auto-delete old events)
- Add more aggregation queries (daily/weekly/monthly trends)
- Export functionality (CSV, JSON)
- Real-time analytics dashboard
- Event filtering by platform, app_version
- Cohort analysis
- Time-series analysis
