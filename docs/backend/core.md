# Core, database and dependencies

The small modules everything else leans on: `app/core/`, `app/db/`,
`app/dependencies/` and `app/utils/`.

## `core/config.py` — settings

A `pydantic-settings` `BaseSettings` reading `.env`, with `extra="ignore"`. It is
the **only** place in the server that reads the environment; nothing else calls
`os.environ`.

Keys and defaults are tabulated in [README.md](README.md#configuration).

`settings.cors_origins` is a property that splits `CORS_ORIGINS` on commas and
drops blanks, so `main.py` gets a `list[str]`.

Optional keys default to empty strings, and the feature **checks** rather than
assumes: `AiService.is_configured()` is what decides whether the hint endpoint
works, and the client hides the button when it reports `available: false`.

## `core/clock.py` — the one wall clock

Everything user-facing happens in Bangladesh: the daily challenge rolls over at
midnight Dhaka, a streak counts a Dhaka day, and the age decay counts Dhaka days.
Reading `datetime.now(timezone.utc)` instead meant the challenge changed at 6am
local and a solve at 1am counted for the day before — the class of bug that only
shows up on the wrong side of midnight
([../decisions.md](../decisions.md) D29).

```python
DHAKA = timezone(timedelta(hours=6), "Asia/Dhaka")
```

Asia/Dhaka is UTC+6 and has had no DST since 2009, so a fixed offset is the whole
truth and needs no tz database on the deploy host.

| Function | Returns |
|---|---|
| `now()` | The current instant, expressed in Bangladesh time |
| `today()` | The calendar day it is in Bangladesh right now |
| `utc_now()` | The current instant in UTC, for comparing against stored timestamps |
| `naive_utc_now()` | The same with tzinfo stripped, for our naive `timestamp` columns |
| `start_of_day(day)` | Midnight in Dhaka on `day`, as an aware instant |

**Instants are still stored in UTC.** This module is about the calendar, not the
storage format. `naive_utc_now()` exists because Postgres stores those columns
without a zone, so writing an aware value would be silently truncated anyway —
doing it here makes the choice visible.

`start_of_day` is what bounds a challenge claim: "was this submitted on or after
the challenge's own day" is a question about Dhaka midnight, not UTC midnight.

The client mirrors all of this in `client/lib/core/app_time.dart`
([../frontend/core.md](../frontend/core.md#app_timedart)).

## `core/supabase.py` — the Supabase client

Four lines: a `supabase-py` `Client` built from `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`.

It is used for **token verification only**. All reads and writes go through
SQLAlchemy models. Querying tables through `supabase-py` would bypass the models
and every rule in `services/` — don't ([../decisions.md](../decisions.md) D10).

## `db/base.py` and `db/database.py`

```python
class Base(DeclarativeBase): pass

engine = create_engine(settings.DATABASE_URL, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

`autoflush=False` is why `PointService.apply` calls `db.flush()` explicitly:
without it, a badge check counting bounties later in the same transaction would
not see the row just written.

`get_db` is a FastAPI dependency — every router takes
`db: Session = Depends(get_db)`.

## `dependencies/auth.py`

```python
security          = HTTPBearer()
optional_security = HTTPBearer(auto_error=False)
```

### `get_current_user_id(credentials) -> UUID`

Calls `supabase.auth.get_user(token)` and returns `UUID(response.user.id)`. Any
failure — no user, an expired token, a network error — becomes
`401 Invalid authentication token.` The `sub` claim is trusted; FastAPI never
issues a token and has no login endpoint.

### `get_optional_user_id(credentials) -> UUID | None`

Identifies the caller when a token is present but **never rejects them**.
Browsing quests is public; the id is only needed to show whether the viewer has
already voted, so a missing or stale token means "anonymous", not `401`.

## `dependencies/admin.py`

```python
require_admin(db, user_id) -> User
```

`get_current_user_id` plus one `db.get(User, user_id)` lookup. `403 Admins only.`
when the row is missing or `is_admin` is false.

`is_admin` lives in our `users` table, not in the Supabase token, so this costs
a lookup — which is also what makes **revoking admin take effect on the next
request** rather than on the next login.

`routers/admin.py` swaps `get_current_user_id` for this on every route. It is the
only thing standing between the moderation services and any signed-in user.

## `utils/serialize.py`

Stitching ORM rows plus their computed counts into response schemas. Documented
with the schemas it produces: [schemas.md](schemas.md#utilsserializepy).

## `main.py`

```python
app = FastAPI(title="QuestBoard API", version="0.1.0")
```

CORS middleware with `allow_origins=settings.cors_origins`,
`allow_credentials=True`, and `*` for methods and headers. Flutter web runs in a
browser and is blocked without it; Android, desktop and the Flutter test harness
are unaffected either way.

Two endpoints are declared here rather than in a router:

- `GET /api/` — the liveness check. Unauthenticated, and what uptime pings,
  Render health checks and the client's own multi-candidate host probe hit.
- `GET /api/ping` — returns the caller's user id, so a token can be verified end
  to end from a terminal.

Everything else mounts on an `APIRouter(prefix="/api")`.
