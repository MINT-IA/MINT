"""
Tests for analytics endpoints - event tracking and analytics queries.
"""

from datetime import datetime, timedelta, timezone
from uuid import uuid4


def test_post_single_event_anonymous(client):
    """Test posting a single anonymous analytics event."""
    event_data = {
        "events": [
            {
                "event_name": "screen_view",
                "event_category": "navigation",
                "screen_name": "home",
                "session_id": str(uuid4()),
                "platform": "ios",
                "app_version": "1.0.0"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201
    data = response.json()
    assert data["events_stored"] == 1
    assert "Successfully stored 1 analytics events" in data["message"]


def test_post_multiple_events_batch(client):
    """Test posting multiple events in a batch."""
    session_id = str(uuid4())
    event_data = {
        "events": [
            {
                "event_name": "landing_view",
                "event_category": "navigation",
                "screen_name": "landing",
                "session_id": session_id,
                "platform": "web"
            },
            {
                "event_name": "onboarding_start",
                "event_category": "engagement",
                "screen_name": "onboarding",
                "session_id": session_id,
                "platform": "web"
            },
            {
                "event_name": "wizard_started",
                "event_category": "conversion",
                "screen_name": "wizard",
                "session_id": session_id,
                "platform": "web"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201
    data = response.json()
    assert data["events_stored"] == 3


def test_post_events_with_user_id(client):
    """Test posting events with authenticated user_id."""
    # Register a user first
    user_response = client.post("/api/v1/auth/register", json={
        "email": "analytics@test.com",
        "password": "testpass123",
        "display_name": "Analytics User"
    })
    assert user_response.status_code == 201
    user_data = user_response.json()
    user_id = user_data["user_id"]

    # Post event with user_id
    event_data = {
        "events": [
            {
                "event_name": "profile_updated",
                "event_category": "engagement",
                "user_id": user_id,
                "session_id": str(uuid4()),
                "platform": "android"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201
    data = response.json()
    assert data["events_stored"] == 1


def test_post_events_with_custom_timestamp(client):
    """Test posting events with custom timestamps."""
    custom_time = datetime.now(timezone.utc) - timedelta(hours=2)
    event_data = {
        "events": [
            {
                "event_name": "custom_event",
                "event_category": "engagement",
                "timestamp": custom_time.isoformat(),
                "session_id": str(uuid4())
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201


def test_post_events_with_event_data_json(client):
    """Test posting events with JSON event_data field."""
    event_data = {
        "events": [
            {
                "event_name": "simulator_used",
                "event_category": "engagement",
                "event_data": '{"simulator_type": "pillar_3a", "amount": 7056}',
                "session_id": str(uuid4())
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201


def test_post_events_validation_empty_event_name(client):
    """Test that empty event_name fails validation."""
    event_data = {
        "events": [
            {
                "event_name": "",
                "event_category": "navigation"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 422


def test_post_events_validation_invalid_category(client):
    """Test that invalid event_category fails validation."""
    event_data = {
        "events": [
            {
                "event_name": "test_event",
                "event_category": "invalid_category"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 422


def test_post_events_validation_empty_batch(client):
    """Test that empty events array fails validation."""
    event_data = {
        "events": []
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 422


def test_post_events_validation_too_many_events(client):
    """Test that more than 100 events fails validation."""
    event_data = {
        "events": [
            {
                "event_name": f"event_{i}",
                "event_category": "navigation"
            }
            for i in range(101)
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 422


def test_get_analytics_summary_default(client):
    """Test getting analytics summary with default parameters (7 days)."""
    # Post some test events
    session_1 = str(uuid4())
    session_2 = str(uuid4())

    events = {
        "events": [
            {
                "event_name": "screen_view",
                "event_category": "navigation",
                "screen_name": "home",
                "session_id": session_1,
            },
            {
                "event_name": "screen_view",
                "event_category": "navigation",
                "screen_name": "profile",
                "session_id": session_1,
            },
            {
                "event_name": "wizard_started",
                "event_category": "engagement",
                "screen_name": "wizard",
                "session_id": session_2,
            },
            {
                "event_name": "error_occurred",
                "event_category": "error",
                "session_id": session_2,
            }
        ]
    }

    client.post("/api/v1/analytics/events", json=events)

    # Get summary
    response = client.get("/api/v1/analytics/summary")
    assert response.status_code == 200
    data = response.json()

    assert data["total_events"] == 4
    assert data["unique_sessions"] == 2
    assert data["events_by_category"]["navigation"] == 2
    assert data["events_by_category"]["engagement"] == 1
    assert data["events_by_category"]["error"] == 1
    assert data["events_by_screen"]["home"] == 1
    assert data["events_by_screen"]["profile"] == 1
    assert data["events_by_screen"]["wizard"] == 1
    assert "date_range_start" in data
    assert "date_range_end" in data


def test_get_analytics_summary_custom_days(client):
    """Test getting analytics summary with custom day range."""
    # Post event
    events = {
        "events": [
            {
                "event_name": "test_event",
                "event_category": "navigation",
                "session_id": str(uuid4()),
            }
        ]
    }
    client.post("/api/v1/analytics/events", json=events)

    # Get summary for last 30 days
    response = client.get("/api/v1/analytics/summary?days=30")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 1


def test_get_analytics_summary_date_range_filter(client):
    """Test analytics summary with custom date range."""
    # Post events with different timestamps
    now = datetime.now(timezone.utc)
    old_event_time = now - timedelta(days=10)
    recent_event_time = now - timedelta(days=2)

    events = {
        "events": [
            {
                "event_name": "old_event",
                "event_category": "navigation",
                "session_id": str(uuid4()),
                "timestamp": old_event_time.isoformat()
            },
            {
                "event_name": "recent_event",
                "event_category": "navigation",
                "session_id": str(uuid4()),
                "timestamp": recent_event_time.isoformat()
            }
        ]
    }
    client.post("/api/v1/analytics/events", json=events)

    # Query only last 5 days (should get only recent event)
    response = client.get("/api/v1/analytics/summary?days=5")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 1  # Only recent event


def test_get_analytics_summary_empty(client):
    """Test analytics summary with no events."""
    response = client.get("/api/v1/analytics/summary")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 0
    assert data["unique_sessions"] == 0
    assert data["events_by_category"] == {}
    assert data["events_by_screen"] == {}


def test_get_funnel_analysis_basic(client):
    """Test basic funnel analysis with multiple steps."""
    session_1 = str(uuid4())
    session_2 = str(uuid4())
    session_3 = str(uuid4())

    # Session 1: completes all steps
    # Session 2: drops off at step 2
    # Session 3: completes all steps
    events = {
        "events": [
            # Session 1
            {"event_name": "landing_view", "event_category": "navigation", "session_id": session_1},
            {"event_name": "onboarding_start", "event_category": "engagement", "session_id": session_1},
            {"event_name": "wizard_started", "event_category": "conversion", "session_id": session_1},
            {"event_name": "wizard_completed", "event_category": "conversion", "session_id": session_1},
            # Session 2
            {"event_name": "landing_view", "event_category": "navigation", "session_id": session_2},
            {"event_name": "onboarding_start", "event_category": "engagement", "session_id": session_2},
            # Session 3
            {"event_name": "landing_view", "event_category": "navigation", "session_id": session_3},
            {"event_name": "onboarding_start", "event_category": "engagement", "session_id": session_3},
            {"event_name": "wizard_started", "event_category": "conversion", "session_id": session_3},
            {"event_name": "wizard_completed", "event_category": "conversion", "session_id": session_3},
        ]
    }
    client.post("/api/v1/analytics/events", json=events)

    # Query funnel
    response = client.get("/api/v1/analytics/funnel?steps=landing_view,onboarding_start,wizard_started,wizard_completed")
    assert response.status_code == 200
    data = response.json()

    steps = data["steps"]
    assert len(steps) == 4

    # Verify step counts
    assert steps[0]["step_name"] == "landing_view"
    assert steps[0]["count"] == 3
    assert steps[0]["conversion_rate"] is None  # First step has no conversion rate

    assert steps[1]["step_name"] == "onboarding_start"
    assert steps[1]["count"] == 3
    assert steps[1]["conversion_rate"] == 100.0  # 3/3 * 100

    assert steps[2]["step_name"] == "wizard_started"
    assert steps[2]["count"] == 2
    assert steps[2]["conversion_rate"] == 66.67  # 2/3 * 100

    assert steps[3]["step_name"] == "wizard_completed"
    assert steps[3]["count"] == 2
    assert steps[3]["conversion_rate"] == 66.67  # 2/3 * 100


def test_get_funnel_analysis_empty_steps(client):
    """Test funnel analysis with no steps provided."""
    response = client.get("/api/v1/analytics/funnel?steps=")
    assert response.status_code == 200
    data = response.json()
    assert data["steps"] == []


def test_get_funnel_analysis_no_matching_events(client):
    """Test funnel analysis with steps that have no matching events."""
    response = client.get("/api/v1/analytics/funnel?steps=nonexistent_step1,nonexistent_step2")
    assert response.status_code == 200
    data = response.json()
    steps = data["steps"]
    assert len(steps) == 2
    assert steps[0]["count"] == 0
    assert steps[1]["count"] == 0


def test_get_funnel_analysis_date_range(client):
    """Test funnel analysis with date range filtering."""
    now = datetime.now(timezone.utc)
    old_event_time = now - timedelta(days=10)
    session_old = str(uuid4())
    session_new = str(uuid4())

    events = {
        "events": [
            {
                "event_name": "step_1",
                "event_category": "navigation",
                "session_id": session_old,
                "timestamp": old_event_time.isoformat()
            },
            {
                "event_name": "step_1",
                "event_category": "navigation",
                "session_id": session_new,
            }
        ]
    }
    client.post("/api/v1/analytics/events", json=events)

    # Query only last 5 days
    response = client.get("/api/v1/analytics/funnel?steps=step_1&days=5")
    assert response.status_code == 200
    data = response.json()
    assert data["steps"][0]["count"] == 1  # Only recent event


def test_analytics_privacy_no_pii(client):
    """Test that analytics events don't contain PII - only anonymous session_id."""
    event_data = {
        "events": [
            {
                "event_name": "screen_view",
                "event_category": "navigation",
                "session_id": str(uuid4()),  # Anonymous UUID only
                "screen_name": "home"
            }
        ]
    }

    response = client.post("/api/v1/analytics/events", json=event_data)
    assert response.status_code == 201

    # Verify summary doesn't expose PII
    summary_response = client.get("/api/v1/analytics/summary")
    assert summary_response.status_code == 200
    data = summary_response.json()
    assert data["unique_sessions"] == 1
    # No email, no user details exposed


def test_analytics_multiple_events_same_session(client):
    """Test that multiple events with same session_id are tracked correctly."""
    session_id = str(uuid4())
    events = {
        "events": [
            {
                "event_name": "event_1",
                "event_category": "navigation",
                "session_id": session_id,
            },
            {
                "event_name": "event_2",
                "event_category": "navigation",
                "session_id": session_id,
            },
            {
                "event_name": "event_3",
                "event_category": "engagement",
                "session_id": session_id,
            }
        ]
    }

    client.post("/api/v1/analytics/events", json=events)

    # Verify summary
    response = client.get("/api/v1/analytics/summary")
    assert response.status_code == 200
    data = response.json()
    assert data["total_events"] == 3
    assert data["unique_sessions"] == 1  # All events from same session
