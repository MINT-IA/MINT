"""
Session model - stores wizard session data.
"""

import json
from uuid import uuid4
from datetime import datetime
from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.types import TypeDecorator, TEXT
from app.core.database import Base


class JSONEncodedDict(TypeDecorator):
    """Represents an immutable structure as a json-encoded string."""
    impl = TEXT
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None:
            value = json.dumps(value)
        return value

    def process_result_value(self, value, dialect):
        if value is not None:
            value = json.loads(value)
        return value


class SessionModel(Base):
    """Session table - stores wizard session data."""
    __tablename__ = "sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    profile_id = Column(String, ForeignKey("profiles.id"), nullable=False, index=True)
    data = Column(MutableDict.as_mutable(JSONEncodedDict), nullable=False)  # Store full session data as JSON
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    profile = relationship("ProfileModel", back_populates="sessions")
