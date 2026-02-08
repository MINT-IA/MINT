from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PROJECT_NAME: str = "Mint API"
    API_V1_STR: str = "/api/v1"

    # Database settings
    DATABASE_URL: str = "sqlite:///./mint.db"

    # JWT settings
    JWT_SECRET_KEY: str = "mint-dev-secret-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRY_HOURS: int = 24

    class Config:
        case_sensitive = True


settings = Settings()
