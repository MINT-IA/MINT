"""
Transactional email service (SMTP).
"""

from __future__ import annotations

import logging
import smtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger(__name__)


def _send_email(*, to_email: str, subject: str, body_text: str) -> bool:
    """
    Send a plaintext email through SMTP.
    Returns False when email sending is disabled or SMTP is not configured.
    """
    if not settings.EMAIL_SEND_ENABLED:
        logger.info("Email sending disabled; skipping email to %s", to_email)
        return False
    if not settings.SMTP_HOST or not settings.EMAIL_FROM:
        logger.warning("SMTP not configured; cannot send email to %s", to_email)
        return False

    msg = EmailMessage()
    msg["From"] = settings.EMAIL_FROM
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body_text)

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as smtp:
            if settings.SMTP_USE_TLS:
                smtp.starttls()
            if settings.SMTP_USERNAME:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            smtp.send_message(msg)
        return True
    except Exception as exc:
        logger.warning("SMTP send failed for %s: %s", to_email, exc)
        return False


def send_password_reset_email(*, to_email: str, token: str) -> bool:
    reset_link = f"{settings.FRONTEND_BASE_URL}/auth/reset-password?token={token}"
    return _send_email(
        to_email=to_email,
        subject="MINT — Réinitialisation de ton mot de passe",
        body_text=(
            "Tu as demandé une réinitialisation de mot de passe.\n\n"
            f"Utilise ce lien: {reset_link}\n"
            "Ce lien expire dans 60 minutes.\n\n"
            "Si tu n'es pas à l'origine de cette demande, ignore ce message."
        ),
    )


def send_email_verification_email(*, to_email: str, token: str) -> bool:
    verify_link = f"{settings.FRONTEND_BASE_URL}/auth/verify-email?token={token}"
    return _send_email(
        to_email=to_email,
        subject="MINT — Vérifie ton adresse e-mail",
        body_text=(
            "Bienvenue sur MINT.\n\n"
            f"Vérifie ton e-mail via ce lien: {verify_link}\n"
            "Ce lien expire dans 24 heures.\n\n"
            "Si tu n'es pas à l'origine de ce compte, ignore ce message."
        ),
    )
