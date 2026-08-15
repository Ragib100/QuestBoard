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
   and the overflow test is measuring a layout that never reaches the screen. The single
   exception, `LeaderboardPodium`, is boxed in a fixed-height `SizedBox` so its outer
   geometry is still constant.
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
