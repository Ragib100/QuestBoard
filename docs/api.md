# API contract

Base URL `${API_URL}/api`. Every endpoint except `/` requires
`Authorization: Bearer <supabase-access-token>`.

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

## Health

| | Endpoint | Notes |
|---|---|---|
| ✅ | `GET /` | Unauthenticated liveness check |
| ✅ | `GET /ping` | Returns `{ user_id }` — use it to verify a token end to end |

## Users

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /users` | Creates the profile row after email verification. Body: `username`, `first_name`, `last_name`, `phone_number?`, `codeforces_handle`, `image_url` (storage path). `409` if username taken. |
| ⬜ | `GET /users/{id}` | Public profile: username, names, `image_url`, points, `streak_days`, `codeforces_handle`, `created_at`. Never returns email or phone for other users. |
| ⬜ | `PATCH /users/{id}` | Own profile only. Editable: names, `phone_number`, `image_url`, `codeforces_handle`. |
| ⬜ | `GET /users/{id}/points` | `{ balance, transactions: [{ amount, reason, ref_id, created_at }] }`, newest first, paginated. |
| ⬜ | `GET /users/{id}/badges` | Earned badges with `earned_at`. |
| ⬜ | `GET /users/{id}/streak` | `{ streak_days, last_active }`. |

## Quests

| | Endpoint | Notes |
|---|---|---|
| ✅ | `POST /quests` | Body: `title`, `description`, `tags[]`, `bounty_points` (0–100, pending). Deducts the bounty in the same transaction. `402` if balance too low. |
| ⬜ | `GET /quests` | Query: `tag`, `sort=latest\|bounty\|votes`, `page`, `limit` (default 20). Returns list + author summary + counts. |
| ⬜ | `GET /quests/{id}` | Single quest with its answers, vote counts, and the caller's own vote. |
| ⬜ | `PATCH /quests/{id}` | Author only. Bounty cannot be changed after posting. |
| ⬜ | `DELETE /quests/{id}` | Author only, and only while unanswered — refunds the bounty. |
| ⬜ | `GET /quests/search?q=` | `pg_trgm` similarity over title and description. |
| ⬜ | `POST /quests/duplicate-check` | Tier 3. Body `{ title }` → up to 3 similar quests. |

## Answers

| | Endpoint | Notes |
|---|---|---|
| ⬜ | `POST /quests/{id}/answers` | Body `{ body }`. Notifies the quest author. `409` if the quest is solved. |
| ⬜ | `PATCH /answers/{id}` · `DELETE /answers/{id}` | Author only. Cannot touch an accepted answer. |
| ⬜ | `POST /answers/{id}/accept` | Quest author only, once. One transaction: mark answer accepted, mark quest solved, credit the helper, write `bounty_awarded`, insert a notification. |

## Votes

| | Endpoint | Notes |
|---|---|---|
| ⬜ | `POST /quests/{id}/vote` · `POST /answers/{id}/vote` | Body `{ value: 1 \| -1 }`. Same value again clears the vote; the opposite flips it. Adjusts the author's points by ±1. `403` on self-vote. Returns `{ vote_count, my_vote }`. |

## Gamification

| | Endpoint | Notes |
|---|---|---|
| ⬜ | `GET /leaderboard?period=weekly\|all_time` | Top 20 plus the caller's own rank. |
| ⬜ | `GET /badges` | Static catalogue of every badge. |
| ⬜ | `GET /notifications` | Paginated, newest first, with `unread_count`. |
| ⬜ | `PATCH /notifications/{id}/read` · `PATCH /notifications/read-all` | |

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
