# Task board

Single source of truth for progress. Check a box only when it meets the definition of
done in [docs/product.md](docs/product.md#definition-of-done). Work top to bottom —
milestones are ordered by dependency, not preference.

**Now:** M6 — ship. M1–M5 are done and verified against the live database.

> **Deployed and verified.** <https://questboard-mccq.onrender.com> serves all 35
> endpoints; AI hints are configured in production and answering. **Not yet
> redeployed** with the challenge archive and code submission — Render still
> runs the pre-D27 build, and the live database has the new columns already
> (they are additive, so the deployed build is unaffected).

| Milestone | Status |
|---|---|
| M0 · Foundation | ✅ done |
| M1 · Auth & profiles | ✅ done |
| M2 · Quest loop (MVP core) | ✅ done |
| M3 · Gamification & notifications | ✅ done |
| M4 · AI & daily challenge | ✅ done |
| M5 · Search, admin & polish | ✅ done |
| M6 · Ship | 🟡 API deployed, apps not released |

**Verified green** (2026-08-20): `flutter analyze` → no issues · `flutter test` →
**41/41** · `pytest` → **43/43** against the live database · `flutter build web`
and `flutter build apk --release --split-per-abi` → succeed (arm64 20.0 MB,
armv7 17.6 MB, x86_64 21.6 MB) · `ruff check` + `black` → clean · **38 API
endpoints**, counted from the OpenAPI schema excluding the liveness root.

Carried over from **2026-08-15**, not re-run since: **98/98** endpoint assertions
against the *deployed* API with real tokens, covering every guard (self-vote,
self-answer, accept-by-non-author, double accept, overspend, unknown tag,
delete-with-answers, reading someone else's notification, admin-only,
self-suspend, suspending an admin, writing while suspended). Those predate the
two new challenge endpoints, which have server tests but have not been exercised
through the deployed API.

Points are moved, never minted, on every path that moves them — bounties, votes,
refunds and AI hints all net to zero across the ledger. The four deliberate
sources of new points are the signup bonus, the daily bonus, the challenge award
and nothing else; as of the D28 audit the live database reports **0** accounts
whose balance the ledger cannot explain.

Destructive paths — admin force-delete and the AI hint charge — were verified against
the live database inside a transaction that was then rolled back, so the refund, the
cascade, the vote cleanup and the no-charge-on-failure guarantee are all proven on
real rows without having altered any. AI hints were confirmed end to end against a
real free-tier provider.

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
- [x] Any OpenAI-compatible provider via `AI_BASE_URL` / `AI_API_KEY` / `AI_MODEL` —
      Gemini, Groq and OpenRouter all have a free tier, and switching is an `.env`
      change ([setup.md](docs/setup.md) step 10). `ANTHROPIC_API_KEY` still works and
      is used only when `AI_API_KEY` is empty. Unset is a supported state: the
      endpoint 503s and the client hides the button
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

## M5 · Search, admin & polish ✅

**Search**
- [x] `pg_trgm` and the GIN indexes over `questions.title` / `body` — they were
      already live but in neither `schema.sql` nor the docs, so both now say so.
      `ILIKE '%term%'` is index-served by them, which is why no query rewrite was
      needed ([data-model.md](docs/data-model.md#search))
- [x] Title hits rank above body-only hits; an explicit `sort=bounty|votes` still wins
- [x] The desktop top-bar box works and hands its term to the Browse tab. The phone
      has no top bar, so Browse grew its own field — debounced, clearable, and the
      empty state now distinguishes "no quests", "nothing tagged X" and "no match for X"
- [x] `GET /questions/search?q=` dropped rather than built ([decisions.md](docs/decisions.md) D23 table, api.md)

**Admin**
- [x] `users.is_suspended` + `UserService.require_active`, called by every write path.
      Suspended accounts read normally and get a 403 with a plain sentence on posting,
      answering or voting ([decisions.md](docs/decisions.md) D22)
- [x] `require_admin` dependency — reads `is_admin` from the database, so revoking it
      takes effect on the next request rather than the next login
- [x] `GET /admin/stats`, `GET /admin/users` (paginated, searchable),
      `PATCH /admin/users/{id}/suspend`, `DELETE /admin/quests/{id}`
- [x] Force-delete refunds the bounty unless the quest was already solved — that one
      is with the helper, and refunding it would mint points. Answers and their
      polymorphic votes go too
- [x] Cannot suspend yourself or another admin — either would need a SQL console to undo
- [x] `admin_dashboard` / `user_management` / `content_moderation` rewritten against
      the real API; every number on them was fictional before
- [x] Reachable at last: sidebar entry on desktop, overflow menu on mobile, both only
      when `is_admin`. A suspended user gets a banner instead of a surprise 403
- [x] `platform_management.dart` and `reports_analytics.dart` deleted — mockups of
      features that do not exist and are not planned ([decisions.md](docs/decisions.md) D23)

**Polish**
- [x] Audited every API-backed screen for loading / error / empty states — the two
      gaps were the admin screens (rewritten) and nothing else; the rest already had
      all three
- [x] `profile_create.dart` showed `e.toString()` on failure, which for a Storage
      error is a page of internals. It now shows the API's `detail` or one plain
      sentence — the last raw exception in the client
- [x] Fixed a live economy bug the admin work uncovered: the
      `point_transactions_reason_check` constraint still said `hint_used` and had never
      heard of `bounty_refunded`, so deleting a quest with a bounty (M2) and buying an
      AI hint (M4) both died on the insert ([decisions.md](docs/decisions.md) D24)
- [x] Layout tests for all three admin screens at 320px and 360px with six-figure
      counts and a 30-character surname

## M6 · Ship 🟡

- [x] Deploy the API to Render (<https://questboard-mccq.onrender.com>) and point
      `API_URL` at it. Kept awake by a 10-minute cron ping — that is ~730 of the free
      tier's 750 instance-hours a month, so it covers this one service and no more
- [x] `client/.env` is now the single HTTPS entry, not a LAN candidate list. The LAN
      address was the cause of "it worked yesterday, not today" — it changes with the
      network, and a release APK cannot use it anyway (cleartext is blocked)
- [x] Android `applicationId` renamed `com.example.client` → **`io.questboard.app`**,
      matching the `io.questboard://` deep-link scheme. Package directory, namespace
      and `MainActivity.kt` moved with it
- [x] Release APKs built and inspected: `--split-per-abi` gives arm64 20.3 MB /
      armv7 18.0 MB / x86_64 21.8 MB (universal is 54.9 MB). Verified in the merged
      manifest that the release build is **not** debuggable, keeps `INTERNET`, keeps
      the HTTPS-only network config, and bundles the Render URL — the four things that
      differ from a debug build and have each broken networking here before
- [x] Web build succeeds and bundles the right `API_URL`; deploy steps for a Render
      Static Site in [setup.md](docs/setup.md) §12.3
- [x] `seed_demo.py` — five students, eight quests, nine answers, 24 votes, all
      written **through the services** so the ledger balances (the script prints each
      balance beside its ledger sum). `--undo` removes exactly what it created
- [x] Economy tests committed as `server/tests/` — 20 tests over the ledger, bounty
      transfer, refunds, vote deltas, suspension and moderation. They run against the
      real database inside a transaction that is rolled back, because the schema needs
      Postgres and a fake one would not test what breaks
- [x] Widget tests for the auth screens — `client/test/auth_test.dart`, 7 tests over
      the validation that must fire *without* a network round trip
- [x] CI: `.github/workflows/ci.yml` runs ruff, black, `flutter analyze`,
      `flutter test` and a web build on every PR. The economy tests are a separate job
      that runs only when a `DATABASE_URL` secret exists, so a fork PR does not fail
      on a database it cannot reach
- [x] Render redeployed and serving all 35 endpoints, with the AI provider set in
      its **Environment** — a real hint came back through the deployed API
- [x] Launcher icons generated (`dart run flutter_launcher_icons` had never been run —
      the app installed with the stock Flutter icon), branded splash on all three
      surfaces (`drawable/`, `drawable-v21/`, `values-v31/`) plus an in-app splash
      while the session resolves, and the web build no longer calls itself "client"
- [ ] Real signing keystore before any Play Store submission — release APKs are signed
      with the debug key today
- [x] Final report written — architecture, the closed economy, testing strategy and an
      honest list of what was left undone. Every figure measured from the repo
- [x] [docs/demo-script.md](docs/demo-script.md) — shot-by-shot demo plan with
      narration, the seed data each shot needs, and the capture commands
- [ ] Record the demo itself against the script (needs a real device and a warm server)

## Code submission, the challenge archive, and a ledger audit ✅

See [decisions.md](docs/decisions.md) D27 (code submission) and D28 (decay + the
audit). Requires re-running `server/schema.sql` and creating the public
`submissions` storage bucket ([setup.md](docs/setup.md) step 2).

**Code submission**
- [x] `CodeComposer` — in-app editor with a language picker, an Indent button
      (Tab moves focus in a Flutter form), autocorrect off, and a file attachment.
      Monospace is the platform font, not `google_fonts`: code has to look like
      code with no network
- [x] `CodeBlock` / `AttachmentChip` — read-only rendering with line numbers, a
      copy button, and sideways scrolling rather than wrapped code
- [x] `answers` and `challenge_attempts` gained `code_body`, `code_language`,
      `attachment_url`, `attachment_name`. Files go to the public `submissions`
      bucket the way avatars do; FastAPI never sees the bytes
- [x] An answer that carries code needs no prose at all, on the server as well
      as in the composer (the old 10-character minimum is gone entirely — D30)
- [x] **Not** built: submitting to Codeforces. Its API is read-only — doing it
      would mean storing the user's Codeforces password. Declined, not deferred (D27)

**Past challenges**
- [x] `GET /challenges` (paginated archive) and `GET /challenges/{id}`, which
      returns the same shape as `/today` so one screen renders both
- [x] `award_for` — 10% of the base off per day, floored at 20%; computed per
      request, never stored on the challenge
- [x] `challenge_attempts.awarded_points` records what a solve actually paid, so
      the leaderboard and the ledger agree about an old solve forever after
- [x] `past_challenges_screen.dart` — infinite scroll, the decay explained once
      at the top, each card showing what it pays *now* beside what it was worth

**Point-accounting audit** — four defects found, each with a regression test
- [x] The signup bonus was never written to the ledger: every account since M1
      held 100 points with nothing explaining them. Fixed, plus an idempotent
      backfill in `schema.sql` — the live database now reports **0** accounts
      whose balance the ledger cannot explain
- [x] Downvoting an author with no points failed *the voter's* request with
      "Not enough points" about someone else's balance
- [x] Two concurrent claims on an existing unsolved attempt could both be paid;
      the attempt is now read `with_for_update()`
- [x] Zero-amount movements no longer write a ledger row

## Timezone, the post form, the phone tray, and the claim rule ✅

See [decisions.md](docs/decisions.md) D29–D32. Server-only changes; no migration
and no new dependency.

**Bangladesh time everywhere (D29)**
- [x] `server/app/core/clock.py` is now the only module that reads a wall clock.
      Six `datetime.now(timezone.utc)` call sites moved to it: today's challenge,
      the decay, the streak boundary, the AI hourly cap, the weekly leaderboard
      window and the Codeforces verification cutoff
- [x] Instants stay stored in UTC — the calendar is answered at the edges, not
      migrated into the rows
- [x] **Client bug fixed:** naive `created_at` strings have no `Z`, and
      `DateTime.parse` reads an unzoned string as *local* — every timestamp in
      the app was six hours early, so a quest posted seconds ago read "6h ago".
      `client/lib/core/app_time.dart` parses as UTC and renders at UTC+6
      regardless of the device's zone
- [x] The weekly leaderboard window was handing Postgres an aware value for a
      `timestamp without time zone` column, making it depend on the session
      timezone. Now naive UTC, matching the column

**Posting a quest (D30)**
- [x] No minimum length on a quest title, body, or an answer. Blank is still
      refused, with the warning under the field that is actually empty
- [x] The Post button is enabled on an empty form and explains what is missing
      when tapped, instead of being greyed out with no reason given
- [x] Silent 300 / 50,000-character ceilings via an input formatter, matched on
      the server. Deliberately not `maxLength`, which draws a counter
- [x] `MinLengthHint` deleted — nothing used it any more

**The phone nav tray (D32)**
- [x] Daily Challenge promoted from the `⋮` overflow menu to the fourth of five
      bottom tabs; nothing was displaced. `type: fixed` so the labels survive
- [x] `DailyChallengeScreen` gained the `embedded` flag the other tabs already
      take; its archive link moves to the top of the body when there is no app bar
- [x] Both covered in `test/mobile_layout_test.dart` at 320px and 360px

**The welcome page loaded nothing**
- [x] It was one `Future.wait` over four calls, so any single failure — a profile
      still onboarding, one leaderboard hiccup — blanked all four tiles and the
      quest feed at once. Each call now fails on its own and the rest still render
- [x] The empty state had said "pull to refresh" since it was written and there
      was no `RefreshIndicator` to pull. There is now
- [x] A banner names what failed and offers a retry, instead of leaving four
      zeroes on screen to be interpreted

**Claiming a challenge (D31)**
- [x] An accepted submission now only counts if it is dated on or after 00:00
      Dhaka on the challenge's own day — an old solve, from before the challenge
      existed, no longer pays. The archive made this exploitable in bulk
- [x] The refusal distinguishes "you solved this in 2023, submit it again" from
      "we cannot see any submission", because the fixes differ
- [x] The rule is stated on the screen *above* the claim button, not left to be
      discovered by failing
- [x] The submission editor is no longer a bare text link: it has a heading, says
      plainly that it is optional and is not sent to Codeforces
- [x] The scan stops paging once it is past the cut-off instead of reading a
      fixed 200 submissions and hoping the solve was in them

## Layout fixes and an admin audit ✅

See [decisions.md](docs/decisions.md) D33–D35.

**The opening screen (D33, D35)**
- [x] `dashboard.dart` used a **960px** breakpoint while the other eight screens
      and `CLAUDE.md` used **900px**. Between the two the shell drew the phone
      layout while every tab inside it drew its desktop layout — the misaligned
      opening screen. One `isWideLayout(context)` now, in `core/breakpoints.dart`
- [x] `test/breakpoints_test.dart` fails if any file under `lib/` compares
      `size.width` to a literal again — a duplicated constant is the only way
      two screens can disagree
- [x] The landing page's highlights band was inside the page's 1200px cap, so
      on a wide screen the coloured stripe stopped short of both edges. Sections
      cap their own contents now; the band is full-bleed and covered by a test

**Quest detail (D34)**
- [x] The title leads the screen at full width instead of sitting below the
      author row and indented past the vote column — about 90px of chrome
      removed from above the question

**Admin audit** — everything checked end to end; no defects found
- [x] `require_admin` → `AdminService` → the four endpoints all trace correctly;
      routers stay thin and the guard is a per-request DB read, so revoking
      admin takes effect on the next request rather than the next login
- [x] Client `AdminService` matches the contract, including `204` on delete
      (`ApiClient` returns null rather than trying to parse an empty body)
- [x] Every button on all three admin screens is wired; no dead controls
- [x] Foreign keys cascade correctly for a force-delete; the polymorphic `votes`
      rows have no FK and are deleted explicitly, which was already right
- [x] **New tests:** the `require_admin` 403 gate (including a valid token with
      no profile row, where `None.is_admin` would have been an AttributeError
      rather than a 403), user search across username and both names, that the
      search total counts every match rather than the page window, and that a
      force-delete leaves the ledger balanced
- [x] Known and left alone: a notification pointing at an admin-deleted quest
      opens a 404 error state. Honest, not a crash

## The three reported bugs, found by running the app ✅

See [decisions.md](docs/decisions.md) D36–D37. Earlier passes fixed real defects
from reading the code but missed all three of these, so this round was done by
building the Linux app against the live API as the signed-in user, sizing the
window to a phone and taking screenshots before and after.

- [x] **The greeting printed an email.** `username` is seeded with the signup
      address, so the home heading read `Welcome back, saifahmedsakib@gmail.com!`
      — no spaces to wrap on, so it broke mid-token and ate the top of the
      screen. `core/display_name.dart` trims from the `@` everywhere, including
      quest tiles
- [x] **`Center` centres vertically.** Quest detail floated its whole page down
      the middle of the viewport when it was shorter than one screen. That was
      the space above the question; moving the title up did not touch it.
      Content screens use `Align(topCenter)` now — auth screens keep `Center`,
      where centring a short form is deliberate
- [x] **The claim button was below the fold** and behind the tab bar, which is
      why it read as missing. Pinned as `ChallengeActionBar`, the way the answer
      composer already is, and covered at 320px in all three of its states
- [x] **The Codeforces link was not a link.** Added `url_launcher` and an
      **Open problem** button. Checking the live account against the Codeforces
      API showed no submission for the challenge problem, ever — the refusal was
      correct, there was just no usable way to reach the problem
- [x] `AndroidManifest.xml` gained the `https` `<queries>` intent, without which
      `canLaunchUrl` returns false on Android 11+ even with a browser installed

**Visual polish pass** — no feature changes; see [decisions.md](docs/decisions.md) D25
- [x] `core/motion.dart`: shared durations/curves, `appRoute`, `FadeSlideIn`,
      `TabTransition`, `CountUpText`. Zero new dependencies — the app had no animation
      of any kind before this
- [x] `core/widgets/skeletons.dart` replaces the bare spinner on 8 screens; the pulse
      is cycle-capped so it cannot hang `pumpAndSettle`, and a test asserts that
- [x] `AppCard` — one card shape, replacing ~15 hand-written `BoxDecoration`s whose
      radii had drifted across 16/20/24, and deleting the two `boxShadow`/`elevation`
      uses that contradicted the no-shadow rule
- [x] Full `TextTheme` scale + `appBarTheme` (`scrolledUnderElevation: 0`, which was
      tinting every app bar grey mid-scroll), `snackBarTheme`, `segmentedButtonTheme`
      and eight more themed blocks
- [x] `LeaderboardPodium` for the top three, replacing the 🥇🥈🥉 emoji in a flat list
- [x] `showRewardBurst` on bounty transfer and challenge claim — the two moments that
      previously produced no feedback at all
- [x] `showAppSnack` with success/error tones across all 19 call sites; they were
      previously identical whether you posted an answer or lost your session
- [x] Real data that the server already returned but nothing rendered: `view_count` on
      quest tiles, and `points_in_circulation` promoted to a hero card on the admin
      dashboard with the closed-economy note
- [x] Earned-vs-spent breakdown on the point ledger, labelled "across your last N
      entries" because `/users/{id}/points` is capped at 50 server-side
- [x] Three `Image.network` calls pointing at `.svg` URLs replaced with a local
      `BrandArt` painter. Flutter cannot decode SVG without `flutter_svg`, so those had
      *never* rendered on any platform — the hero art was always the fallback icon
- [x] Removed ~1.7MB of bundled assets that no `Image.asset` call ever referenced
- [ ] `GoogleFonts.*` → `Theme.of(context).textTheme` in the remaining ~29 call sites
      (intro/login/signup/forgot_password left alone deliberately — they are the
      screens `layout_test.dart` covers and there is no payoff in touching them)
- [ ] `GET /users/{id}/streak` is still never called; `last_active` remains unsurfaced

**Final pass**
- [x] Every endpoint exercised against the **deployed** API with real tokens —
      98 assertions, 0 failures, including a real AI hint and the full admin
      surface (see the verified-green block above)
- [x] Fixed: seeded demo accounts could not sign in. GoTrue reads
      `confirmation_token` / `recovery_token` / `email_change` /
      `email_change_token_new` as strings and 500s if any is NULL, so the
      accounts existed but every login failed
- [x] Dead code removed — `PointService.balance_of` (pure indirection),
      `codeforces_service.handle_exists` (verification proves ownership with a
      submission instead), and the unused `cupertino_icons` dependency
- [x] De-duplicated: `ChallengeService.solved_count` and
      `BadgeService._challenges_solved` were the same query written twice, while
      the router ran a *third* copy inline — a router doing DB work, against the
      layering rule. Now one `_count_solved` with two named callers
- [x] Four hand-rolled search debounces became one `SearchField` widget. They had
      already drifted: one trimmed the term before comparing, the others did not,
      so a trailing space re-ran the query. Two tests lock the behaviour down
- [x] 2.6 GB of build output and every `__pycache__` / `.ruff_cache` removed;
      shareable APKs kept in the gitignored `client/dist/`

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
- [x] The desktop search box silently swallowed input; disabled until M5, wired now
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
- [x] Android `applicationId` renamed to `io.questboard.app` (M6)
- [x] Deploy the API so the app works off your Wi-Fi (M6)
- [x] CI: `flutter analyze` + `flutter test` + `ruff check` on every PR
