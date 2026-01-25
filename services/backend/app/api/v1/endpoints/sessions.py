"""
Sessions endpoint - Advisor guided sessions.
"""

import uuid
from datetime import datetime
from typing import Dict
from fastapi import APIRouter, HTTPException
from pydantic import UUID4
from app.schemas.session import Session, SessionCreate, SessionReport
from app.api.v1.endpoints.profiles import _profiles
from app.services.rules_engine import generate_session_report, recommend_goal_template

router = APIRouter()

# In-memory store for MVP
_sessions: Dict[UUID4, Session] = {}


@router.post("", response_model=Session)
def create_session(session_create: SessionCreate) -> Session:
    """Create a new guide session."""
    if session_create.profileId not in _profiles:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile = _profiles[session_create.profileId]
    recommended_goal_id, _ = recommend_goal_template(profile, session_create.answers)

    session_id = uuid.uuid4()
    session = Session(
        id=session_id,
        profileId=session_create.profileId,
        createdAt=datetime.utcnow(),
        answers=session_create.answers,
        selectedFocusKinds=session_create.selectedFocusKinds,
        recommendedGoalTemplateId=recommended_goal_id,
        selectedGoalTemplateId=session_create.selectedGoalTemplateId,
    )
    _sessions[session_id] = session
    return session


@router.get("/{session_id}/report", response_model=SessionReport)
def get_session_report(session_id: UUID4) -> SessionReport:
    """Generate and get the report for a session."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    profile = _profiles[session.profileId]

    report = generate_session_report(
        profile, session.answers, session.selectedFocusKinds, session_id
    )
    return report
