# Task board

Single source of truth for progress. Check a box only when it meets the definition of
done in [docs/product.md](docs/product.md#definition-of-done). Work top to bottom —
milestones are ordered by dependency, not preference.

**Now:** M2 — the core loop. Nothing in M3+ starts until M2 is done.

| Milestone | Status |
|---|---|
| M0 · Foundation | ✅ done |
| M1 · Auth & profiles | 🟡 mostly done |
| M2 · Quest loop (MVP core) | 🔴 not started |
| M3 · Gamification & notifications | 🔴 not started |
| M4 · AI & daily challenge | 🔴 not started |
| M5 · Search, admin & polish | 🔴 not started |
| M6 · Ship | 🔴 not started |

**Verified green** (2026-08-14): `flutter analyze` → no issues · `flutter test` → 4/4
passing · `flutter build web` → succeeds · `ruff check app` + `black --check app` →
clean · `GET /api/` → 200 · `/api/ping` → 401 without a valid token · CORS preflight
→ 200 · both ORM models registered and the `User.quests` relationship resolves.

⚠️ **Blocked on configuration, not code:** `server/.env` still holds the placeholder
`DATABASE_URL`, so no endpoint that touches the database can work yet, and Supabase
has no custom SMTP so verification emails are never delivered. Both are one-time
setup steps — follow [docs/setup.md](docs/setup.md).

---

## M0 · Foundation ✅

- [x] Repo, branch rules, `.env.example` for client and server
- [x] FastAPI app with `/api` router, Supabase + SQLAlchemy wired
- [x] `get_current_user_id` JWT dependency + `GET /api/ping`
- [x] Flutter app: theme, deep links, Supabase init
- [x] Docs reorganised — `CLAUDE.md`, `docs/`, this board
- [x] Shared `AppColors` palette and `LabeledField` form widget in `client/lib/core/`
- [x] Client test suite runs and passes (was the broken Flutter counter template)
- [x] CORS middleware — Flutter web could not call the API at all without it
- [x] `server/schema.sql` — the live tables, runnable in the Supabase SQL editor
- [x] `docs/setup.md` — Supabase, Brevo SMTP, connection string, deep links, hosting
- [x] Android intent filter for `io.questboard://` — email links did not open the app
- [ ] Fill in a real `DATABASE_URL` in `server/.env` (see [docs/setup.md](docs/setup.md) step 3)
- [ ] Run `server/schema.sql` and create the public `profile_image` storage bucket
- [ ] Configure Brevo SMTP + the two redirect URLs in Supabase (steps 4–5)

## M1 · Auth & profiles 🟡

- [x] Login, signup, email verification, forgot/reset password — UI and wiring
- [x] `users` table and model
- [x] `POST /api/users` + `ProfileCreate` onboarding screen
- [x] Avatar upload to the `profile_image` bucket
- [x] Email format and password-confirmation validation on signup
- [x] Forgot-password screen reachable from the login form
- [ ] `GET /api/users/{id}` — profile read
- [ ] `PATCH /api/users/{id}` — profile edit (`ProfileEdit` is built and waiting on it)
- [ ] Wire `profile_screen.dart` to real data (still shows placeholder content)
- [ ] Migration: add `users.is_admin BOOLEAN NOT NULL DEFAULT false`
- [ ] Route users with a session but no `users` row to `ProfileCreate` on cold start
- [ ] Resend-verification-email button on `EmailVerification` (currently inert)

## M2 · Quest loop 🔴

The product does not exist until this works end to end. Every screen below renders
hardcoded placeholder content today.

**Database**
- [ ] Migration: `quests` gains `bounty_points`, `is_solved`, `accepted_answer_id`
- [ ] Create `answers`, `votes`, `point_transactions` (see [docs/data-model.md](docs/data-model.md))

**Server**
- [ ] `GET /api/quests` — pagination, `tag` filter, `sort=latest|bounty|votes`
- [ ] `GET /api/quests/{id}` — quest + answers + vote state
- [ ] `PATCH` / `DELETE /api/quests/{id}` — author only, refund on delete
- [ ] Deduct the bounty inside `POST /api/quests`, reject when the balance is short
- [ ] `POST /api/quests/{id}/answers`
- [ ] `PATCH` / `DELETE /api/answers/{id}`
- [ ] `POST /api/answers/{id}/accept` — the bounty transfer transaction
- [ ] Vote endpoints for quests and answers, with toggle logic and ±1 to the author
- [ ] `PointService` — the one place `users.points` and `point_transactions` are written

**Client**
- [ ] `QuestService` (list, get, create, update, delete) on the `UserService` pattern
- [ ] Wire `browse_questions.dart` — real data, pagination, loading/error/empty states
- [ ] Wire `question_detail.dart` — answers, accept button for the author
- [ ] Wire `ask_question.dart` — the Publish button and category picker are inert;
      needs tags, a bounty slider and a balance check before submit
- [ ] Answer composer — the send button in `question_detail.dart` is inert
- [ ] Vote buttons with optimistic update and rollback on failure
- [ ] Points balance in the app bar, refreshed after every economy action
- [ ] Markdown + code block + LaTeX rendering for quest and answer bodies

## M3 · Gamification & notifications 🔴

- [ ] Create `notifications`, `badges`, `user_badges`; seed the badge catalogue
- [ ] Streak update + `daily_bonus` on first activity of the day
- [ ] Badge check as a background task after each point event
- [ ] `GET /api/leaderboard` (weekly + all-time) and `GET /api/badges`
- [ ] Notification rows on answer received / accepted / bounty won / badge earned
- [ ] Notification list + read endpoints ("Mark all as read" is inert)
- [ ] Wire `leaderboard_screen.dart` and `notifications_screen.dart`
- [ ] Unread badge on the nav bell
- [ ] Badges and streak on the profile screen

## M4 · AI & daily challenge 🔴

- [ ] Pick and configure the LLM provider; add the key to `.env.example`
- [ ] Create `ai_hints`; write the Socratic prompt (hints only, never the answer)
- [ ] `POST /api/ai/hint` — deduct 5 points, refund on failure, 3/hour rate limit
- [ ] Hint modal in `question_detail.dart` with the point-cost confirmation
- [ ] Create `daily_challenges`, `challenge_attempts`
- [ ] Daily job pulling one Codeforces problem, with a cached fallback
- [ ] Codeforces handle verification flow
- [ ] `GET /api/challenges/today`, `POST /solve`, `GET /leaderboard`
- [ ] Wire `daily_challenge_screen.dart` (the solve button is inert)

## M5 · Search, admin & polish 🔴

- [ ] Enable `pg_trgm`, add the GIN indexes
- [ ] `GET /api/quests/search` + search UI (the dashboard search box is not wired)
- [ ] Tag filter chips and sort control on the feed
- [ ] Admin endpoints: stats, user list, suspend, force-delete
- [ ] Wire the five screens in `client/lib/app/admin/`, gated on `is_admin` — they are
      complete UI but currently unreachable, with every action button inert
- [ ] Audit every screen for loading / error / empty states
- [ ] Never surface a raw exception — always the API's `detail`

## M6 · Ship 🔴

- [ ] Deploy the API (Render or Railway) and point `API_URL` at it
- [ ] Release Android APK, tested off a debug build
- [ ] Web build deployed (`flutter build web` already succeeds)
- [ ] Seed demo data
- [ ] Backend tests for the economy transactions (bounty transfer, voting)
- [ ] Widget tests for the auth screens
- [ ] Final report and demo recording

---

## Chores

- [x] Removed a hardcoded password backdoor in `login.dart` that logged anyone in
- [x] Replaced 240+ duplicated `Color(0xFF…)` literals with `AppColors`
- [x] Added the missing `dispose()` to every controller-owning widget
- [x] Deleted the accidentally committed `client/ios/` and `client/macos/` trees and
      the 140 KB `client/android/build/` report; both are now gitignored
- [x] Repaired `server/.venv`, whose absolute paths broke when the project folder was
      renamed `QuestBoard` → `questboard`
- [x] Dropped the redundant `websockets` / `yarl` pins — both arrive transitively via
      `uvicorn[standard]` and `supabase`; verified the resolve still works without them
- [x] Deleted 1.4 GB of `client/build`, `server/.ruff_cache` and `__pycache__` trees
- [x] Quest creation now returns a clear 400 instead of a raw 500 when the caller has
      no profile row yet
- [ ] Android `applicationId` is still `com.example.client` — rename before release
- [ ] CI: `flutter analyze` + `flutter test` + `ruff check` on every PR
