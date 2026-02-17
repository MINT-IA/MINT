"""
Profile model - stores user profiles with all data as JSON.
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


class ProfileModel(Base):
    """Profile table - stores full profile data as JSON."""
    __tablename__ = "profiles"

    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=True)  # Nullable for anonymous profiles
    data = Column(MutableDict.as_mutable(JSONEncodedDict), nullable=False)  # Store full profile as JSON
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="profiles")
    sessions = relationship("SessionModel", back_populates="profile", cascade="all, delete-orphan")
