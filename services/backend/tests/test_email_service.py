"""
Tests for email service safety behavior.
"""

from app.core.config import settings
from app.services.email_service import (
    send_email_verification_email,
    send_password_reset_email,
)


def test_email_service_returns_false_when_disabled():
    prev_enabled = settings.EMAIL_SEND_ENABLED
    settings.EMAIL_SEND_ENABLED = False
    try:
        sent_verify = send_email_verification_email(
            to_email="user@example.com",
            token="token-123",
        )
        sent_reset = send_password_reset_email(
            to_email="user@example.com",
            token="token-456",
        )
        assert sent_verify is False
        assert sent_reset is False
    finally:
        settings.EMAIL_SEND_ENABLED = prev_enabled


def test_email_service_returns_false_when_smtp_missing():
    prev_enabled = settings.EMAIL_SEND_ENABLED
    prev_host = settings.SMTP_HOST
    settings.EMAIL_SEND_ENABLED = True
    settings.SMTP_HOST = ""
    try:
        sent = send_email_verification_email(
            to_email="user@example.com",
            token="token-789",
        )
        assert sent is False
    finally:
        settings.EMAIL_SEND_ENABLED = prev_enabled
        settings.SMTP_HOST = prev_host
