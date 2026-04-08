"""
Magic link authentication service.

Provides passwordless login via email magic links:
- Token generation (secrets.token_urlsafe, SHA-256 hashed storage)
- Token verification (single-use, 15-min expiry)
- Email sending via Resend API (graceful fallback if no API key)
"""

import hashlib
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import httpx
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.magic_link_token import MagicLinkTokenModel
from app.models.user import User

logger = logging.getLogger(__name__)

# Token expiry: 15 minutes
MAGIC_LINK_EXPIRY_MINUTES = 15


class MagicLinkService:
    """Service for magic link token lifecycle."""

    def __init__(self, db: Session):
        self.db = db

    def generate_token(self, email: str) -> str:
        """
        Generate a magic link token for the given email.

        Creates a cryptographically secure token, stores its SHA-256 hash
        in the database with a 15-minute expiry.

        Args:
            email: User's email address (does not need to exist yet).

        Returns:
            Raw token string (to be sent via email). Never stored in plaintext.
        """
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

        record = MagicLinkTokenModel(
            id=str(uuid4()),
            email=email.lower().strip(),
            token_hash=token_hash,
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=MAGIC_LINK_EXPIRY_MINUTES),
            used=False,
            created_at=datetime.now(timezone.utc),
        )
        self.db.add(record)
        self.db.commit()

        return raw_token

    def verify_token(self, token: str) -> User:
        """
        Verify a magic link token and return the associated user.

        - Checks token exists (by SHA-256 hash lookup)
        - Checks not expired
        - Checks not already used
        - Marks as used (single-use)
        - Returns existing user or auto-creates new user (frictionless onboarding)

        Args:
            token: Raw token string from the magic link URL.

        Returns:
            User object (existing or newly created).

        Raises:
            HTTPException(401): Token invalid, expired, or already used.
        """
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        record = self.db.query(MagicLinkTokenModel).filter(
            MagicLinkTokenModel.token_hash == token_hash
        ).first()

        if record is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Lien invalide ou expiré",
            )

        if record.used:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Ce lien a déjà été utilisé",
            )

        if record.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Ce lien a expiré",
            )

        # Mark as used (single-use)
        record.used = True
        record.used_at = datetime.now(timezone.utc)
        self.db.commit()

        # Find or create user
        user = self.db.query(User).filter(
            User.email == record.email
        ).first()

        if user is None:
            # Auto-create user (frictionless onboarding per T-01-06)
            user = User(
                id=str(uuid4()),
                email=record.email,
                hashed_password="",  # No password for magic-link-only users
                email_verified=True,  # Email ownership proven by magic link
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
            logger.info("Auto-created user via magic link: %s", user.id)

        return user

    def send_magic_link_email(self, email: str, token: str) -> None:
        """
        Send the magic link email via Resend API.

        Gracefully degrades if RESEND_API_KEY is not set (dev mode):
        logs the token instead of sending email.

        Args:
            email: Recipient email address.
            token: Raw magic link token.
        """
        api_key = os.environ.get("RESEND_API_KEY")
        base_url = os.environ.get("MAGIC_LINK_BASE_URL", "https://mint-app.ch/auth/verify")

        if not api_key:
            logger.warning(
                "RESEND_API_KEY not set — magic link NOT sent. "
                "Dev mode: token=%s for email=%s",
                token[:8] + "...",
                email,
            )
            return

        magic_link_url = f"{base_url}?token={token}"

        try:
            response = httpx.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "from": "MINT <noreply@mint-app.ch>",
                    "to": [email],
                    "subject": "Ton lien de connexion MINT",
                    "html": (
                        f"<p>Salut\u00a0!</p>"
                        f"<p>Clique sur le lien ci-dessous pour te connecter\u00a0:</p>"
                        f'<p><a href="{magic_link_url}">Se connecter à MINT</a></p>'
                        f"<p>Ce lien expire dans 15 minutes et ne peut être utilisé qu'une fois.</p>"
                        f"<p>Si tu n'as pas demandé ce lien, ignore cet email.</p>"
                    ),
                },
                timeout=10.0,
            )
            if response.status_code >= 400:
                logger.error(
                    "Resend API error %d: %s",
                    response.status_code,
                    response.text[:200],
                )
        except Exception as exc:
            logger.error("Failed to send magic link email: %s", exc)
