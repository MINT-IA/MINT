"""
Pydantic v2 schemas for the Coach Chat module (Sprint S56).

POST /api/v1/coach/chat — Conversational AI with Claude proxy.

Sources:
    - LSFin art. 3 (information financiere educative)
    - LPD art. 6 (protection des donnees)
"""

from typing import List, Optional

from pydantic import BaseModel, Field, ConfigDict
from pydantic.alias_generators import to_camel


class ChatBaseModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True, alias_generator=to_camel)


class ChatMessage(ChatBaseModel):
    """A single message in the conversation."""
    role: str = Field(..., description="'user' or 'assistant'")
    content: str = Field(..., description="Message text")


class CoachChatRequest(ChatBaseModel):
    """Request to the coach chat endpoint."""
    message: str = Field(..., min_length=1, max_length=2000,
                         description="User's message")
    conversation_history: List[ChatMessage] = Field(
        default_factory=list,
        description="Previous messages for context (max 20)",
    )

    # Profile context (injected into system prompt, never sent to LLM as user data)
    first_name: Optional[str] = None
    age: Optional[int] = None
    canton: Optional[str] = None
    salary_annual: Optional[float] = None
    civil_status: Optional[str] = None
    archetype: Optional[str] = None
    financial_literacy_level: Optional[str] = "intermediate"

    # Financial context
    fri_total: Optional[int] = None
    replacement_ratio: Optional[float] = None
    confidence_score: Optional[float] = None
    avoir_lpp: Optional[float] = None
    epargne_3a: Optional[float] = None
    total_dettes: Optional[float] = None

    # CapMemory context (for coach memory)
    last_cap_served: Optional[str] = None
    completed_actions: List[str] = Field(default_factory=list)
    abandoned_flows: List[str] = Field(default_factory=list)
    declared_goals: List[str] = Field(default_factory=list)


class CoachChatResponse(ChatBaseModel):
    """Response from the coach chat endpoint."""
    reply: str = Field(..., description="Coach's response")
    disclaimer: str = Field(
        default="Outil educatif. Ne constitue pas un conseil financier (LSFin).",
    )
    used_model: str = Field(default="", description="Model used for generation")
    tokens_used: int = Field(default=0, description="Total tokens consumed")
    remaining_quota: int = Field(default=-1, description="Remaining daily quota (-1=unlimited)")
