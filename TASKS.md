# Task board

Single source of truth for progress. Check a box only when it meets the definition of
done in [docs/product.md](docs/product.md#definition-of-done). Work top to bottom —
milestones are ordered by dependency, not preference.

**Now:** M4 — AI hints and the daily challenge. M1–M3 are done and verified against
the live database.

| Milestone | Status |
|---|---|
| M0 · Foundation | ✅ done |
| M1 · Auth & profiles | ✅ done |
| M2 · Quest loop (MVP core) | ✅ done |
| M3 · Gamification & notifications | ✅ done |
| M4 · AI & daily challenge | 🟡 tables exist, unused |
| M5 · Search, admin & polish | 🔴 not started |
| M6 · Ship | 🔴 not started |

**Verified green** (2026-08-14): `flutter analyze` → no issues · `flutter test` → 6/6
passing · `flutter build web` → succeeds · `ruff check` + `black` → clean · **26 API
endpoints live**, exercised against the real database along with every guard
(self-vote, self-answer, accept-by-non-author, double accept, overspend, unknown tag,
delete-with-answers, reading someone else's notification). The economy ledger nets to
zero — points are conserved, never minted. Streak transitions (first ever, same day,
consecutive, gap) and badge idempotency are asserted too.

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
- [x] Custom SMTP configured (Resend) — verification email delivers
- [ ] Set Supabase **Site URL** + both redirect URLs, then reinstall the Android app
      — until then email links dead-end on `localhost:3000` ([setup.md](docs/setup.md) step 5)

## M1 · Auth & profiles 🟡

- [x] Login, signup, email verification, forgot/reset password — UI and wiring
- [x] `users` table and model
- [x] `POST /api/users` + `ProfileCreate` onboarding screen
- [x] Avatar upload to the `profile_image` bucket
- [x] Email format and password-confirmation validation on signup
- [x] Forgot-password screen reachable from the login form
- [x] Signup reports "already registered" instead of Supabase's silent fake success
- [x] Show/hide toggle on every password field
- [x] `GET /api/users/{id}` and `GET /api/users/me` — profile read
- [x] `PATCH /api/users/{id}` — profile edit, own account only
- [x] `GET /api/users/{id}/points` — balance plus the ledger
- [x] `profile_screen.dart` shows the real profile, avatar and point history
- [x] `profile_edit.dart` saves for real; changing the Codeforces handle clears verification
- [x] `users.is_admin` — already present in the database
- [x] Session-without-profile routes to `ProfileCreate`, on login and on cold start

## M2 · Quest loop ✅

**Database** — the schema already existed; the code was aligned to it
([decisions.md](docs/decisions.md) D14).
- [x] `questions`, `answers`, `votes`, `point_transactions`, `tags`, `question_tags`
- [x] Dropped the vestigial `quests` table

**Server**
- [x] `GET /api/questions` — public, pagination, `tag`, `search`, `sort=latest|bounty|votes`
- [x] `GET /api/questions/{id}` — quest + answers + vote state, increments `view_count`
- [x] `PATCH` / `DELETE /api/questions/{id}` — author only, refunds on delete,
      refuses once answers exist
- [x] `POST /api/questions` deducts the bounty and returns 402 when short
- [x] `POST /api/questions/{id}/answers`, `PATCH` / `DELETE /api/answers/{id}`
- [x] `POST /api/answers/{id}/accept` — bounty transfer in one transaction
- [x] Vote endpoints with toggle/flip/clear and ±1 to the author by delta
- [x] `PointService` — the only writer of `users.points` and the ledger

**Client**
- [x] `ApiClient` — bearer token, timeouts, and `detail` turned into `ApiException`
- [x] `QuestService` + typed `Quest` / `Answer` / `Profile` models
- [x] `browse_questions.dart` — real data, infinite scroll, pull to refresh, tag and
      sort filters, loading/error/empty states
- [x] `question_detail.dart` — answers ordered accepted-first, accept with a
      confirmation dialog, composer hidden from the author and on solved quests
- [x] `ask_question.dart` — tag picker, bounty slider capped at the real balance
- [x] Vote buttons with optimistic update and rollback on failure
- [x] Points balance in the app bar, refreshed on navigation
- [ ] Markdown + code block + LaTeX rendering for quest and answer bodies (deferred:
      needs a package decision, and plain text is readable meanwhile)

## M3 · Gamification & notifications ✅

**Server**
- [x] `Notification`, `Badge`, `UserBadge` models over the existing tables
- [x] `ActivityService` — streak transitions and the +10 `daily_bonus`, once a day,
      on posting / answering / accepting / voting. Reads do not count.
- [x] `BadgeService` — awards inline in the same transaction, idempotent via the
      composite primary key ([decisions.md](docs/decisions.md) D18)
- [x] `LeaderboardService` — all-time from `users.points`, weekly summed from the
      ledger over 7 days, no cron ([decisions.md](docs/decisions.md) D17)
- [x] `GET /api/leaderboard` (public, own rank pinned), `GET /api/badges`
- [x] `GET /api/users/{id}/badges`, `GET /api/users/{id}/streak`
- [x] Notifications on answer received / accepted / bounty won / badge earned
- [x] `GET /api/notifications`, `/unread-count`, `PATCH /{id}/read`, `/read-all`

**Client**
- [x] `leaderboard_screen.dart` — weekly/all-time toggle, medals, own rank pinned
      even outside the top 20, tap through to a profile
- [x] `notifications_screen.dart` — typed icons, unread styling, optimistic
      mark-read, tap through to the quest
- [x] Unread count badge on the nav bell, refreshed on navigation
- [x] Badges on the profile — locked ones stay visible
      ([decisions.md](docs/decisions.md) D21)
- [x] Streak with a flame, and real stats on the home dashboard (was hardcoded)

**Deferred**
- [ ] `top_helper` badge — needs a weekly-rank check on a schedule; the other six
      awardable badges are live
- [ ] Vote notifications — intentionally omitted, see
      [decisions.md](docs/decisions.md) D19; revisit as a weekly digest

## M4 · AI & daily challenge 🔴

- [ ] Pick and configure the LLM provider; add the key to `.env.example`
- [x] `ai_hints` table exists
- [ ] ORM model + the Socratic prompt (hints only, never the answer)
- [ ] `ai_skeptic` and `challenger` badges become awardable once this lands
- [ ] `POST /api/ai/hint` — deduct 5 points, refund on failure, 3/hour rate limit
- [ ] Hint modal in `question_detail.dart` with the point-cost confirmation
- [x] `daily_challenges`, `challenge_attempts` tables exist
- [ ] Daily job pulling one Codeforces problem, with a cached fallback
- [ ] Codeforces handle verification flow
- [ ] `GET /api/challenges/today`, `POST /solve`, `GET /leaderboard`
- [ ] Wire `daily_challenge_screen.dart` (the solve button is inert)

## M5 · Search, admin & polish 🔴

- [ ] Enable `pg_trgm` and the GIN indexes — search currently uses `ILIKE`, which is
      correct but will not scale
- [ ] Wire the dashboard search box to `GET /api/questions?search=`
- [x] Tag filter chips and sort control on the feed
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
- [ ] Commit the economy tests as a pytest suite — they were run against the live DB
      but not checked in
- [ ] Widget tests for the auth screens
- [ ] Final report and demo recording

---

## Fixed after M3 field testing

- [x] **`INTERNET` permission was only in the debug manifest** — a release APK
      would have had no network access at all
- [x] **Android blocked all cleartext HTTP**, so every call to the local API failed
      before leaving the phone. Debug builds now permit it; release stays HTTPS-only
- [x] `API_URL` pointed at `192.168.137.35`, an address this machine does not have
- [x] Startup blocked on a 20s network timeout before drawing anything — now 4s for
      routing, 10s elsewhere, and the dashboard never blocks the first frame
- [x] Dashboard made five API calls in sequence; they now run in parallel
- [x] Four stat tiles forced into one `Row` overflowed every phone by up to 117px —
      now a responsive grid, 2 up on mobile and 4 on desktop
- [x] Landing page overflowed by 215px on a phone (app bar) and 64px on desktop
      (hero buttons); both layouts fixed
- [x] Added `test/layout_test.dart` — renders screens at 320px and 360px and fails
      on any overflow, so this class of bug cannot come back silently

## Fixed after the second Android round

- [x] **`API_URL` accepts a comma-separated candidate list.** The app probes them
      all in parallel on the first request, keeps whichever answers, and re-probes
      after a network failure. A single hardcoded host — the previous
      `adb reverse` + `localhost` scheme included — broke whenever the setup
      changed; now desktop, emulator and Wi-Fi phone all work from one `.env`
- [x] **Android had no way to reach Login**: the app bar's Login button was made
      web-only to cure an overflow, leaving the landing page's hero as the only
      entry point. Login is back on phones; the wordmark ellipsizes instead
- [x] Login and Signup overflowed a 360px phone (logo `Row` 146px, sign-in prompt
      `Row` 186px) — now `Flexible` + `Wrap`
- [x] **The dashboard's "Recent Questions" list was three hardcoded fake quests**
      ("Array vs ArrayList in Java"…) with a dead "See all". It now renders real
      quests from `GET /api/questions`, opens them, and shows an honest empty or
      offline state — ground rule 4
- [x] Reused `QuestTile` across Browse and the dashboard instead of a second,
      non-interactive card widget
- [x] Long names and titles could push scores off-screen in the leaderboard,
      profile stats and section headers — all ellipsize now
- [x] Four raw `Color(0xFF…)` literals had crept back in; added `AppColors.streak`
      and `AppColors.warningDark`
- [x] `layout_test.dart` now covers Login, Signup and ForgotPassword, and asserts
      the landing page always offers a way to log in

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
- [ ] Deploy the API so the app works off your Wi-Fi (M6)
- [ ] CI: `flutter analyze` + `flutter test` + `ruff check` on every PR
