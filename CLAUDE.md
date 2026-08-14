# QuestBoard

Gamified Q&A app for STEM students. Users post **quests** (questions with a point
bounty), others answer, the author accepts the best answer and the bounty transfers.
University group project (4 members), ~10 weeks.

**Stack:** Flutter (client) · FastAPI + SQLAlchemy (server) · Supabase (Postgres, Auth, Storage)

## Commands

```bash
# Server (run first — client needs it)
cd server && source .venv/bin/activate && uvicorn app.main:app --reload
ruff check app && black app          # lint + format

# Client
cd client && flutter run -d linux    # or: -d chrome, -d <android-device-id>
flutter analyze && flutter test
```

Both need a `.env` (see `.env.example` in each dir). Server runs on `:8000`;
Android emulator reaches it at `http://10.0.2.2:8000`.

## Layout

```
server/app/
  main.py              FastAPI app, mounts /api
  core/                config (pydantic-settings), supabase client
  db/                  SQLAlchemy engine + Base
  models/              SQLAlchemy ORM models
  schemas/             Pydantic request/response models
  routers/             HTTP endpoints (thin — delegate to services)
  services/            business logic
  dependencies/auth.py get_current_user_id — verifies Supabase JWT
client/lib/
  main.dart            app entry, theme, deep-link handling
  config/              env-backed config
  services/common/     auth_service, user_service, supabase_services (singletons)
  app/auth/            login, signup, forgot_password, email_verification
  app/profile/         profile_create (post-signup onboarding)
  app/modules/         questions, leaderboard, daily_challenge, notifications, profile
  app/admin/           admin screens (UI only, no backend yet)
```

## Conventions

- **Terminology:** a question is a **quest** everywhere — table `quests`, model `Quest`,
  route `/api/quests`, UI "Browse Quests". Never "question" in new code.
- **Auth:** the Flutter client talks to Supabase Auth directly (`supabase_flutter`).
  FastAPI never issues tokens — it only verifies the bearer JWT via
  `Depends(get_current_user_id)` and trusts the `sub` claim.
- **Errors:** plain FastAPI. Raise `HTTPException(status_code=..., detail="message")`;
  the client reads `body['detail']`. Do not invent a custom error envelope.
- **Server layering:** router → service → model. Routers do no DB work.
- **Client state:** `StatefulWidget` + `setState`, `Navigator` (no router package),
  `package:http`. No Riverpod / GoRouter / Dio — do not add them.
- **Theme:** light, blue `#0066FF`, Inter/Outfit via `google_fonts`. See
  [docs/design-system.md](docs/design-system.md). Do not use the old dark-navy palette.
- **Branching:** feature branches, PR review before merge, `main` always deployable.

## Docs (read on demand — do not preload)

| File | Read it when |
|---|---|
| [TASKS.md](TASKS.md) | Starting any work — what's done, what's next. Update it when you finish something. |
| [docs/product.md](docs/product.md) | Deciding scope, point-economy rules, what is out of scope |
| [docs/architecture.md](docs/architecture.md) | Adding an endpoint, screen, or changing auth/data flow |
| [docs/data-model.md](docs/data-model.md) | Touching the DB — canonical schema, live vs. planned tables |
| [docs/api.md](docs/api.md) | Wiring client↔server — endpoint contract + implementation status |
| [docs/design-system.md](docs/design-system.md) | Building UI — colors, type, spacing, components |
| [docs/decisions.md](docs/decisions.md) | Something in the code contradicts your assumption — the "why" lives here |

## Ground rules

1. **API contract first.** Add the endpoint to `docs/api.md` before building the screen
   that consumes it.
2. **No gold plating.** Finish all Tier 1 (MVP) items in `TASKS.md` before starting Tier 2.
3. **Keep docs true.** If code and docs disagree, the code wins — fix the doc in the same PR.
