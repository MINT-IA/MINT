"""
Shared profile bootstrap helper.

Ensures every authenticated user has an empty ProfileModel immediately
after account creation, regardless of which auth path they came through
(password register, magic link, Apple Sign-In, etc.).

Without this, GET /profiles/me returns 404 forever until the mobile
client manually POSTs a profile — which it currently never does, so
every screen downstream (Aujourd'hui, Explorer, Coach) falls back to
"Crée ton compte" copy even after successful auth.

History: the helper originally lived inline in
`app/api/v1/endpoints/auth.py` and was called from /register and
/apple-signin. The magic link path never called it, so every magic
link user had a broken profile. This module centralises the logic so
all auth paths share the same bootstrap.
"""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.profile_model import ProfileModel


def ensure_empty_profile(db: Session, user_id: str, *, commit: bool = False) -> None:
    """Auto-create an empty ProfileModel for a freshly-created user.

    Idempotent: no-op if the user already has at least one profile.

    Args:
        db: SQLAlchemy session.
        user_id: The user whose profile should exist.
        commit: If True, commit the insertion immediately. Defaults to
            False so callers that are already inside a larger transaction
            (e.g. /register, /apple-signin) can batch their commits.
            Magic link verify uses commit=True because it stands alone.
    """
    existing = (
        db.query(ProfileModel).filter(ProfileModel.user_id == user_id).first()
    )
    if existing is not None:
        return

    now = datetime.now(timezone.utc)
    profile_id = str(uuid4())
    profile_data = {
        "id": profile_id,
        "createdAt": now.isoformat(),
        "householdType": "single",
        "hasDebt": False,
        "goal": "other",
        "factfindCompletionIndex": 0.0,
        "isChurchMember": False,
    }
    profile = ProfileModel(
        id=profile_id,
        user_id=user_id,
        data=profile_data,
        created_at=now,
        updated_at=now,
    )
    db.add(profile)
    if commit:
        db.commit()
