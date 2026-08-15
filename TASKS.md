# Task board

Single source of truth for progress. Check a box only when it meets the definition of
done in [docs/product.md](docs/product.md#definition-of-done). Work top to bottom —
milestones are ordered by dependency, not preference.

**Now:** M5 — search, admin and polish. M1–M4 are done and verified against the live
database; the API is deployed at <https://questboard-mccq.onrender.com>.

| Milestone | Status |
|---|---|
| M0 · Foundation | ✅ done |
| M1 · Auth & profiles | ✅ done |
| M2 · Quest loop (MVP core) | ✅ done |
| M3 · Gamification & notifications | ✅ done |
| M4 · AI & daily challenge | ✅ done |
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

## M4 · AI & daily challenge ✅

**AI hints**
- [x] Anthropic (`claude-opus-5`), key in `server/.env.example` as `ANTHROPIC_API_KEY`.
      Unset is a supported state: the endpoint 503s and the client hides the button
- [x] `AiHint` ORM model + the Socratic prompt — a nudge, never the answer
- [x] `POST /api/ai/hint` — deducts 5 points *before* the model call and rolls back
      in the same transaction if it fails, so an error always means no charge.
      3/hour, counted from `ai_hints.created_at` rather than a separate counter
- [x] `GET /api/ai/hint` — cost and remaining hints, so the button is honest
      before anyone spends anything
- [x] Hint modal in `question_detail.dart` with the point-cost confirmation

**Daily challenge**
- [x] `DailyChallenge` / `ChallengeAttempt` ORM models
- [x] Today's problem is pulled from the public Codeforces API on the first request
      of the day — no cron. The unique `challenge_date` makes the race safe
- [x] Falls back to the last stored challenge when Codeforces is down, and the
      screen says so rather than passing it off as today's
- [x] Codeforces handle verification: submit a deliberate compilation error to a
      problem derived from your user id. Deterministic, so no state to store —
      and a submission is the only thing that actually proves ownership
- [x] `GET /api/challenges/today`, `POST /{id}/solve`, `GET /{id}/leaderboard`
- [x] Solves are verified against Codeforces, never taken on trust
- [x] `daily_challenge_screen.dart` wired: real problem, claim button, solver list
- [x] `challenger` (7 solves) and `ai_skeptic` (an accepted answer on a quest you
      bought no hint for) are now awardable — `top_helper` still needs a schedule
- [x] `schema.sql` gained the six tables it was missing (M3's three and M4's three)
      and the badge seed, so it once again matches the live database

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

- [x] Deploy the API to Render (<https://questboard-mccq.onrender.com>) and point
      `API_URL` at it. Kept awake by a 10-minute cron ping — that is ~730 of the free
      tier's 750 instance-hours a month, so it covers this one service and no more
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

## Mobile-first pass

- [x] **No logout on mobile.** Logout, notifications, the points balance and the
      daily challenge lived only in the desktop sidebar — the phone had four tabs
      and no app bar at all. Added a mobile app bar (balance, bell, overflow menu
      with Daily Challenge and Log out) and a confirm dialog on sign-out
- [x] Tabs now take `embedded: true` inside the shell so the phone does not stack
      two app bars and lose 112px of a 640px screen
- [x] `EmailVerification` — the screen every signup lands on — clipped its buttons
      off the bottom by 83px with no scroll. Rewritten, now scrollable
- [x] Its "Resend Email" button did nothing; wired to `auth.resend` and hidden when
      there is no address to send to
- [x] **The daily challenge screen was entirely fictional** — a hardcoded 12:45:30
      countdown, a hardcoded problem and a dead button. Replaced with an honest
      "not open yet" state until M4 builds it (ground rule 4)
- [x] The desktop search box silently swallowed input; disabled until M5 wires it
- [x] `AskQuestion`'s button row overflowed 60px on a phone; stacked full-width now
- [x] `QuestTile` overflowed at 1.5x system font scale — tags and metadata now wrap
      onto separate runs instead of competing for one Row
- [x] Added `test/mobile_layout_test.dart`: hostile data (long names, 99999 points,
      8 tags, 1.5x text scale) at 320px and 360px
- [x] `CLAUDE.md` gained a mobile-first convention and ground rule 5; its
      terminology bullet still claimed the table was `quests`, reversed back in D14

## Auth fixes

- [x] **Password reset failed on submit.** `main.dart` opened the form on a fixed
      300ms timer, racing supabase_flutter's parsing of the recovery link — the
      screen loaded with no session and `updateUser` threw "Auth session missing".
      Now navigates on `AuthChangeEvent.passwordRecovery`, when the session exists
- [x] Expired or reused links now say so instead of surfacing a raw exception
- [x] The reset field gained the reveal toggle (`LabeledField`) and scrolls

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
