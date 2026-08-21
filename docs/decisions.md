# Decisions

Short log of choices that resolve a contradiction someone will otherwise hit again.
Newest last. Only add an entry when the reasoning is not obvious from the code.

---

### D1 — "Quest" in the product, `questions` in the schema (revised)
> Originally this said `quests` was canonical. That was decided without database
> access and turned out to be wrong — see D14.

The table is `questions` and so is every foreign key, route and JSON key. The product,
the UI and the Dart types say **quest**. Treat the wire format as the schema's business
and the word "quest" as the product's: `Quest.fromJson` reads `question_id`, and that is
intentional.

### D2 — Light theme, not dark navy
Early design docs specified a dark gamified palette (`#0D1117` + electric purple).
The ~25 screens actually built use a light theme on `#0066FF` blue. Rewriting all of
them for a palette is not worth the weeks. **The shipped light theme is canonical**;
the dark-theme design docs and the Google Stitch prompt files were deleted.

### D3 — No Riverpod / GoRouter / Dio
Docs mandated them; none are in `pubspec.yaml` and the app ships fine on
`setState` + `Navigator` + `package:http`. For an app this size the extra layers cost
more to learn and review than they save. **Stay on the plain stack.**

### D4 — FastAPI's `{"detail": ...}` error shape
Docs specified a custom `{"error", "code"}` envelope. The server raises plain
`HTTPException` and the client already parses `detail`. Adding an envelope means an
exception handler plus a client rewrite for no user-visible gain. **Use `detail`.**

### D5 — Push notifications (FCM) cut
Firebase was in every doc and in zero lines of code or dependencies. It needs
per-platform setup and an APNs account for iOS. **In-app notifications only**, read
from the `notifications` table. Revisit only if the app is actually deployed.

### D6 — `users` table follows the server model
The old epic schema had `email`, `bio`, `avatar_url`, `is_admin`. The migrated table
has `first_name`, `last_name`, `phone_number`, `image_url`, `codeforces_handle`,
`codeforces_verified`. Email lives in `auth.users` and must not be duplicated.
**The live model wins**; `is_admin` is a pending migration (see `TASKS.md`).

### D7 — Tier 3 features dropped, not deferred
Live discussion rooms, in-app code runner, personalized study path, auto difficulty
grader and the follow/social feed had full specs but no chance of landing in 10 weeks
alongside the MVP. **Removed from the docs entirely**; a one-line "explicitly out of
scope" list survives in `docs/product.md` so nobody re-specs them.

### D8 — App title is "QuestBoard"
`main.dart` sets `title: 'QuestHub'`. That is a typo, not a rename. Fix pending in
`TASKS.md`.

### D9 — Admin is a real epic
Admin was Tier 3, but five admin screens already exist in `client/lib/app/admin/`.
Rather than delete working UI, admin is Tier 2 with a real (small) backend surface.

### D10 — Two DB access paths, on purpose
The server uses SQLAlchemy over `DATABASE_URL` for all data work, and the `supabase-py`
client **only** for `auth.get_user(token)` in `dependencies/auth.py`. Do not query
tables through `supabase-py` — it bypasses the models.

### D11 — iOS and macOS build targets deleted
Commit `3c88a51` deliberately removed them; commit `0d3de06` re-added 68 files by
accident while committing docs. iOS is out of scope (D5/D7 — no Apple hardware, no
developer account, no time), and both trees regenerate with `flutter create .` if that
ever changes. **Deleted and gitignored.** Supported targets are Android, web, Linux
and Windows.

### D12 — No fake success, no invented numbers
The landing page advertised "10K+ Questions / 5K+ Users" for an app with no users, and
the profile editor showed a "Profile updated!" toast while saving nothing. Both teach
users to distrust the UI, and both hide unfinished work from the team. **A screen with
no backend shows an explicit disabled state**, and marketing copy describes what the
app does rather than how popular it is.

### D13 — Colors live in `AppColors`, not in screens
The same eight hex values appeared 240+ times across 21 files, so a palette change
meant a 21-file sweep and drift was inevitable. **`client/lib/core/app_colors.dart` is
the only place a `Color(0xFF…)` literal may appear.** Shared form rows likewise live in
`core/widgets/labeled_field.dart` instead of a private `_buildLabel` per screen.

### D14 — The `quests` table was a dead end
The database already contained a complete schema built on `questions` — with
`answers`, `votes`, `point_transactions`, `notifications`, `question_tags`, plus
seeded `badges` and `tags` — every foreign key pointing at it. Alongside it sat
`quests`: six columns, zero rows, referenced by nothing but the ORM.

Renaming the real schema would have meant rewriting six tables' foreign keys to
satisfy a naming preference. Aligning four server files cost far less. **`quests`
was dropped and the code moved to `questions`.** The lesson for the next
disagreement: the database is the expensive artifact, so check it before deciding
which side of a conflict is authoritative.

### D15 — Points move only through `PointService`
Every balance change goes through one method that writes the ledger row and updates
`users.points` together, and never commits on its own. That is what lets a bounty
transfer debit the asker and credit the helper inside a single transaction. The
end-to-end test asserts the ledger nets to zero — points are conserved, never minted.

### D16 — Votes are optimistic in the UI, authoritative on the server
Tapping an arrow updates the count instantly and rolls back if the request fails.
A vote is too small to justify a spinner, and the server returns the true count
either way, so the client never has to guess for long.

### D17 — The weekly leaderboard is computed, not snapshotted
The plan called for a Monday cron that snapshots scores and resets a counter.
`point_transactions` is already an append-only history, so the weekly number is just
`sum(amount) where created_at >= now() - 7 days`. **No cron, no snapshot table, no
Monday morning where the reset silently failed** — and the figure can be recomputed
for any window later. All-time still reads `users.points` directly.

### D18 — Badge checks run inline, not in a background task
Three cheap `COUNT` queries after a point event. Running them inside the same
transaction means a badge can never be lost to a worker that died between the answer
and the award. A background task would have traded correctness for a few milliseconds
nobody would notice.

### D19 — Votes do not create notifications
The `vote_received` type exists in the schema's CHECK constraint, and nothing writes
it. Votes arrive constantly and each one is nearly meaningless on its own; a row per
vote would bury the notifications that actually need action. Left in place for a future
digest ("your answer got 12 upvotes this week"), which is the form worth sending.

### D20 — Services flush, never commit
`PointService` and `BadgeService` add rows and call `db.flush()`, leaving the commit
to the caller. The session runs with `autoflush=False`, so **without the explicit
flush a pending ledger row is invisible to the badge check that reads it two lines
later** — a bug that shipped twice during M3 before the tests caught it: a badge
awarded twice, and `first_bounty` never awarded at all. Flushing makes writes visible
within the transaction; not committing keeps the whole event atomic.

### D21 — Locked badges stay visible
The profile shows all eight badges, greyed out until earned, rather than only the
earned ones. Seeing what is still achievable is most of what a badge list is for.
`challenger` and `ai_skeptic` are in the catalogue but unreachable until M4 — they
show as locked, which is honest.

### D22 — Suspension is a column, not a token claim
`users.is_suspended` is checked by `UserService.require_active`, which every write
path calls, rather than in `get_current_user_id`. The Supabase JWT knows nothing about
our tables, so a token-level check would need a database read on *every* request
including the public ones — and it would let a suspension take effect only after the
token expired. A suspended account can still read: banning someone from a Q&A board
their answers are still cited on helps nobody, and the point of suspending is to stop
them adding more.

### D23 — Two admin screens deleted rather than wired
`platform_management.dart` (maintenance mode, "XP per upvote") and
`reports_analytics.dart` (daily-active charts, activity logs) were pure mockups of
features that do not exist and are not planned: the point economy has no per-upvote
setting, nothing records logins, and there is no reporting or flagging anywhere in the
app. Ground rule 4 says a screen with no backend shows an honest disabled state — but
a permanently disabled screen for a feature that will never be built is just a
different lie. The three that survived (`admin_dashboard`, `user_management`,
`content_moderation`) map one-to-one onto the four real `/api/admin` endpoints.

### D24 — The reason CHECK constraint follows `PointReason`
The live `point_transactions_reason_check` had drifted: it still listed `hint_used`
and had never heard of `bounty_refunded`, so deleting a quest with a bounty and buying
an AI hint both failed on the insert — the first a live M2 bug, the second latent in
M4 because no key was configured to trigger it. `PointReason` in
`app/models/point_transaction.py` is canonical; `schema.sql` now drops and recreates
the constraint from that list rather than adding it only when missing, so re-running
the file repairs a stale constraint instead of skipping past it.

### D25 — Motion is SDK-only, and nothing repeats forever
The polish pass added the app's first animations. It added **no** package to do it: no
shimmer, no lottie, no confetti. Skeletons are `AnimatedBuilder` over one shared
controller, the celebration burst is a `CustomPainter` in an `Overlay`, and everything
else is `TweenAnimationBuilder` or `FadeTransition`. Durations and curves live in
`core/motion.dart` for the same reason colours live in `AppColors` (D13) — the
alternative is every screen inventing its own 250ms.

Two rules bind all of it, and both exist because of `test/mobile_layout_test.dart`,
which pumps a single frame at 320px and asserts no overflow:

1. **Animate opacity and transform, never a value the layout measures.** Tween a height
   and the overflow test is measuring a layout that never reaches the screen.

   `LeaderboardPodium` proved this the hard way. It first shipped tweening each
   pedestal's `height` inside a fixed-height `SizedBox`, reasoning that a constant outer
   box kept the parent's constraints honest. It did not: the widget test pumps one
   frame, the pedestals start at height 0, so the test measured an empty podium and
   passed — while the *settled* podium overflowed by 1px with a long display name and by
   13px at 1.5x text scale. The fix was to lay the pedestal out at full height always and
   animate a `scaleY` transform, which does not participate in layout at all. The test
   now calls `pumpAndSettle()` and sweeps text scales 1.0–2.0.

   The lesson generalises: **a passing test on an animated widget means nothing unless it
   settles the animation first.**
2. **Nothing repeats forever.** A pending `Timer` fails a `testWidgets` body outright,
   and an uncapped `controller.repeat()` makes `pumpAndSettle()` time out — a failure
   that surfaces months later in someone else's test. `SkeletonPulse` therefore stops
   after six cycles and rests, and a test asserts it settles. Note the irony this
   replaces: `CircularProgressIndicator` is itself an uncapped repeating animation, so
   the skeletons are strictly the safer of the two.

Also settled here: `flutter_svg` was rejected. It would have made the three popsy
illustrations actually render — they had never decoded on any platform we ship, so the
"illustration" was always the `errorBuilder`'s fallback icon — but it would have put a
network fetch on the app's first screen. `BrandArt` draws the same idea locally.

### D26 — Markdown and LaTeX rendering stays deferred
Still the one open Tier 1 item (TASKS.md, product.md "Markdown + code blocks + LaTeX").
Revisited during the polish pass and deliberately left out: `flutter_math_fork` and a
markdown renderer are the heaviest dependencies the client would carry, and the call was
to keep the app light. Plain text stays readable meanwhile. This is a known gap against
product.md, not an oversight — reopen it if quest bodies start carrying real code.


### D27 — Code submission is in-app; Codeforces submission is not possible
The ask was "submit code, or upload a file — verify my Codeforces account and use that
to submit". Half of that cannot be built: **Codeforces has no public submit endpoint.**
Its API is read-only, so submitting on a user's behalf would mean storing their
Codeforces password and driving a browser session against a site that treats that as
abuse. That was declined, not deferred.

What exists instead, and what it honestly claims:

- A **code editor** (`core/widgets/code_composer.dart`) on the answer composer and the
  challenge claim, with a language label and a file attachment. Monospace comes from the
  platform font, not `google_fonts`: code is the one thing that has to still look like
  code with no network.
- `answers` and `challenge_attempts` each gained `code_body` / `code_language` /
  `attachment_url` / `attachment_name`. The source lives in Postgres (small, belongs to
  the row, saves a second fetch); the file goes to the public `submissions` bucket, the
  way avatars already work, so FastAPI never handles the bytes.
- **The award is still paid only against a real Codeforces verdict.** Attaching code
  proves nothing and changes no balance — `ChallengeService.claim` checks the public API
  exactly as before. The code is stored either way, including on a claim made a minute
  too early, because losing what someone typed is its own bug.
- Tab is not an indent key in a Flutter form (it moves focus), so indenting is a button.
  Autocorrect and autocapitalisation are off; a phone keyboard "helpfully" capitalising
  `int` turns valid code into invalid code as you type it.

This narrows [D26](#d26--markdown-and-latex-rendering-stays-deferred) rather than
reversing it: code now has a real home with a real renderer, so the case for a markdown
dependency is weaker than it was, not stronger. Quest and answer *bodies* are still
plain text.

### D28 — Past challenges decay; and what the audit found in the ledger
Archived challenges stay solvable and are worth **10% of their base less per day, with a
floor at 20%** (`award_for`, table in [api.md](api.md#challenge-point-decay)). Linear,
not exponential, because a student can predict "five points a day" and cannot predict a
half-life. The floor is the point: a challenge that decays to nothing is one nobody has
a reason to open, and the archive exists to be worked through.

The decayed value is computed per request and **never stored on the challenge** — a
stored copy is wrong by the next morning. What *is* stored is
`challenge_attempts.awarded_points`, what one solve actually paid, because otherwise
nothing could say what a late solver received and the leaderboard would quietly
contradict the ledger.

Auditing every point path for that change turned up four defects, all now fixed and all
covered by a regression test:

1. **The signup bonus was never ledgered.** `users.points` defaults to 100 and
   `create_user` let it, so every account since M1 held 100 points with an empty history
   behind them and `users.points <> sum(amount)` for all of them — the exact invariant
   the ledger exists to guarantee. Now paid through `PointService`, with an idempotent
   backfill in `schema.sql` that reconciles the real gap rather than assuming 100.
2. **A downvote could fail on the author's balance.** The debit went through the same
   affordability check as a purchase, so downvoting someone with 0 points raised "Not
   enough points" — failing *the voter's* request and quoting them a stranger's balance.
   `allow_negative` now applies to that one caller. Clamping at zero was the tempting
   fix and is wrong: down-then-up would have minted the difference.
3. **A challenge could be claimed twice concurrently.** The unique
   `(challenge_id, user_id)` only protects the first claim; once an unsolved attempt
   existed, two racing claims both UPDATEd it and both were paid. The attempt is now read
   `with_for_update()`.
4. **Zero-amount movements wrote a ledger row.** Harmless to the arithmetic, noise in a
   history whose only job is to explain a balance. `apply` now returns `None`.

### D29 — One clock, and it is Asia/Dhaka

**Every calendar question is answered in Bangladesh time; every instant is
stored in UTC.**

The server was reading `datetime.now(timezone.utc)` in six places. That is a
defensible default for a global product and the wrong one here: everybody who
uses QuestBoard is in Dhaka, so "today's challenge" changed at 6am local, a
streak could break because a 1am session counted as yesterday, and the decay
counted a day at the wrong moment. `server/app/core/clock.py` is now the only
module that reads a wall clock, and it answers in UTC+6.

Storage did not change, and deliberately. The `timestamp` columns are naive and
hold UTC; rewriting them to local time would have been a migration over live
data to gain nothing, and would have made every existing row ambiguous. The
calendar is a presentation question, so it is answered at the edges.

That left a client bug worth naming, because it had been visible the whole
time. Those naive columns serialise as `2026-08-20T14:18:09.297403` — no `Z`,
no offset — and `DateTime.parse` reads an unzoned string as **local**. On a
phone in Dhaka every timestamp in the app was six hours early: a quest posted a
moment ago read "6h ago". `client/lib/core/app_time.dart` appends the `Z` the
column forgot, then renders at UTC+6 rather than at the device's zone, so a
traveller and a phone with the wrong zone set still see the day the server is
paying challenges for.

`challenge_date` is exempt: it is a calendar day, not an instant, and
converting one moves it a day.

### D30 — No minimum length on a quest or an answer

Posting required a 10-character title and a 20-character body; answering
required 10 characters. All three are gone. A live countdown ("14 more
characters needed") is a word count on a question, and what it actually
produced was padding — the rule cannot tell "Why is this O(n²)?" from twenty
characters of throat-clearing, so it taxed the former and passed the latter.

What is enforced instead is *non-empty*, reported under the field it belongs to
when the user tries to post, rather than as a snackbar they have to map back
onto the form. The Post button is no longer disabled on an empty form either: a
greyed-out button is a rule with no explanation attached, and the user asked to
be told what is missing.

The ceilings — 300 characters of title, 50,000 of body — are new, and are a
guard on what one request can write into a row, not a target. They are enforced
silently by an input formatter and are never shown. `TextField.maxLength` would
have drawn a "0/50000" counter, which reads as a goal.

### D31 — An accepted submission only counts if it postdates the challenge

The verdict check searched a handle's whole Codeforces history for an `OK` on
the problem. Anyone who had solved it at some point — years ago, in a contest,
before QuestBoard existed — could claim without opening the challenge. The
archive made that worse rather than better: it is full of well-known problems,
so a competitive programmer could have walked the whole archive for points in a
few minutes.

The check is now bounded below by 00:00 Dhaka on the challenge's own
`challenge_date`. A same-day solve is the normal case; solving an archived
challenge any time since it ran also counts, which is the point of keeping the
archive solvable. Solving it *before* it ran does not.

A blunter rule — "within the last 30 minutes" — was considered and rejected. It
would refuse the honest case of solving at breakfast and claiming at night, and
the thing being prevented is not staleness, it is a solve that was never made
for the challenge.

Because Codeforces returns submissions newest first, the bound also made the
scan cheaper: it stops paging as soon as it is past `since`, rather than
reading a fixed 200 rows and hoping.

### D32 — The daily challenge is a tab, not an overflow-menu item

On a phone the challenge lived behind the `⋮` menu in the app bar — the one
screen in the app with a deadline attached was the hardest to reach, and the
decay in D28 made "I forgot it existed" cost real points. It is now the fourth
of five bottom tabs.

Nothing was displaced to make room. Material's fixed bottom bar takes five
items, and at our narrowest supported width (320px) that is 64px per tab, which
fits an icon and a short label — hence "Ranks" and "Daily" rather than their
full titles. `type: fixed` is set explicitly: five items otherwise flips the bar
to `shifting`, which hides every inactive label.

Rendering it as a tab meant giving `DailyChallengeScreen` an `embedded` flag,
the same one `BrowseQuestions`, `LeaderboardScreen` and `ProfileScreen` already
take — the shell draws the app bar, so the screen must not. The archive link
moves from an app-bar action to the top of the body when embedded, since there
is no app bar to hang it on and the copy at the foot of the solver list is a
long scroll away.

### D33 — One layout breakpoint, in one place

`dashboard.dart` decided phone-vs-desktop at `width > 960`; the other eight
screens, and CLAUDE.md, used `> 900`. In a window between the two the shell
drew the **phone** layout — bottom nav, no sidebar, `embedded: true` passed to
every tab — while each tab independently concluded it was on a desktop and drew
its wide internal layout inside it. A desktop grid in a phone shell is not a
subtle difference, and that band is a perfectly ordinary window size on a Linux
desktop, which is where it was found.

The threshold is now `wideLayoutWidth` in `client/lib/core/breakpoints.dart`,
read through `isWideLayout(context)`. A duplicated constant is the only way two
screens can disagree about the same question, so `test/breakpoints_test.dart`
fails if any file under `lib/` compares `size.width` against a literal again.

### D34 — The quest title leads its own screen

Quest detail opened with an author row — avatar, name, timestamp, status chip —
and put the title below it, indented past the vote column. That is roughly 90px
of chrome before the screen says what the question actually is, on a phone
where 90px is a seventh of the viewport.

The title is now the first thing, at full width, and the author line is the
caption underneath it. The vote control keeps its position beside the body,
which is what it votes on.

### D35 — The landing page caps sections, not the page

The whole landing Column sat inside a 1200px `ConstrainedBox`, which also
capped the highlights band — a `Container` whose entire job is to be a
full-width stripe of a different colour. On anything wider than 1200px it
stopped short of both edges and read as a misaligned block floating mid-page.

Each section now caps its own contents and the band is full-bleed. The outer
Column stretches so the band has a width to fill, and `ColoredBox` replaced the
`Container` since the sizing no longer comes from it.

### D36 — Three layout bugs, found by looking at the running app

D33–D35 were written from reading the code and they fixed real defects, but
none of them was what had been reported three times. The three below were found
by building the Linux app, pointing it at the live API as the actual signed-in
user, sizing the window to 400×860 and taking screenshots. Reading the widget
tree could not have found any of them, because all three are about what the
viewport does to content that is otherwise correct.

**The greeting printed an email address.** Signing up seeds `username` with the
address the account was created with, and `displayName` falls back to
`username` when there is no first name. So the home screen's 28px heading read
`Welcome back, saifahmedsakib@gmail.com!` — and an address has no spaces, so it
broke mid-token across two lines and took the top sixth of the phone screen.
The same string appeared, truncated, on every quest tile. `core/display_name.dart`
now trims anything from the `@` on, everywhere. The address is still what the
account is keyed by; it is simply never rendered.

**`Center` centres vertically too.** Quest detail wrapped its scroll view in
`Center`, so a quest whose content is shorter than the viewport — one with no
answers yet — floated down the middle, leaving a band of dead space above the
title about as tall as the app bar again. This is the "so much space on top of
the question", and moving the title up (D34) did not touch it because the cause
was the alignment, not the content order. Content screens now use
`Align(alignment: Alignment.topCenter)`; the auth screens keep `Center`, where
centring a short form is deliberate.

**The claim button was below the fold.** On the challenge screen the action sat
at the end of a scrolling column, after the statement, the problem link, the
archive link, the claim rules and the code editor — off the bottom of a phone
and behind the tab bar. Reported as "there is no submit button", which is what
it looked like. Worse, the explanatory block added in D31 had pushed it further
down. It is pinned now, as `ChallengeActionBar` in a `bottomSheet`, the way the
answer composer already is on a quest.

### D37 — url_launcher, so the Codeforces link is a link

The daily challenge is a link out by design: the points come from a verdict on
Codeforces, and only Codeforces has the statement. The app had no way to open a
URL — `CopyableUrl` and `AttachmentChip` could only copy to the clipboard — so
the flow was "solve this problem on Codeforces" followed by a URL to select and
paste by hand.

That is most of why claiming appeared broken. Checking the live account against
the Codeforces API showed no submission for the challenge problem at all, ever:
the refusal was correct, and the user had simply never been given a usable way
to reach the problem. **Open problem** is now half of the pinned action bar.

`url_launcher` is the exception to "no new packages" — it is first-party, it has
no alternative on Android, and CLAUDE.md's rule names Riverpod/GoRouter/Dio,
which are architectural choices rather than a missing platform capability. The
`<queries>` intent for `https` is required in `AndroidManifest.xml` or
`canLaunchUrl` returns false on Android 11+ even when a browser is installed.

### D38 — Saving code and claiming the bonus are two different acts

Reported twice as "there is no code submit button". There was an editor, and
after D36 it was reachable — but nothing in the flow *submitted* it:

- `CodeComposer` stayed collapsed behind a blue text link ("Write or upload your
  code"), which reads as a link, not as an editor with an action.
- The only writer of `challenge_attempts.code_body` was `POST /solve`, and
  `/solve` refuses unless Codeforces already shows an accepted verdict. So
  someone who had written a solution but not yet submitted it upstream had no
  way to save it at all, and the only button anywhere near the editor said
  **Claim**.
- The copy made it worse by calling the field "Your solution (optional)" and
  saying it "is not what earns the points" — true, but it framed the editor as
  decoration.

Split into two: `PUT /challenges/{id}/submission` stores the code and never
calls Codeforces, and `POST /solve` still pays on the verdict. The editor now
opens expanded on the challenge screen with its own **Submit code** button and
a note confirming what is stored. It deliberately needs neither a verified
handle nor an unsolved challenge — keeping a record of your work has nothing to
do with claiming a bonus.

The answer composer keeps the collapsed editor and no submit button of its own:
most answers are prose, an always-open code pane pushes the text field off a
phone screen, and it already has a send button. `startOpen` and `onSubmit` are
what separate the two.

`CodeComposer` also never called `setState` as you typed, so its character
counter sat at 0 forever; the submit button's enabled state reads the same
controller, which is what surfaced it.

### D39 — The landing page keeps one alignment axis

The hero centres itself on a phone (and left-aligns beside the art on desktop),
but the highlights band under it was always left-aligned. On a phone that put a
centred heading directly above a left-aligned list — two competing alignments
on one screen, which is what "the alignment is completely wrong" meant. It
survived two earlier rounds of fixes because both were about width (the 1200px
cap, the full-bleed band), not about the axis.

The band now centres its icon, title and body. The hero's tagline also gained an
explicit `textAlign`: it had none, so it only *looked* centred while it fitted
on one line, and a larger system font setting wrapped it back to the left.

Confirmed against the running app at 360px rather than from reading the widget
tree — the same method D36 records, and the reason it was found at all.

### D40 — Verifying a handle gates claiming, not saving

D38 split the write in two — `PUT /challenges/{id}/submission` stores code and
never calls Codeforces, `POST /solve` still pays on the verdict — but the screen
kept the whole editor behind `if (!today.codeforcesVerified)`. A brand new
account therefore opened the daily challenge, saw one sentence about Codeforces,
and had no submit button anywhere on the page. The endpoint had never asked for
a verified handle; only the UI did.

The editor is now offered whatever the verification state, and the lock is
explained in a banner at the top of the screen next to the stale-challenge one,
where it belongs — it is the reason the pinned button says **Verify Codeforces
handle** rather than **Claim**.

Four more things on the same screen, all of which made submitting feel broken
even once the button was there:

- **The editor came after the rules.** A three-step explainer plus a warning
  panel sat between the problem and the only thing you can do with it, which put
  the submit button about a screen and a half below the fold on a phone. Action
  first, reference material after it.
- **The action bar was a `bottomSheet`.** A sheet is drawn *over* the body, which
  is why the list carried 140px of guessed bottom padding and still covered its
  last row whenever the bar wrapped to two lines — and why the bar parked itself
  on top of the code editor as soon as the keyboard opened. `bottomNavigationBar`
  is the slot that reserves real space, so the padding is now an ordinary 32.
- **Every write was followed by a full reload.** Saving code blanked the screen
  to a spinner, rebuilt the editor from the server mid-edit, and — if that read
  happened to fail — replaced a save that had worked with an error page. Saving
  now patches the returned attempt straight into state; a claim still re-reads
  but does it silently, because the reward burst is already on screen.
- **`PUT` had no timeout override**, so a solution going to a cold free-tier
  Render dyno hit the 10s default and surfaced as "could not reach the server".
  It gets the same 20s `/challenges/today` already uses.

Also removed: "Your last claim did not find an accepted verdict." It keyed off
an unsolved attempt existing, which stopped meaning "a claim failed" the moment
saving code started creating attempt rows of its own.

`CopyableUrl` became `ExternalLink` and `AttachmentChip` now opens what it points
at. Both still copied a URL and told you to paste it in a browser yourself,
which predates url_launcher landing in D37 and is exactly what CLAUDE.md's link
rule forbids. `openLink` still falls back to the clipboard when there is no
browser, so the old behaviour survives where it is actually the truth.

### D41 — The first two screens carry the brand mark

Reported as "that page is so massy", about the launch screen — the one held
while [_Launch] resolves a restored session, which on a cold start against a
sleeping server is on screen for several seconds.

It was a flat tinted disc, a wordmark and a tagline in a bare full-bleed
`Column` with **no horizontal padding at all**, and a progress bar pinned to the
bottom of the window with a `Spacer` between. So the text ran off both edges at
a large system font setting, and on a tall window a dead half-page separated the
logo from the only moving thing on screen.

It carries [BrandArt] now — the same mark as the landing and auth screens, so
the app opens on something of its own — and mark, wordmark, tagline and loader
are one centred block with the wordmark in a scale-down `FittedBox`.

The landing page got the same treatment in the same pass. `BrandArt` lived only
in the desktop hero's second column, and a phone has no second column, so the
first screen of the app was three stacked paragraphs of grey text; the phone
hero has the mark now. The highlights band was three centred paragraphs floating
in 32px of whitespace with no container around them, which read as a long sparse
scroll rather than as a list of three things — they are `AppCard`s, and they
stagger in with `FadeSlideIn`. The band still centres its contents, so D39 holds.

### D42 — Startup does no network work

"The launch splash takes too much time." It took as long as two blocking waits,
and neither had to be on the critical path.

`main` awaited `dotenv.load` and `Supabase.initialize` *before* `runApp`.
Restoring a stored session usually means refreshing an expired token over the
network, so all of that happened while the **operating system's** splash was on
screen — a screen we do not control, cannot brand, and cannot put a progress
bar on. `runApp` comes first now and the bootstrap runs behind our own splash.

Then `_Launch` awaited `landingScreenForCurrentUser()`, which calls
`GET /users/me` for one reason: telling a fully onboarded user apart from one
who quit halfway through signup. [Dashboard] *already* makes that exact call
when it mounts, so every cold start paid for it twice and the first one blocked.
`_Launch` is synchronous now — session or no session — and the half-onboarded
case is handled where it is actually discovered: the dashboard redirects to
[ProfileCreate] when its own `/users/me` comes back 404.

`goToLanding` still resolves the destination up front. Straight after a login
tap there is nothing on screen to flash, and the user is already expecting a
wait.

### D43 — Codeforces is read-only, so the app hosts Codeforces

The ask was for the whole loop to happen in QuestBoard: set your handle, read
the problem, submit, get the verdict. Codeforces makes three of those four
impossible through its API.

**Their public API has no write methods at all.** There is no submit endpoint —
their own admins have said so repeatedly ([blog 99189], [blog 86022]) — and no
method that returns a problem *statement* either; `problemset.problems` gives
name, rating and tags, which is exactly why the daily challenge's `body` is a
generated summary rather than the real text. What the API *does* give is
`user.status`, the verdict feed, which is what has always paid the bounty.

That leaves two ways to submit from inside an app: ask people for their
Codeforces password and drive the site as them, or host Codeforces' own pages.
The first is credential harvesting whatever the intent, breaks the moment they
add a captcha, and is against their terms. So: `webview_flutter`, and
`core/codeforces_web.dart`.

- The user signs in on Codeforces' real login page. The session cookie lives in
  the platform WebView's store; we never see a credential, and the Submit
  button they press is Codeforces' own.
- The app bar says `codeforces.com` under the title. An embedded browser that
  does not say whose site it is showing is one a user could mistake for our own
  login form.
- The submit form is prefilled with the code from the in-app editor, and the
  code goes on the clipboard too. The paste is best effort — Codeforces' markup
  has changed before — so the JavaScript reports whether it landed and the
  message says which of the two actually happened rather than assuming.
- Closing the page triggers the verdict check automatically. That is the one
  moment we know the user is done with it, which is why the browser fallback
  does *not* auto-check: it returns the instant the browser launches.

`webview_flutter` covers Android, iOS and macOS. Linux, Windows and web fall
back to `openLink` and the manual "Check now" button, which is the flow as it
was. Adding the package is the same call as `url_launcher` in D37: a missing
*platform capability*, not an architectural preference of the kind CLAUDE.md
rules out.

Handle verification moved into the same flow. It used to be four written steps
and a link out; it is now one button that opens the submit form with a
deliberately non-compiling line already in it, and checks on the way back.

The action bar changed with it. **Submit** is the primary button and **Claim**
is the outline one, which is the reverse of before — only a Codeforces verdict
pays, so for anyone who has not submitted yet Claim could only ever fail, and it
was the loud blue button telling them no.

[blog 99189]: https://codeforces.com/blog/entry/99189
[blog 86022]: https://codeforces.com/blog/entry/86022

### D44 — The home screen leads with the thing the app is for

Three fixes, one theme: the screen you land on was spending its best space on
filler and burying its headline feature.

- The greeting's subtitle read "Keep learning and earning points!" — filler,
  under a 28px heading, in the largest empty block on the screen. It says
  something true now, off `streakDays`, next to an initial avatar.
- The Daily Challenge card sat *below* the entire quest list on a phone, so the
  feature the app is built around was three tiles of scrolling away. It is
  directly under the stats now. Desktop keeps it in the sidebar, where it was
  already beside the fold.
- `_buildTopLeaderboard` and the daily-challenge card were hand-rolled
  `Container`s at radius 20 with raw `Colors.white`, which is the precise drift
  [AppCard] was written to stop. Both use the standard card now, and the
  podium's first three ranks are gold, silver and bronze instead of three
  identical grey discs.
