import os

from pydantic import ConfigDict
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = ConfigDict(case_sensitive=True)

    PROJECT_NAME: str = "Mint API"
    API_V1_STR: str = "/api/v1"

    # Database settings
    DATABASE_URL: str = "sqlite:///./mint.db"

    # JWT settings — env var JWT_SECRET_KEY required in production
    JWT_SECRET_KEY: str = "mint-dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_HOURS: int = 24


settings = Settings()

# Fail-fast: reject hardcoded secret in production
if (
    os.getenv("ENVIRONMENT", "development") in ("production", "staging")
    and settings.JWT_SECRET_KEY == "mint-dev-secret-change-in-production"
):
    raise RuntimeError(
        "CRITICAL: JWT_SECRET_KEY must be set via environment variable in production. "
        "Do not use the default dev secret."
    )
