# Decisions

Short log of choices that resolve a contradiction someone will otherwise hit again.
Newest last. Only add an entry when the reasoning is not obvious from the code.

---

### D1 — "Quest", not "question"
The old docs said `questions`; the shipped DB table, ORM model and UI all say `quests`.
Renaming live code and a live Supabase table to match a doc is pure cost, and "quest"
fits the product name. **Quest is canonical.** `docs/api.md` and `docs/data-model.md`
were rewritten to match.

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
