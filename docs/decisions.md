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
