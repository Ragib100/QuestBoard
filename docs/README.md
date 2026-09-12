# QuestBoard documentation

Everything written down about this project, split by the part of the system it
describes. **The code is the source of truth** — if a document and the code
disagree, the code wins and the document is the bug (ground rule 3 in
`CLAUDE.md`). Every page here was verified against the files it describes.

## Start here

| If you want to… | Read |
|---|---|
| Get the app running on your machine | [setup.md](setup.md) |
| Know what we are building and why | [product.md](product.md) |
| See how the three pieces fit together | [architecture.md](architecture.md) |
| Understand why something is the way it is | [decisions.md](decisions.md) |
| Know what is done and what is next | [../TASKS.md](../TASKS.md) |
| Record the demo video | [demo-script.md](demo-script.md) |

## Backend — [`docs/backend/`](backend/)

The FastAPI server in `server/`.

| File | Covers |
|---|---|
| [backend/README.md](backend/README.md) | Overview, layering rule, commands, file map |
| [backend/api.md](backend/api.md) | **The endpoint contract** — every route, body, status code |
| [backend/routers.md](backend/routers.md) | Every router file and the endpoints it declares |
| [backend/services.md](backend/services.md) | Every service class, its methods, and the rules it enforces |
| [backend/models.md](backend/models.md) | Every SQLAlchemy model, column and module constant |
| [backend/schemas.md](backend/schemas.md) | Every Pydantic schema and its validation rules |
| [backend/core.md](backend/core.md) | Config, clock, Supabase client, DB session, auth dependencies, serializers |
| [backend/testing.md](backend/testing.md) | How `pytest` runs against the live database, and what is covered |

## Frontend — [`docs/frontend/`](frontend/)

The Flutter client in `client/`.

| File | Covers |
|---|---|
| [frontend/README.md](frontend/README.md) | Overview, state and navigation rules, commands, file map |
| [frontend/screens.md](frontend/screens.md) | Every screen: what it shows, what it calls, where it goes next |
| [frontend/services.md](frontend/services.md) | `ApiClient`, every service singleton, every model class |
| [frontend/core.md](frontend/core.md) | `core/` helpers — breakpoints, time, names, links, Codeforces WebView, the code engine |
| [frontend/widgets.md](frontend/widgets.md) | Every shared widget in `core/widgets/` |
| [frontend/design-system.md](frontend/design-system.md) | Colors, type, spacing, motion, the four screen states |
| [frontend/testing.md](frontend/testing.md) | The seven test files and what each one guards |

## Database — [`docs/db/`](db/)

Postgres on Supabase. `server/schema.sql` is the runnable copy.

| File | Covers |
|---|---|
| [db/README.md](db/README.md) | How the schema is applied, conventions, storage buckets |
| [db/schema.md](db/schema.md) | **Every table and every column**, live vs. planned |
| [db/economy.md](db/economy.md) | The point ledger: reasons, invariants, and every path that moves points |
| [db/indexes-and-rls.md](db/indexes-and-rls.md) | Indexes, trigram search, the `updated_at` trigger, Row Level Security |

## Conventions used in these docs

- **quest** is the product word; `question` is the schema word. The table, the
  ORM model, the JSON keys and the route all say `question`
  ([decisions.md](decisions.md) D1).
- ✅ live · ⬜ planned · ❌ dropped, with the reason so it is not re-proposed.
- Every claim about behaviour names the file that implements it, so it can be
  checked in one jump.
