# Architecture

How the three pieces fit together. The per-part detail lives in
[backend/](backend/README.md), [frontend/](frontend/README.md) and
[db/](db/README.md).

```
Flutter client ──── Supabase Auth ────► issues JWT
      │                                     │
      ├──── Supabase Storage (files) ◄──────┤ same JWT
      │                                     │
      └──── HTTP + Bearer JWT ──► FastAPI ──┴─► verifies token (supabase-py)
                                     │
                                     └────────► Postgres (SQLAlchemy, DATABASE_URL)
```

## Three things to internalise

1. **FastAPI is not an auth server.** It has no login, signup or refresh
   endpoint. The client authenticates against Supabase directly and attaches the
   resulting access token to every API call. FastAPI's only auth job is
   `get_current_user_id`.
2. **Supabase is used two ways, and they do not overlap.** `supabase-py` on the
   server is for token verification *only*. All reads and writes go through
   SQLAlchemy models. Querying tables through `supabase-py` bypasses the models
   and every rule in `services/` — don't ([decisions.md](decisions.md) D10).
3. **Storage is client-direct.** The client uploads an avatar to the
   `profile_image` bucket and a file attachment to `submissions` itself, then
   sends only the resulting path or URL to the API. **The server never proxies
   file bytes.**

One consequence of (3): `users.image_url` holds a storage *path*
(`<uid>/<epoch>.png`) and the client turns it into a URL with `getPublicUrl`,
while `attachment_url` holds a finished public URL. Code itself is neither — it
is plain text in Postgres, because it is small and belongs to the row
([decisions.md](decisions.md) D27).

## Auth flow

```
signup → Supabase sends verification email
       → user taps link → deep link io.questboard://signup-callback
       → app routes to ProfileCreate
       → POST /api/users (Bearer JWT) creates the users row, credits 100 points
       → Dashboard

reset  → resetPasswordForEmail → io.questboard://reset-callback
       → supabase_flutter emits AuthChangeEvent.passwordRecovery
       → ResetPassword screen
```

Deep links are handled in `main.dart` via `app_links`, matched on scheme
`io.questboard`. `signup-callback` navigates directly; `reset-callback`
deliberately does **not** — `supabase_flutter` parses the recovery link itself
and only then emits the event, and navigating on a timer instead raced that work
and landed on the form with no session.

**A user with a valid Supabase session but no `users` row is mid-onboarding.**
Verifying an email creates the Supabase account, not the profile row. Every entry
point therefore asks `GET /api/users/me` rather than assuming the dashboard; a
`404` means `ProfileCreate` (`app/auth/post_login_router.dart`).

## Request path

**router → service → model**, with no exceptions
([backend/README.md](backend/README.md#the-layering-rule)).

Routers do no DB work and hold no rules; they translate a service's
`ValueError` / `LookupError` / `PermissionError` into an `HTTPException`.
`routers/admin.py` is the one that swaps `get_current_user_id` for
`require_admin`, which is the only thing standing between the moderation services
and any signed-in user.

Errors are FastAPI's default shape, `{"detail": "..."}` — never invent another
([decisions.md](decisions.md) D4). The client reads `body['detail']` and turns it
into an `ApiException` whose `message` is always safe to show.

**Multi-step point operations — the bounty transfer, a vote, a hint purchase —
must run in one transaction** that updates `users.points` and inserts the
`point_transactions` row together. A half-applied economy is unrecoverable. See
[db/economy.md](db/economy.md).

## Client structure

- **Navigation** is `Navigator.push` with `MaterialPageRoute` (`appRoute()` from
  `core/motion.dart`). No router package. `Dashboard` holds an `IndexedStack`
  behind a bottom nav on a phone and a sidebar on desktop.
- **State** is `StatefulWidget` + `setState`. Services are private-constructor
  singletons wrapping Supabase or `http`.
- **Responsive**: one widget renders both layouts off `isWideLayout(context)`
  from `core/breakpoints.dart` — **900px, in one place, never a literal of your
  own** ([decisions.md](decisions.md) D33). Content sits in a `ConstrainedBox`:
  900 for lists and forms, 1400 for the dashboard shell.
- **API calls** live in `services/`, never in a widget.

## Time

Instants are **stored in UTC**. Every calendar question — which challenge is
today's, how many days old one is, whether a streak survived, whether a
Codeforces submission is recent enough — is answered in **Asia/Dhaka** (UTC+6, no
DST).

`server/app/core/clock.py` is the only place the server reads a wall clock, and
`client/lib/core/app_time.dart` mirrors it. Naive `timestamp` columns serialise
with no zone marker, so the client must read an unzoned string as UTC —
`DateTime.parse` would read it as local and render everything six hours out
([decisions.md](decisions.md) D29).

## Codeforces

Read-only, by their design. The public API exposes problem *metadata* and
submission *verdicts* — there is no submit method and no statement method. So:

- QuestBoard **never posts** to Codeforces. It serves `source_url` and
  `submit_url`, and the client hosts those two Codeforces pages in an in-app
  WebView where one exists (Android/iOS/macOS), falling back to a real browser
  elsewhere. The user submits on Codeforces' own form, under their own session,
  and QuestBoard never sees a Codeforces credential
  ([decisions.md](decisions.md) D43).
- The **statement** is a scrape, sanitised server-side and cached forever on
  `daily_challenges.statement`. It fails far more often in production than in
  development — Cloudflare reads a datacenter IP as a robot and a phone's as a
  person — so the phone reads the page itself when the server cannot
  ([decisions.md](decisions.md) D45, D47).
- A solve is proved by a **verdict**, checked server-side against the user's
  public submissions, bounded below by the challenge's own Dhaka midnight (D31).

## Environments

| File | Keys |
|---|---|
| `client/.env` | `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_URL` |
| `server/.env` | `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, optional `CORS_ORIGINS` and the AI provider keys |

`API_URL` is the deployed HTTPS URL. It also accepts a comma-separated candidate
list for local server work — the client probes them all and keeps whichever
answers — but a LAN address breaks whenever the network changes and a release APK
cannot use one at all, so plain HTTPS is the default. Bind uvicorn to `0.0.0.0`
or a phone can never reach it.

Real `.env` files are gitignored; keep `.env.example` in sync when adding a key.
Full walkthrough: [setup.md](setup.md).
