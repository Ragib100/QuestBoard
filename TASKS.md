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

## The two that were still wrong ✅

See [decisions.md](docs/decisions.md) D38–D39. Both had been reported twice
before. Same method as the round above — Linux build against the live API,
sized to 360px, screenshots before and after.

- [x] **Nothing actually submitted the code.** The editor existed and was
      reachable, but it stayed collapsed behind a text link, and the only thing
      that persisted `code_body` was `POST /solve` — which refuses unless
      Codeforces already shows an accepted verdict. So code written before
      solving upstream could not be saved at all, and the nearest button said
      **Claim**
- [x] `PUT /challenges/{id}/submission` stores a submission without calling
      Codeforces. No verified handle required, works before and after the
      solve, and creates the attempt row if there is not one yet
- [x] The challenge screen opens the editor expanded (`startOpen`) with its own
      **Submit code** button and a note confirming what is stored. The answer
      composer deliberately keeps the collapsed editor and its send button
- [x] Fixed while in there: `CodeComposer` never rebuilt as you typed, so its
      character counter was frozen at 0; and "Open problem" wrapped onto two
      lines at 360px
- [x] **The landing page used two alignments at once.** Centred hero directly
      above a left-aligned feature list. The band now centres too, and the
      tagline gained the explicit `textAlign` it never had — without it, it only
      looked centred while it fitted on one line
- [x] **New tests:** six server tests for `save_submission` (no Codeforces call,
      no verified handle needed, a second submit updates rather than inserting,
      a later claim does not wipe the code, editing after solving does not pay
      twice, missing challenge raises); client tests that the submit button
      appears and stays disabled until there is code, that the answer composer
      does *not* get one, and that the landing page holds one alignment axis

## Round three: the submit button, and the first screen ✅

See [decisions.md](docs/decisions.md) D40–D41. Same method again — Linux build,
window sized to a phone, screenshots of every state before and after.

- [x] **The editor was still hidden from anyone unverified.** D38 built
      `PUT /submission` so saving needs no Codeforces handle, then left the
      whole editor behind `if (!today.codeforcesVerified)` — so a new account's
      first sight of the screen was one sentence and no submit button. The
      editor is offered in every state; the lock is a banner at the top that
      explains the pinned **Verify Codeforces handle** button
- [x] Editor moved **above** the claim rules. The three-step explainer and the
      warning panel used to sit between the problem and the only action on the
      page
- [x] The pinned bar moved from `bottomSheet` to `bottomNavigationBar` — a sheet
      overlays the body, which is why the list carried 140px of guessed padding,
      still covered its last row, and got sat on by the keyboard
- [x] Saving no longer reloads the screen: it patches the returned attempt into
      state, so the editor is not rebuilt mid-edit and a failed refresh cannot
      replace a successful save with an error page. Claim refreshes silently
- [x] `PUT` got a timeout override (20s, as `/challenges/today` has). On a cold
      Render dyno the 10s default surfaced a working save as "could not reach
      the server"
- [x] Dropped "Your last claim did not find an accepted verdict" — it keyed off
      an unsolved attempt existing, which stopped meaning that once saving code
      began creating attempt rows
- [x] `CopyableUrl` → `ExternalLink`, and `AttachmentChip` opens the file. Both
      still copied a URL and asked you to paste it in a browser, which CLAUDE.md
      forbids and D37 made unnecessary
- [x] **The launch splash.** No horizontal padding at all, so the wordmark ran
      off both edges at a large font scale, and the loader was stranded at the
      bottom of the window. Now one centred block carrying `BrandArt`, with the
      wordmark in a scale-down `FittedBox`
- [x] **The landing page**: `BrandArt` in the phone hero (it was desktop-only,
      so a phone got three paragraphs of grey text and no image), and the
      highlights are `AppCard`s that stagger in instead of loose centred
      paragraphs in 32px of whitespace
- [x] **New tests:** an unverified user gets the editor and the submit button;
      the editor sits above the claim rules; the pinned bar does not overlap
      the list

## Round four: startup, Codeforces in-app, and the home screen ✅

See [decisions.md](docs/decisions.md) D42–D44.

### Startup

- [x] **The launch splash took too long, twice over.** `main` awaited
      `dotenv.load` and `Supabase.initialize` before `runApp`, so a token
      refresh happened while the *OS* splash was up — a screen we cannot brand
      or put a progress bar on. `runApp` runs first now
- [x] `_Launch` awaited `GET /users/me` purely to tell an onboarded user from a
      half-onboarded one — a call the dashboard already makes when it mounts.
      Startup is synchronous now; the dashboard redirects to ProfileCreate when
      its own `/users/me` 404s

### Codeforces, without leaving the app

- [x] **Established the constraint first:** the Codeforces API has no submit
      method and no statement method. Only `user.status` (verdicts) is
      available, which is what already pays the bounty
- [x] `webview_flutter` + `core/codeforces_web.dart` — Codeforces' own pages
      hosted inside QuestBoard. Sign in on their real login page; we never see
      a credential, and the Submit button is theirs
- [x] Read the statement in-app; submit in-app with the code from the editor
      prefilled (and on the clipboard as the fallback); the verdict check fires
      automatically when the page closes
- [x] Handle verification is one button now instead of four written steps and a
      link out — it opens the submit form with a non-compiling line already in
      it and checks on the way back
- [x] `submit_url` added to the challenge and verification payloads (server
      derives it; the client never builds a Codeforces URL itself)
- [x] Action bar reversed: **Submit** is primary, **Claim** is secondary. Claim
      can only fail before you have submitted, and it was the loud blue button
- [x] Android/iOS/macOS get the WebView; Linux, Windows and web fall back to
      `openLink` and the manual "Check now"
- [x] Verified with `flutter build apk --debug` — the plugin integrates and the
      Android build is green

### Home screen

- [x] Greeting: initial avatar, and a subtitle that says something true off
      `streakDays` instead of "Keep learning and earning points!"
- [x] The Daily Challenge card moved above the quest list on a phone — the
      app's headline feature was three tiles of scrolling away
- [x] The leaderboard card and the challenge card were hand-rolled `Container`s
      at radius 20 with raw `Colors.white`; both use `AppCard` / the standard
      radius now, and the top three ranks are gold, silver and bronze

## Round five: the real statement, real submission, and offline ✅

See [decisions.md](docs/decisions.md) D45–D46.

> **Schema change.** `daily_challenges` gained `statement` (jsonb) and
> `statement_fetched_at`. Both are `add column if not exists` in `schema.sql`,
> so re-running it in the Supabase SQL editor is safe and is all that is needed.
> They have already been applied to the live project.

### The problem statement

- [x] **There was no statement, and there could not have been** — the Codeforces
      API returns name, rating and tags and nothing else. `statement_service`
      scrapes the problem page and lifts `div.problem-statement` out of it
- [x] Cached on the row forever (statements never change, and Codeforces is
      behind Cloudflare — every refetch is another 403 risk). A *failure* is
      never cached: the next caller usually gets through
- [x] Sanitised server-side — scripts, frames, forms and `on*` handlers stripped,
      every URL absolutised — because it renders in a WebView with a channel
      open to the app
- [x] `GET /challenges/{id}/statement` returns `available: false` as a **200**
      when Codeforces refuses, and the screen falls back to the summary it has
      plus a button to Codeforces. It never invents a statement
- [x] Rendered in a WebView with our own stylesheet and MathJax configured for
      Codeforces' `$$$` delimiters; sample boxes get a **Copy** button
- [x] Desktop fallback (no WebView on Linux/Windows): text plus native sample
      blocks, with the maths converted — `$$$1 \le n \le 2 \cdot 10^5$$$` reads
      as `1 ≤ n ≤ 2 · 10⁵`
- [x] Verified by generating the document and rendering it in a browser, since
      `webview_flutter` has no Linux build — which is how two glyphs were caught
      rendering as tofu boxes

### Submission, vjudge-style — with no password

- [x] **The Codeforces password is not needed and is not stored.** The user is
      already signed into Codeforces in the app's WebView; that session is what
      submits. Storing passwords would have put a reversible secret for every
      user's Codeforces account in the Postgres
- [x] `submitToCodeforces` fills Codeforces' own form, picks the compiler by
      matching **their option labels** (never a hardcoded `programTypeId` —
      those change, and a stale one submits C++ as Python), and posts it
- [x] Refuses to guess: no form, or no compiler matching the language, and it
      fills the form and hands it back instead of submitting
- [x] Polls for the verdict afterwards — five tries, four seconds apart — because
      a submission sits "In queue" and claiming instantly reports a false "not
      accepted yet"

### Offline

- [x] **"Internet issues, then press retry" was a dead end.** `ApiException`
      now distinguishes "never reached the server" from "the server said no"
- [x] `ApiClient` retries **reads** automatically (700ms, 1600ms, re-probing the
      host). Never writes: a replayed POST could claim a challenge twice
- [x] `ErrorState(offline: true)` renders as `ReconnectingState` — a spinner
      that retries every 5s, capped at 6 attempts, then offers the button. The
      home banner does the same while keeping its tiles on screen
- [x] Threaded through all 12 screens that had the old error page

## Round six: the false alarm, the honest button, and one action at a time ✅

### "Always showing that Codeforces is unreachable"

- [x] **The false one.** `is_today` is false both when the server fell back and
      when you opened an archived challenge on purpose. The screen showed the
      "Codeforces is unreachable" banner for both, so every archive row carried
      it permanently. `DailyChallengeView.askedForToday` separates them
- [x] **The true one.** `GET /challenges/{id}/statement` succeeds locally and
      fails on Render for every uncached problem — Cloudflare reads a datacenter
      IP as a robot. Verified against the deployed API, not assumed
- [x] The phone is the way through: on Android/iOS a refused statement now falls
      back to loading Codeforces' own page in the WebView, stripped to
      `div.problem-statement` and restyled with **the same** `statementCss` the
      cached path uses. Their MathJax survives the move; the limits row is
      rebuilt so both paths look identical (D47)
- [x] That WebView opens **no** JavaScript channel — it is codeforces.com running
      its own scripts. Pinned by a test
- [x] Verified by running the real reader script against a live Codeforces page
      in a browser, since `webview_flutter` has no Linux build

### "Why does the save button work as a save button?"

- [x] It said **Submit code** and only saved. It says `Save solution` /
      `Update saved solution` now, with a save icon, and the surrounding copy
      says which button reaches the judge (D48)

### "I don't like the way submitting works"

- [x] The bar was Claim and Submit side by side at half a phone width, equally
      weighted, plus a third submit-ish button in the editor. It is one
      full-width primary action per stage now — `Submit to Codeforces` →
      `Check verdict` — with the other as a quiet link beneath
- [x] Nothing written yet: the primary button is disabled and says why, instead
      of failing when pressed
- [x] **Submitting saves the code first.** It used to store nothing until a claim
      succeeded, so a submission whose verdict never landed left the attempt empty
- [x] The verdict poll has a determinate progress bar (`2 of 6`) and a **Stop**.
      Six checks, four seconds apart
