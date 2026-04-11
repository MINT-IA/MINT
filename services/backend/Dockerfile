# MINT Backend — Production Dockerfile
# Multi-stage build: install deps in builder, copy to slim runtime

# --- Stage 1: Builder ---
FROM python:3.12-slim AS builder
WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

# Install deps from pyproject.toml (single source of truth)
# CRITICAL: [rag] extra includes chromadb, openai, tiktoken which are required
# by coach_chat.py / rag.py. Without this extra, the RAG orchestrator
# cannot initialize and returns 503 "RAG dependencies not installed".
COPY pyproject.toml .
COPY app/ app/
RUN pip install --no-cache-dir ".[rag]" && python -c "import anthropic, chromadb; print('anthropic', anthropic.__version__, '/ chromadb', chromadb.__version__)"

# --- Stage 2: Production ---
FROM python:3.12-slim AS production
WORKDIR /app

# libpq needed at runtime for psycopg2
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 && \
    rm -rf /var/lib/apt/lists/*

# Security: non-root user
RUN groupadd -r mint && useradd -r -g mint -d /app mint

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .

RUN chown -R mint:mint /app
USER mint

# Fly.io injects PORT env var; fallback 8080
ENV PORT=8080
EXPOSE ${PORT}

# Railway provides its own healthcheck via railway.json
CMD ["sh", "-c", "gunicorn app.main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:${PORT:-8080} --timeout 120 --access-logfile - --error-logfile -"]
