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

`400` invalid input · `401` missing/expired token · `403` not yours · `404` missing ·
`409` conflict (duplicate vote, already solved) · `422` Pydantic validation ·
`402` insufficient points.

**Status:** ✅ live · ⬜ planned. Add a row here *before* building the screen that uses it.

---

> **Path naming:** the routes say `/questions` because the table does. The product
> calls them quests. See [decisions.md](decisions.md) D1.

## Health

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /` | Unauthenticated liveness check |
| ✅ | `GET /ping` | Returns `{ user_id }` — use it to verify a token end to end |
| ✅ | `GET /users/me` | The caller's own profile. **404 means signed in but not onboarded** — route to ProfileCreate |

## Users

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /users` | Creates the profile row after email verification. Body: `username`, `first_name`, `last_name`, `phone_number?`, `codeforces_handle`, `image_url` (storage path). `409` if username taken. |
| ✅ | `GET /users/{id}` | Public profile: username, names, `image_url`, points, `streak_days`, `codeforces_handle`, `created_at`. Never returns email or phone for other users. |
| ✅ | `PATCH /users/{id}` | Own profile only. Editable: names, `phone_number`, `image_url`, `codeforces_handle`. |
| ✅ | `GET /users/{id}/points` | `{ balance, transactions: [{ amount, reason, ref_id, created_at }] }`, newest first, paginated. |
| ✅ | `GET /users/{id}/badges` | Earned badges with `earned_at`. |
| ✅ | `GET /users/{id}/streak` | `{ streak_days, last_active }`. |

## Quests

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /questions` | Body: `title` (≥10), `body` (≥20), `tags[]` (≤5, must exist), `bounty_points` (0–100). Deducts the bounty in the same transaction; `402` if the balance is too low, `400` on an unknown tag. |
| ✅ | `GET /questions` | Public. Query: `tag`, `search`, `sort=latest\|bounty\|votes`, `page`, `limit` (≤50). Returns `{items, page, limit, total, has_more}`. A token is optional but adds `my_vote`. |
| ✅ | `GET /questions/{id}` | Public. Quest with answers (accepted first, then by score), vote counts and the caller's own votes. Increments `view_count`. |
| ✅ | `PATCH /questions/{id}` | Author only. Bounty cannot be changed after posting. |
| ✅ | `DELETE /questions/{id}` | Author only, and only while unanswered (`409` otherwise) — refunds the bounty. |
| ⬜ | `GET /questions/search?q=` | `pg_trgm` similarity over title and description. |
| ⬜ | `POST /questions/duplicate-check` | Tier 3. Body `{ title }` → up to 3 similar quests. |

## Answers

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /questions/{id}/answers` | Body `{ body }`. Notifies the quest author. `409` if the quest is solved. |
| ✅ | `PATCH /answers/{id}` · `DELETE /answers/{id}` | Author only. Cannot touch an accepted answer. |
| ✅ | `POST /answers/{id}/accept` | Quest author only, once (`409` on repeat). One transaction: mark accepted, close the quest, credit the helper, write `bounty_awarded`. |

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
| ⬜ | `GET /challenges/today` | Today's problem plus the caller's attempt state. |
| ⬜ | `POST /challenges/{id}/solve` | Verifies against the Codeforces API using the user's handle, then awards `bonus_points`. `409` if already solved. |
| ⬜ | `GET /challenges/{id}/leaderboard` | Solvers ordered by `solved_at`. |

## AI

| | Endpoint | Notes |
|---|---|---|
| ⬜ | `POST /ai/hint` | Body `{ quest_id }`. `402` under 5 points, `429` past 3/hour. Deduct first, refund in-transaction if the model call fails. Returns `{ hint_text, points_remaining }`. |
| ⬜ | `POST /ai/scan` | Tier 3. Multipart image → `{ extracted_text }` to prefill the post form. |

## Admin

All require an admin user (`users.is_admin`, pending migration); non-admins get `403`.

| | Endpoint | Notes |
|---|---|---|
| ⬜ | `GET /admin/stats` | `{ total_users, active_quests, points_in_circulation }` |
| ⬜ | `GET /admin/users` | Paginated, searchable by username. |
| ⬜ | `PATCH /admin/users/{id}/suspend` | |
| ⬜ | `DELETE /admin/quests/{id}` | Bypasses the author check. |
