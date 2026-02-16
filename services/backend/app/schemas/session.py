from datetime import datetime
from typing import List, Optional, Any, Dict
from uuid import UUID, uuid4
from pydantic import BaseModel, Field
from app.schemas.recommendation import Recommendation, NextAction


class SessionCreate(BaseModel):
    profileId: UUID
    answers: Dict[str, Any]
    selectedFocusKinds: List[str]
    selectedGoalTemplateId: Optional[str] = None


class Session(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    profileId: UUID
    createdAt: datetime = Field(default_factory=datetime.utcnow)
    answers: Dict[str, Any]
    selectedFocusKinds: List[str]
    recommendedGoalTemplateId: str
    selectedGoalTemplateId: Optional[str] = None


class ScoreboardItem(BaseModel):
    label: str
    value: str
    note: str


class TopAction(BaseModel):
    effortTag: str = Field(..., description="5 min | 30 min | 1 semaine")
    label: str
    why: str
    ifThen: str = Field(..., description="Format SI... ALORS...")
    nextAction: NextAction


class GoalTemplate(BaseModel):
    id: str
    label: str


class SessionReportOverview(BaseModel):
    canton: str
    householdType: str
    goalRecommendedLabel: str


class ConflictOfInterest(BaseModel):
    partner: str
    type: str
    disclosure: str


class MintRoadmap(BaseModel):
    mentorshipLevel: str = "Guidance Générale (MVP)"
    natureOfService: str = "Coaching / Éducatif"
    limitations: List[str]
    assumptions: List[str]
    conflictsOfInterest: List[ConflictOfInterest] = []


class SessionReport(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    sessionId: UUID
    precisionScore: float = Field(
        ..., description="0.0 to 1.0 reflecting data completeness"
    )
    title: str
    overview: SessionReportOverview
    mintRoadmap: MintRoadmap
    scoreboard: List[ScoreboardItem] = Field(..., min_length=4, max_length=6)
    recommendedGoalTemplate: GoalTemplate
    alternativeGoalTemplates: List[GoalTemplate] = Field(..., max_length=2)
    topActions: List[TopAction] = Field(..., min_length=3, max_length=3)
    recommendations: List[Recommendation]
    disclaimers: List[str] = Field(..., min_length=3)
    generatedAt: datetime = Field(default_factory=datetime.utcnow)
