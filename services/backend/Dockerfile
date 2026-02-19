# Multi-stage build for MINT API
# Stage 1: Install dependencies (cached layer)
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy full source so pip can resolve the package
COPY . .
RUN pip install --no-cache-dir .

# Stage 2: Production image (slim, no build tools)
FROM python:3.12-slim AS production
WORKDIR /app

COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .

EXPOSE 8888

# Use python for healthcheck (curl not available in slim image)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8888/api/v1/health')" || exit 1

CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8888", "--access-logfile", "-"]
