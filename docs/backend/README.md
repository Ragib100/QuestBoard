# Backend

FastAPI + SQLAlchemy, in `server/`. It serves JSON under `/api`, verifies
Supabase tokens, and owns every business rule in the product. It is **not** an
auth server: it issues no tokens and has no login endpoint.

```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0   # http://localhost:8000, OpenAPI at /docs

ruff check app && black app                     # lint + format — both must be clean
pytest                                          # needs a live DATABASE_URL
```

Bind to `0.0.0.0`, not the default `127.0.0.1`, or a phone on the same network
can never reach it.

## The layering rule

**router → service → model.** There are no exceptions.

| Layer | Does | Never does |
|---|---|---|
| `routers/` | Path, method, status code, dependency injection, turning service exceptions into `HTTPException` | Touch the database, hold business rules |
| `services/` | All logic. Takes a `Session`, raises `ValueError` / `LookupError` / `PermissionError` on a domain violation | Know about HTTP, import FastAPI |
| `models/` | SQLAlchemy ORM rows and the constants that describe them | Contain query logic |
| `schemas/` | Pydantic request and response shapes, one per direction | Read the database |

Services raise plain Python exceptions and the router maps them:

| Service raises | Router returns |
|---|---|
| `LookupError` | `404` |
| `PermissionError` | `403` (and `429` in `ai.py`, where it means the hourly cap) |
| `ValueError` | `400`, or `402` when the message mentions points, or `409` on a conflict |
| `AiHintError` | `503` |
| `CodeforcesError` | `502` |

Pydantic validation failures come back as FastAPI's own `422`.

## Two rules that are not negotiable

1. **Points move only through `PointService`.** It is the only writer of
   `users.points`, and it writes a `point_transactions` row in the same unit of
   work. See [../db/economy.md](../db/economy.md).
2. **Services flush, never commit** — except at the top of a request-scoped
   operation. The caller owns the transaction, which is what lets a bounty
   transfer debit one account and credit another atomically
   ([../decisions.md](../decisions.md) D20).

## File map

```
server/
  app/
    main.py                  FastAPI app, CORS, /api mount, GET /api/ and /api/ping
    core/
      config.py              pydantic-settings — the only reader of .env
      clock.py               the one wall clock, pinned to Asia/Dhaka
      supabase.py            supabase-py client, used only to verify tokens
    db/
      base.py                DeclarativeBase
      database.py            engine, SessionLocal, get_db dependency
    dependencies/
      auth.py                get_current_user_id, get_optional_user_id
      admin.py               require_admin
    models/                  SQLAlchemy ORM — see models.md
    schemas/                 Pydantic in/out shapes — see schemas.md
    routers/                 HTTP endpoints — see routers.md
    services/                business logic — see services.md
    utils/serialize.py       ORM row + computed counts → response schema
  tests/                     pytest against the real database — see testing.md
  schema.sql                 the live tables, runnable in the Supabase SQL editor
  seed_demo.py               demo data for the recording
  requirements.txt
```

## Configuration

`app/core/config.py` is the **only** place that reads the environment. Nothing
else calls `os.environ`.

| Key | Required | Default | Used for |
|---|---|---|---|
| `DATABASE_URL` | yes | — | SQLAlchemy engine (the Supabase pooler connection string) |
| `SUPABASE_URL` | yes | — | Token verification |
| `SUPABASE_PUBLISHABLE_KEY` | yes | — | Token verification |
| `CORS_ORIGINS` | no | `*` | Comma-separated browser origins. Flutter web cannot call the API without it |
| `AI_BASE_URL` | no | `""` | Any OpenAI-compatible `/chat/completions` endpoint — Gemini, Groq, OpenRouter, Cerebras |
| `AI_API_KEY` | no | `""` | Key for the above |
| `AI_MODEL` | no | `""` | Model name for the above |
| `ANTHROPIC_API_KEY` | no | `""` | Fallback provider |
| `ANTHROPIC_MODEL` | no | `claude-opus-5` | Fallback model |

`AI_BASE_URL` takes precedence when set, so a paid Anthropic key can sit in
`.env` without being used. With no provider at all, `GET /api/ai/hint` reports
`available: false` and `POST` returns `503` — the client hides the button rather
than faking one ([../setup.md](../setup.md) step 10).

## Where to read next

- The contract the client codes against: [api.md](api.md)
- Endpoint declarations, one file at a time: [routers.md](routers.md)
- What actually happens: [services.md](services.md)
- The rows underneath: [models.md](models.md) and [../db/schema.md](../db/schema.md)
