import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.core.database import Base, engine
from app.api.v1.router import api_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create database tables and auto-ingest RAG knowledge base on startup."""
    # Import models to ensure they're registered with Base
    from app.models import User, ProfileModel, SessionModel, AnalyticsEvent
    Base.metadata.create_all(bind=engine)

    # Auto-ingest education inserts into RAG vector store if empty
    _auto_ingest_rag()
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    version="0.1.0",
    lifespan=lifespan,
)

# Setup CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For MVP/Local dev. In production, restrict this.
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _auto_ingest_rag():
    """
    Auto-ingest education inserts into the RAG vector store if it's empty.

    This runs at startup and is a no-op if:
    - RAG dependencies are not installed
    - The vector store already has documents
    - The education inserts directory doesn't exist
    """
    try:
        from app.services.rag import RAG_AVAILABLE

        if not RAG_AVAILABLE:
            logger.info("RAG dependencies not installed, skipping auto-ingest")
            return

        from app.services.rag.vector_store import MintVectorStore
        from app.services.rag.ingester import MarkdownIngester

        # Determine paths
        backend_dir = os.path.dirname(os.path.dirname(__file__))
        persist_dir = os.path.join(backend_dir, "data", "chromadb")
        # Education inserts are at: ../../education/inserts/ relative to backend dir
        inserts_dir = os.path.normpath(
            os.path.join(backend_dir, "..", "..", "education", "inserts")
        )

        if not os.path.isdir(inserts_dir):
            logger.info(
                "Education inserts directory not found at %s, skipping auto-ingest",
                inserts_dir,
            )
            return

        # Initialize vector store
        vector_store = MintVectorStore(persist_directory=persist_dir)

        # Only ingest if the store is empty
        if vector_store.count() > 0:
            logger.info(
                "Vector store already has %d documents, skipping auto-ingest",
                vector_store.count(),
            )
            return

        # Ingest education inserts (language auto-detected from filenames)
        ingester = MarkdownIngester(vector_store=vector_store)
        count = ingester.ingest_directory(inserts_dir)
        logger.info("Auto-ingested %d document chunks from education inserts", count)

    except Exception as e:
        # Non-fatal: RAG is optional, don't block app startup
        logger.warning("RAG auto-ingest failed (non-fatal): %s", e)


app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {"msg": "Welcome to Mint API"}
