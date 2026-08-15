# Architecture

```
Flutter client ──── Supabase Auth ────► issues JWT
      │                                     │
      ├──── Supabase Storage (avatars) ◄────┤ same JWT
      │                                     │
      └──── HTTP + Bearer JWT ──► FastAPI ──┴─► verifies token (supabase-py)
                                     │
                                     └────────► Postgres (SQLAlchemy, DATABASE_URL)
```

Three things to internalise:

1. **FastAPI is not an auth server.** It has no login, signup or refresh endpoint. The
   client authenticates against Supabase directly and attaches the resulting access
   token to every API call. FastAPI's only auth job is `get_current_user_id`.
2. **Supabase is used two ways, and they don't overlap.** `supabase-py` on the server is
   for token verification *only*. All reads and writes go through SQLAlchemy models.
   Querying tables through `supabase-py` bypasses the models — don't.
3. **Storage is client-direct.** The client uploads an avatar to the `profile_image`
   bucket itself and sends only the resulting *path* to the API. The server never
   proxies file bytes.

## Auth flow

```
signup → Supabase sends verification email
       → user taps link → deep link io.questboard://signup-callback
       → app routes to ProfileCreate
       → POST /api/users (Bearer JWT) creates the users row, credits 100 points
       → Dashboard

reset  → resetPasswordForEmail → io.questboard://reset-callback → ResetPassword screen
```

Deep links are handled in `main.dart` via `app_links`, matched on scheme
`io.questboard` and host (`signup-callback`, `reset-callback`). A user with a valid
Supabase session but no `users` row is mid-onboarding — send them to `ProfileCreate`,
not the dashboard.

## Server

Request path is always **router → service → model**.

- `routers/` — path, status code, `Depends(get_current_user_id)`, and translating
  service `ValueError`s into `HTTPException`. No DB access, no business rules.
  `routers/admin.py` is the exception to nothing: it swaps that dependency for
  `Depends(require_admin)`, which is the only thing standing between the moderation
  services and any signed-in user.
- `services/` — static-method classes (`QuestService`, `UserService`) holding the
  logic. They take a `Session` and raise `ValueError` on domain violations.
- `models/` — SQLAlchemy ORM. `schemas/` — Pydantic in/out shapes, one per direction
  (`QuestCreate` / `QuestResponse`).
- Config is `pydantic-settings` reading `.env` (`DATABASE_URL`, `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`). Never read `os.environ` directly. Optional keys —
  the AI provider — default to empty, and the feature checks rather than assumes.

Everything mounts under `/api`. Multi-step point operations (bounty transfer, vote,
hint purchase) must run in **one** `db` transaction that updates `users.points` and
inserts the `point_transactions` row together — a half-applied economy is unrecoverable.

## Client

- **Navigation:** `Navigator.push` with `MaterialPageRoute`. `Dashboard` holds an
  `IndexedStack` behind a bottom nav (mobile) or sidebar (web, `width > 960`).
- **State:** `StatefulWidget` + `setState`. Services are private-constructor singletons
  (`AuthService.instance`) wrapping Supabase or `http`.
- **Responsive:** every screen checks `MediaQuery` width and renders a mobile or web
  layout from one widget. Content is centred inside a `ConstrainedBox` (900 for lists,
  1400 for the shell). Keep this pattern — the app is graded on web *and* Android.
- **API calls** live in `services/`, never in a widget. Base URL comes from
  `dotenv.get('API_URL')`. Attach
  `Authorization: Bearer ${_supabase.auth.currentSession?.accessToken}`; if the session
  is null, throw — do not send an unauthenticated request.

## Environments

`client/.env`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_URL`.
`server/.env`: `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`.

`API_URL` differs per target: `http://10.0.2.2:8000` (Android emulator),
`http://<lan-ip>:8000` (physical device), `http://localhost:8000` (desktop/web).
Real `.env` files are gitignored; keep `.env.example` in sync when adding a key.
