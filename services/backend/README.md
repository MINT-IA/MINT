# Mint Backend

FastAPI implementation for Mint.

## First-run (local dev)

### 1. Python env

```bash
cd services/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

Minimum Python 3.11. Python 3.9 works for most endpoints but fails some
FastAPI generics introduced in 3.11 — prefer `python3.11 -m venv`.

### 2. Environment variables

Copy `.env.example` to `.env` and set at minimum:

```bash
cp .env.example .env
```

| Var | Required for | Default | Notes |
|-----|--------------|---------|-------|
| `ANTHROPIC_API_KEY` | Coach chat + anonymous chat | (unset) | **Without this, anonymous chat returns 503 "Service temporairement indisponible."** Get key at [console.anthropic.com](https://console.anthropic.com). |
| `DATABASE_URL` | All endpoints | `postgresql://mint:mint@localhost:5432/mint` | Use `sqlite:///./mint.db` for zero-setup local dev. |
| `REDIS_URL` | Rate limiting | `redis://localhost:6379/0` | Leave empty for in-memory fallback (dev only). |
| `JWT_SECRET_KEY` | Auth endpoints | `change-me-in-production` | Generate via `openssl rand -hex 32`. |
| `ENVIRONMENT` | CORS + strictness | `development` | `production` enables stricter CORS, mandatory HTTPS, etc. |

See `.env.example` for the full list. Email + Sentry vars are optional
for local dev (email delivery off by default, Sentry DSN unset → no
event transmission).

### 3. Run

```bash
uvicorn app.main:app --reload --host 127.0.0.1 --port 8888
```

The mobile app's debug build hardcodes `http://localhost:8888/api/v1`
as the default base URL. Use port 8888 to avoid reconfiguring.

### 4. Verify

```bash
curl -s http://127.0.0.1:8888/                 # {"msg": "Welcome to Mint API"}
curl -s http://127.0.0.1:8888/api/v1/health    # 200 OK
curl -sv -X POST http://127.0.0.1:8888/api/v1/anonymous/chat \
  -H "Content-Type: application/json" \
  -H "X-Anonymous-Session: $(uuidgen | tr A-Z a-z)" \
  -d '{"message":"bonjour","language":"fr"}'    # 200 if ANTHROPIC_API_KEY set,
                                                # 503 if missing (expected)
```

## Common gotchas

- **`503 Service temporairement indisponible.`** — `ANTHROPIC_API_KEY`
  not set in env. Coach cannot respond. Anonymous chat will always fail
  until you set a valid key.
- **`400 Format de session invalide. UUID requis.`** — The mobile app
  generates a valid UUID v4 for `X-Anonymous-Session` automatically.
  Only happens when calling the endpoint manually with a non-UUID string.
- **Port 8000 already in use** — FastAPI default is 8000, but the mobile
  app expects 8888. Always pass `--port 8888` to `uvicorn`.
- **SSL / TLS errors on Railway** — production TLS termination is handled
  by Railway. Local dev uses plain HTTP. Don't try to enable TLS locally.

## Tests

```bash
python3 -m pytest tests/ -q
```

## Migrations

Alembic drives schema migrations. See `alembic/` + `alembic.ini`.
