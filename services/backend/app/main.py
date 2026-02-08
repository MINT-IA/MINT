from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import Base, engine
from app.api.v1.router import api_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    version="0.1.0",
)

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For MVP/Local dev. In production, restrict this.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def on_startup():
    """Create database tables on startup."""
    # Import models to ensure they're registered with Base
    from app.models import User, ProfileModel, SessionModel
    Base.metadata.create_all(bind=engine)


app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {"msg": "Welcome to Mint API"}
