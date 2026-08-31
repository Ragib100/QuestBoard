# API contract

Base URL `${API_URL}/api`. Every endpoint except `/` requires
`Authorization: Bearer <supabase-access-token>`.

CORS is enabled via `CORS_ORIGINS` (defaults to `*`) — Flutter web cannot call the
API without it.

There are **no auth endpoints** — registration, login, logout, refresh and password
reset all happen client-side through `supabase_flutter`. See
[architecture.md](architecture.md#auth-flow).

**Errors** are FastAPI's default shape. Never invent another.

```json
{ "detail": "Username is already taken." }
```

`400` invalid input · `401` missing/expired token · `403` not yours, admin-only, or suspended · `404` missing ·
`409` conflict (duplicate vote, already solved) · `422` Pydantic validation ·
`402` insufficient points.

**Status:** ✅ live · ⬜ planned · ❌ dropped (with the reason, so it is not re-proposed). Add a row here *before* building the screen that uses it.

---

> **Path naming:** the routes say `/questions` because the table does. The product
> calls them quests. See [decisions.md](decisions.md) D1.

## Health

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /` | Unauthenticated liveness check |
| ✅ | `GET /ping` | Returns `{ user_id }` — use it to verify a token end to end |
| ✅ | `GET /users/me` | The caller's own profile, including `is_admin` and `is_suspended`. **404 means signed in but not onboarded** — route to ProfileCreate |

## Users

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /users` | Creates the profile row after email verification. Body: `username`, `first_name`, `last_name`, `phone_number?`, `codeforces_handle`, `image_url` (storage path). `409` if username taken. |
| ✅ | `GET /users/{id}` | Public profile: username, names, `image_url`, points, `streak_days`, `codeforces_handle`, `created_at`. Never returns email or phone for other users. |
| ✅ | `PATCH /users/{id}` | Own profile only. Editable: names, `phone_number`, `image_url`, `codeforces_handle`. |
| ✅ | `GET /users/{id}/points` | `{ balance, transactions: [{ amount, reason, ref_id, created_at }] }`, newest first, paginated. `limit` defaults to 50; the profile asks for **10** — the earned/spent figures on that screen cover exactly the rows it fetched and say so. |
| ✅ | `GET /users/{id}/badges` | Earned badges with `earned_at`. |
| ✅ | `GET /users/{id}/streak` | `{ streak_days, last_active }`. |

## Quests

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /questions` | Body: `title` (non-empty, ≤300), `body` (non-empty, ≤50,000), `tags[]` (≤5, must exist), `bounty_points` (0–100). Blank or whitespace-only title/body → `422`. Deducts the bounty in the same transaction; `402` if the balance is too low, `400` on an unknown tag. |
| ✅ | `GET /questions` | Public. Query: `tag`, `search`, `sort=latest\|bounty\|votes`, `page`, `limit` (≤50). Returns `{items, page, limit, total, has_more}`. A token is optional but adds `my_vote`. `search` matches title or body with `ILIKE`, served by GIN trigram indexes, and ranks title hits first unless an explicit `sort` overrides it. |
| ✅ | `GET /questions/{id}` | Public. Quest with answers (accepted first, then by score), vote counts and the caller's own votes. Increments `view_count`. |
| ✅ | `PATCH /questions/{id}` | Author only. Bounty cannot be changed after posting. |
| ✅ | `DELETE /questions/{id}` | Author only, and only while unanswered (`409` otherwise) — refunds the bounty. |
| ❌ | ~~`GET /questions/search?q=`~~ | Dropped: a second endpoint would duplicate `GET /questions`'s paging, tag filter and vote counts to add nothing. Search is a query parameter there. |
| ⬜ | `POST /questions/duplicate-check` | Tier 3. Body `{ title }` → up to 3 similar quests. |

## Answers

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /questions/{id}/answers` | Body `{ body, image_url?, code_body?, code_language?, attachment_url?, attachment_name? }`. Notifies the quest author. `409` if the quest is solved. `body` may be any non-empty text (max 50,000); an answer carrying `code_body` may omit it entirely, because the code *is* the answer. |
| ✅ | `PATCH /answers/{id}` · `DELETE /answers/{id}` | Author only. Cannot touch an accepted answer. `PATCH` takes the same optional code fields; passing `""` clears one. |
| ✅ | `POST /answers/{id}/accept` | Quest author only, once (`409` on repeat). One transaction: mark accepted, close the quest, credit the helper, write `bounty_awarded`. |

**Attachments are not an API endpoint.** The client uploads the file straight to
the public `submissions` Supabase Storage bucket — the same pattern avatars
already use — and sends the resulting public URL as `attachment_url`, with the
original filename as `attachment_name` so the UI has something to label the link
with. FastAPI never sees the bytes. `code_body` is plain text and *is* stored in
Postgres: it is small, it belongs to the answer, and putting it in a bucket would
mean a second fetch to render an answer.

## Votes

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /questions/{id}/vote` · `POST /answers/{id}/vote` | Body `{ value: 1 \| -1 }`. Same value again clears the vote; the opposite flips it. Moves the author's balance by the *delta*. `403` on self-vote. Returns `{ vote_count, my_vote }`. |

## Gamification

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /leaderboard?period=weekly\|all_time` | Public. Top `limit` (≤50) plus the caller's own rank pinned when signed in. Weekly is summed from the ledger over the last 7 days — no cron, no snapshot table. |
| ✅ | `GET /badges` | Public. The full catalogue; merge with `/users/{id}/badges` to show locked and earned together. |
| ✅ | `GET /notifications` | Paginated, newest first, with `unread_count`. Types: `answer_received`, `answer_accepted`, `bounty_awarded`, `badge_earned`. Votes deliberately do **not** notify. |
| ✅ | `PATCH /notifications/{id}/read` · `PATCH /notifications/read-all` | Read-all returns `{marked}`. Reading someone else's notification is `403`. |
| ✅ | `GET /notifications/unread-count` | One COUNT, no rows — what the nav bell polls. |

## Daily challenge

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /challenges/today` | Public. Creates today's row on the first request of the day — there is no cron. Returns `{ challenge, is_today, solver_count, my_attempt, codeforces_verified }`. Every `challenge` carries `source_url` (the statement) and `submit_url` (Codeforces' own submit form) — both derived from `codeforces_id`, neither stored. `is_today` is false when Codeforces was unreachable and the server fell back to the last stored challenge; `503` if there is not even one of those. It is also false on every row of `GET /challenges` and on `GET /challenges/{id}` for an archived one, where it means nothing at all — only a caller that asked for *today* may read it as a fallback (D47). |
| ✅ | `GET /challenges` | Public. The archive, newest first — `page`, `limit` ≤ 50, same page shape as `/questions`. Today's challenge is included only when `include_today=true`. Every row carries `award_points`: what solving it is worth **now**, after the age decay below. |
| ✅ | `GET /challenges/{id}` | Public. One challenge in the same shape as `/challenges/today`, so a past challenge reuses the whole screen. `404` if it does not exist. |
| ✅ | `POST /challenges/{id}/solve` | Checks the caller's public Codeforces submissions for an `OK` verdict on this problem **dated on or after the challenge's own day (00:00 Asia/Dhaka)**, then awards `award_points` — `bonus_points` decayed by the challenge's age, never `bonus_points` itself for an old one. Optional body `{ code_body?, code_language?, attachment_url?, attachment_name? }` stores the solution on the attempt. `403` without a **verified** handle, `409` if already claimed or not accepted yet, `502` if Codeforces is unreachable. A failed check still records an unsolved attempt — with the code, so nothing typed is lost. |
| ✅ | `PUT /challenges/{id}/submission` | Saves the solution written or uploaded in the app onto the caller's attempt **without touching Codeforces**. Body `{ code_body?, code_language?, attachment_url?, attachment_name? }` — an omitted field is left alone, an empty string clears it. Creates the attempt row if there is not one yet, and works before the problem is solved, after it is solved, and without a verified handle: keeping your code is not the same act as claiming the bonus, and requiring a Codeforces verdict to save a draft meant there was no way to submit code at all. Returns the updated `my_attempt`. `404` if the challenge does not exist. |
| ✅ | `GET /challenges/{id}/statement` | Public. The **real** Codeforces statement, scraped from the problem page once and cached on the row forever. `{ available, html, time_limit, memory_limit, samples[{input,output}], source_url, submit_url }`. `html` is sanitised server-side — no scripts, frames or event handlers, every URL absolute — because the client renders it in a WebView with a channel open to the app. `available: false` (a **200**, not a 502) when Codeforces refuses us: their API has no statement method, so the only source is the page, and it sits behind Cloudflare. A refusal is never cached — and on the deployed API it is the usual answer for an uncached problem, which is why the mobile client falls back to reading the page itself (D47). `404` if the challenge does not exist. |
| ✅ | `GET /challenges/{id}/leaderboard` | Public. Solvers ordered by `solved_at`, `limit` ≤ 100. Each row carries the `awarded_points` that solver actually received, which differs between a same-day solve and a late one. |
| ✅ | `GET /users/me/codeforces/verification` | The problem to submit a deliberate compilation error to, derived from the caller's id — deterministic, so nothing is stored server-side. Returns `problem_url` and `submit_url`. `400` without a handle on the profile. |
| ✅ | `POST /users/me/codeforces/verification` | Looks for that compilation error in the last 30 minutes and sets `codeforces_verified`. `409` when it is not there yet. A handle existing proves nothing; a submission on it does. |

### The clock is Asia/Dhaka

Every calendar question the server answers — which challenge is today's, how
many days old a challenge is, whether a streak survived, whether a Codeforces
submission is recent enough to claim — is answered in **Bangladesh time**
(UTC+6, no DST). `server/app/core/clock.py` is the only place that reads the
wall clock; nothing else calls `datetime.now()`.

Instants are still *stored* in UTC. The `timestamp` columns are naive and hold
UTC, so `created_at` comes back as `2026-08-20T14:18:09.297403` with **no zone
marker** — clients must read that as UTC. The Flutter client does so in
`client/lib/core/app_time.dart`; `DateTime.parse` would otherwise read it as
local time and render everything six hours out.

`challenge_date` is a plain `YYYY-MM-DD` calendar day and has no zone to
convert — shifting one moves it a day.

### Codeforces is read-only

There is no Codeforces API for submitting a solution, and none for reading a
problem statement — the public API exposes problem *metadata* (name, rating,
tags) and submission *verdicts*, nothing more. So QuestBoard never posts to
Codeforces. It serves `source_url` and `submit_url`, the client hosts those two
Codeforces pages in an in-app WebView, and the user submits on Codeforces' own
form under their own session — prefilled from the in-app editor, with the
compiler chosen by matching Codeforces' own option labels. The verdict comes
back the way it always has, through `user.status` on
`POST /challenges/{id}/solve`. See [decisions.md](decisions.md) D43.

The **statement** is a scrape, not an API read, and is the one place this app
parses someone else's HTML. `GET /challenges/{id}/statement` fetches the problem
page once, lifts `div.problem-statement` out of it, strips anything executable,
absolutises every URL, and stores the result on `daily_challenges.statement`
(jsonb). Statements never change, so a success is kept forever and a failure is
never cached — Cloudflare lets the next caller through often enough that one
refusal must not become a permanent "no statement" (D45).

That scrape fails far more often in production than in development, and the
difference is the IP: Cloudflare reads Render's datacenter address as a robot and
a phone's as a person. So `available: false` is the *common* answer on the
deployed API for any problem not already cached, and the client does not treat it
as the end of the road — on Android and iOS it loads Codeforces' own page in the
WebView and strips it down to the statement itself, styled with the same sheet
the cached path uses. That WebView deliberately has no JavaScript channel. See
[decisions.md](decisions.md) D47.

A challenge's `body` remains a generated summary. It is the fallback the screen
shows when neither path produced a statement — no WebView on this platform, or
Codeforces refused the phone too — and it is deliberately not an attempt at the
statement itself.

### Challenge point decay

A challenge is worth its full `bonus_points` on its own day and loses **10% of
that base per day** afterwards, with a floor at **20%** of the base. For the
standard 50-point challenge:

| Age | 0d | 1d | 3d | 5d | 7d | 8d+ |
|---|---|---|---|---|---|---|
| Award | 50 | 45 | 35 | 25 | 15 | 10 |

The decay is computed from `challenge_date` at claim time — it is never stored
on the challenge, so it cannot go stale. What *is* stored is
`challenge_attempts.awarded_points`, the amount actually paid, so the ledger and
the leaderboard agree about a solve forever after.

### An old solve does not pay

The verdict check is bounded below by the challenge's own day: the accepted
submission must be dated **on or after 00:00 Dhaka on `challenge_date`**.
Without that bound, a Codeforces account that had solved the problem at any
point in its history could claim a challenge it never opened — and archived
challenges made that trivially exploitable, since the archive is full of
well-known problems.

The refusal distinguishes the two cases, because they have different fixes:

| The handle has | `409 detail` |
|---|---|
| an accepted submission, but from before `challenge_date` | "Your last submission for this problem is from *date*, before this challenge opened on *date*. Submit it again on Codeforces to claim — old solves do not count." |
| nothing since `challenge_date` | "Codeforces has no accepted submission from *handle* for this problem since *date*. Submit your solution there first, then claim — a verdict can take a minute to land." |

The client states the rule *before* the button, on the challenge screen, rather
than leaving it to be discovered by a failed claim.

## AI

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /ai/hint` | `{ available, points_cost, hints_remaining }` — what the button should say before anyone spends anything. `available` is false when the server has no AI provider configured. |
| ✅ | `POST /ai/hint` | Body `{ question_id }`. `402` under 5 points, `429` past 3/hour, `503` when unconfigured or the model call fails (including a provider's free-tier quota running out). Deducts first and rolls back in the same transaction on failure, so an error always means nothing was charged. Returns `{ hint_text, points_cost, points_remaining, hints_remaining }`. |
| ⬜ | `POST /ai/scan` | Tier 3. Multipart image → `{ extracted_text }` to prefill the post form. |

## Admin

All require `users.is_admin`; everyone else gets `403 Admins only.` The flag is read
from the database on every call, so revoking admin takes effect on the next request
rather than the next login.

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /admin/stats` | `{ total_users, suspended_users, total_quests, open_quests, total_answers, points_in_circulation }` — all live counts. |
| ✅ | `GET /admin/users` | Paginated (`page`, `limit` ≤ 50), `search` over username and first/last name. **Not email** — that lives in `auth.users` and is never copied ([data-model.md](data-model.md)). |
| ✅ | `PATCH /admin/users/{id}/suspend` | Body `{ suspended: bool }` — explicit, not a toggle, so two admins cannot flip each other's decision. `403` on yourself or on another admin. A suspended user can still read; posting, answering and voting return `403`. |
| ✅ | `DELETE /admin/quests/{id}` | Bypasses the author check *and* the has-answers rule. Refunds the bounty unless the quest was already solved — that bounty is with the helper and refunding it would mint points. Deletes the answers and their votes too. |
