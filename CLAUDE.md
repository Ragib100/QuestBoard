# QuestBoard

Gamified Q&A app for STEM students. Users post **quests** (questions with a point
bounty), others answer, the author accepts the best answer and the bounty transfers.
University group project (4 members), ~10 weeks.

**Stack:** Flutter (client) · FastAPI + SQLAlchemy (server) · Supabase (Postgres, Auth, Storage)

## Commands

```bash
# Server (run first — client needs it)
cd server && source .venv/bin/activate && uvicorn app.main:app --reload --host 0.0.0.0
ruff check app && black app          # lint + format
pytest                               # economy tests — needs a live DATABASE_URL

# Client
cd client && flutter run -d linux    # or: -d chrome, -d <android-device-id>
flutter analyze && flutter test
```

Both need a `.env` (see `.env.example` in each dir), plus a Supabase project with
`server/schema.sql` applied — full walkthrough in [docs/setup.md](docs/setup.md).

`API_URL` in `client/.env` is the deployed HTTPS URL. It also accepts a
comma-separated candidate list for local server work — the app probes them all and
keeps whichever answers — but a LAN address breaks whenever the network changes and
a release APK cannot use one at all, so plain HTTPS is the default. Bind uvicorn to
`0.0.0.0` or a phone can never reach it.

`server/tests/` runs against the **real** database inside a transaction that is
rolled back, so it is safe to point at the live project but needs network. The AI
hint endpoint is optional: with no provider configured it 503s and the client hides
the button ([setup.md](docs/setup.md) step 10).

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
  services/statement_service.py  scrapes + sanitises Codeforces statements (D45)
  dependencies/auth.py get_current_user_id — verifies Supabase JWT
server/schema.sql      the live tables; run in the Supabase SQL editor
client/lib/
  main.dart            app entry, theme, splash, deep-link handling. Bootstraps
                       *after* runApp — startup does no blocking network (D42)
  core/                app_colors.dart (the palette), widgets/ (shared UI),
                       codeforces_web.dart (Codeforces in an in-app WebView)
  config/              env-backed config
  services/common/     auth_service, user_service, supabase_services (singletons)
  app/auth/            login, signup, forgot_password, email_verification
  app/profile/         profile_create (post-signup onboarding)
  app/modules/         questions, leaderboard, daily_challenge, notifications, profile
  app/admin/           dashboard, user suspension, quest moderation (gated on is_admin)
```

## Conventions

- **Terminology:** "quest" is the product word, `question` is the schema word. UI strings
  and Dart types say Quest (`Quest`, "Browse Quests"); the table, the ORM model, the JSON
  keys and the route stay `question` / `/api/questions` (decisions.md D1, D14).
- **Mobile-first.** This is a phone app that also runs on desktop. Build the phone layout
  first and treat the wide layout as the variant — always via
  `isWideLayout(context)` from `core/breakpoints.dart` (900px), never a width
  literal of your own. Concretely: no fixed widths on
  anything a phone renders, `Wrap`/`Flexible` over hard `Row`s, full-width buttons, every
  screen scrollable, and anything the desktop sidebar offers must also be reachable on a
  phone. New screens get a case in `test/mobile_layout_test.dart`, which fails on overflow
  at 320px and 360px.
- **Auth:** the Flutter client talks to Supabase Auth directly (`supabase_flutter`).
  FastAPI never issues tokens — it only verifies the bearer JWT via
  `Depends(get_current_user_id)` and trusts the `sub` claim.
- **Errors:** plain FastAPI. Raise `HTTPException(status_code=..., detail="message")`;
  the client reads `body['detail']`. Do not invent a custom error envelope.
  On the client, a failure that never reached the server sets
  `ApiException.isOffline`; pass it to `ErrorState(offline:)` so the screen
  waits and retries instead of demanding a tap (decisions.md D46).
- **Server layering:** router → service → model. Routers do no DB work.
- **Client state:** `StatefulWidget` + `setState`, `Navigator` (no router package),
  `package:http`. No Riverpod / GoRouter / Dio — do not add them. A package that
  supplies a *platform capability* is a different question and has been added
  twice (`url_launcher` D37, `webview_flutter` D43); an architectural preference
  is not.
- **Links:** open external URLs with `openLink()` from `core/open_link.dart`
  (url_launcher), never by showing a URL to copy. Android needs the `https`
  `<queries>` intent in the manifest or it silently fails (decisions.md D37).
  **Codeforces** links go through `openCodeforces()` in
  `core/codeforces_web.dart` instead, which hosts the page in an in-app WebView
  on Android/iOS/macOS and falls back to `openLink` elsewhere. Codeforces has no
  submit API and no statement API, so hosting their pages is the only way to
  read a problem and submit a solution without leaving the app (D43).
- **Alignment:** `Center` centres vertically too, so a page shorter than the
  viewport floats down the middle of it. Content screens use
  `Align(alignment: Alignment.topCenter)`; only auth forms use `Center` (D36).
- **Names:** never render `username` directly — it holds the signup email. Use
  `displayName`, or the helpers in `core/display_name.dart` (D36).
- **Theme:** light, blue `#0066FF`, Inter/Outfit via `google_fonts`. Colors come
  from `AppColors` in `client/lib/core/app_colors.dart` — never write a raw
  `Color(0xFF...)` literal. Forms use `LabeledField` from `core/widgets/`. See
  [docs/design-system.md](docs/design-system.md); the old dark-navy palette is gone.
- **Branching:** feature branches, PR review before merge, `main` always deployable.

## Docs (read on demand — do not preload)

| File | Read it when |
|---|---|
| [TASKS.md](TASKS.md) | Starting any work — what's done, what's next. Update it when you finish something. |
| [docs/setup.md](docs/setup.md) | Nothing runs, email never arrives, DB won't connect, or you're deploying |
| [docs/product.md](docs/product.md) | Deciding scope, point-economy rules, what is out of scope |
| [docs/architecture.md](docs/architecture.md) | Adding an endpoint, screen, or changing auth/data flow |
| [docs/data-model.md](docs/data-model.md) | Touching the DB — canonical schema, live vs. planned tables |
| [docs/api.md](docs/api.md) | Wiring client↔server — endpoint contract + implementation status |
| [docs/design-system.md](docs/design-system.md) | Building UI — colors, type, spacing, components |
| [docs/decisions.md](docs/decisions.md) | Something in the code contradicts your assumption — the "why" lives here |
| [docs/demo-script.md](docs/demo-script.md) | Recording the demo — shot list, narration, seed data, capture commands |

## Ground rules

1. **API contract first.** Add the endpoint to `docs/api.md` before building the screen
   that consumes it.
2. **No gold plating.** Finish all Tier 1 (MVP) items in `TASKS.md` before starting Tier 2.
3. **Keep docs true.** If code and docs disagree, the code wins — fix the doc in the same PR.
4. **Never fake success.** A screen with no backend shows an honest disabled state,
   not a "Saved!" toast. Never invent statistics or seed the UI with fictional numbers.
5. **A phone is the target.** If it does not work at 360px wide, it does not work.
6. **Before every PR:** `flutter analyze` and `flutter test` in `client/`, `ruff check app`
   and `black app` in `server/`. All must be clean.
