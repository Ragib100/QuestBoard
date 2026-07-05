# QuestBoard API Reference

Base URL: `https://api.questboard.app/api`

All protected endpoints require the Supabase-issued JWT as a Bearer token:
```
Authorization: Bearer <supabase_access_token>
```

Authentication (register, login, logout, token refresh, forgot password, and change password) is handled by **Supabase Auth** on the client — see [Section 1](#1-authentication) for details.

All request and response bodies are JSON. Timestamps are ISO 8601 UTC.

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Users](#2-users)
3. [Questions](#3-questions)
4. [Answers](#4-answers)
5. [Votes](#5-votes)
6. [AI Hints](#6-ai-hints)
7. [Daily Challenges](#7-daily-challenges)
8. [Leaderboard & Badges](#8-leaderboard--badges)
9. [Notifications](#9-notifications)
10. [Tags](#10-tags)

---

## 1. Authentication

> **⚠️ Notice — Supabase Auth is used for all authentication.**
>
> QuestBoard does **not** expose any custom `/api/auth/*` endpoints. Registration, login,
> logout, email verification, token refresh, password reset, and password change are all
> handled directly by the **Supabase Auth SDK** on the Flutter client — no custom backend
> needed for any of these actions.

### Register
```dart
await supabase.auth.signUp(email: email, password: password);
```
Supabase automatically sends a verification email. The user must confirm before logging in.

---

### Login
```dart
await supabase.auth.signInWithPassword(email: email, password: password);
```
Returns a `session` containing `access_token`, `refresh_token`, and `user.id` (uuid).

---

### Logout
```dart
await supabase.auth.signOut();
```
Invalidates the current session on the Supabase side.

---

### Token Refresh
Handled **automatically** by the Supabase Flutter client. You do not need to call anything — the SDK silently refreshes the `access_token` using the `refresh_token` before it expires.

---

### Forgot Password (Reset Link)
```dart
await supabase.auth.resetPasswordForEmail(
  email,
  redirectTo: 'io.questboard://reset-password', // your app's deep link
);
```
Supabase emails the user a **password reset link**. When the user taps it, your Flutter app receives a deep link and the session is automatically restored. You should then immediately show the Change Password screen.

> **Deep link setup:** Register `io.questboard://reset-password` as a redirect URL in your Supabase project under **Authentication → URL Configuration → Redirect URLs**. Also configure the deep link in your Flutter app (`AndroidManifest.xml` and `Info.plist`).

---

### Change Password
Used after the user has clicked the reset link (session is active) **or** when a logged-in user wants to update their password from the Profile/Settings screen.

```dart
await supabase.auth.updateUser(
  UserAttributes(password: newPassword),
);
```

> This call requires an **active session**. For the forgot password flow, the session is set automatically when the deep link is opened. For the in-app settings flow, the user is already logged in.

---

> **Token flow summary**
>
> On successful login, Supabase returns a session with an `access_token` (JWT) and the
> authenticated `user.id` (uuid). This `user.id` is the same uuid used as the primary key
> across all QuestBoard database tables.
>
> **All protected FastAPI endpoints** validate this JWT by reading the `sub` claim, which
> contains the authenticated user's uuid:
>
> ```
> Authorization: Bearer <supabase_access_token>
> ```
>
> A new row is inserted into the `users` table automatically when a Supabase Auth user is
> created, via a Supabase database trigger (`on_auth_user_created`). The `users.id` always
> matches `auth.users.id`.

---

## 2. Users

### `GET /users/{id}`
Fetch a user's public profile.

**Auth required:** No

**Response `200`:**
```json
{
  "id": "uuid",
  "username": "saif_ahmed",
  "avatar_url": "https://storage.supabase.co/avatars/uuid",
  "bio": "CSE student at MIST",
  "points": 340,
  "streak_days": 5,
  "created_at": "2025-01-01T10:00:00Z"
}
```

---

### `PATCH /users/{id}`
Update the authenticated user's own profile.

**Auth required:** Yes (own account only)

**Request body** (all fields optional):
```json
{
  "username": "saif_new",
  "bio": "Updated bio",
  "avatar_url": "https://storage.supabase.co/avatars/new"
}
```

**Response `200`:** Updated user object.

---

### `GET /users/{id}/points`
Get the current point balance and recent transactions.

**Auth required:** Yes (own account only)

**Response `200`:**
```json
{
  "balance": 340,
  "transactions": [
    {
      "id": "uuid",
      "amount": 50,
      "reason": "bounty_awarded",
      "reference_id": "question-uuid",
      "created_at": "2025-01-05T08:00:00Z"
    }
  ]
}
```

---

### `GET /users/{id}/badges`
Get all badges earned by a user.

**Auth required:** No

**Response `200`:**
```json
{
  "badges": [
    {
      "id": "uuid",
      "name": "first_answer",
      "description": "Submitted your first answer",
      "icon_url": "https://storage.supabase.co/badges/first_answer.png",
      "awarded_at": "2025-01-02T12:00:00Z"
    }
  ]
}
```

---

### `GET /users/{id}/streak`
Get the current login/activity streak for a user.

**Auth required:** No

**Response `200`:**
```json
{
  "streak_days": 5,
  "last_active": "2025-01-10T00:00:00Z"
}
```

---

## 3. Questions

### `GET /questions`
List questions with optional filters and sorting.

**Auth required:** No

**Query params:**

| Param | Type | Description |
|---|---|---|
| `tag` | string | Filter by tag name e.g. `math` |
| `sort` | string | `latest` (default), `bounty`, `votes` |
| `solved` | boolean | `true` or `false` |
| `page` | int | Page number (default `1`) |
| `limit` | int | Results per page (default `20`, max `50`) |

**Response `200`:**
```json
{
  "total": 142,
  "page": 1,
  "results": [
    {
      "id": "uuid",
      "title": "How to solve a DP problem with bitmask?",
      "tags": ["dsa", "dynamic-programming"],
      "bounty_points": 30,
      "is_solved": false,
      "vote_count": 4,
      "answer_count": 2,
      "author": { "id": "uuid", "username": "saif_ahmed" },
      "created_at": "2025-01-08T09:00:00Z"
    }
  ]
}
```

---

### `POST /questions`
Post a new question with tags and an optional bounty.

**Auth required:** Yes

**Request body:**
```json
{
  "title": "How to solve a DP problem with bitmask?",
  "body": "I am stuck on this Codeforces problem...\n$$f(n) = \\sum_{i=0}^{n} i$$",
  "tags": ["dsa", "dynamic-programming"],
  "bounty_points": 30
}
```

> Note: `bounty_points` is deducted from the user's balance immediately. The user must have sufficient points.

**Response `201`:** Full question object.

---

### `GET /questions/{id}`
Fetch a single question with all its answers.

**Auth required:** No

**Response `200`:**
```json
{
  "id": "uuid",
  "title": "How to solve a DP problem with bitmask?",
  "body": "I am stuck on this Codeforces problem...",
  "tags": ["dsa", "dynamic-programming"],
  "bounty_points": 30,
  "is_solved": false,
  "vote_count": 4,
  "author": { "id": "uuid", "username": "saif_ahmed" },
  "answers": [ ],
  "created_at": "2025-01-08T09:00:00Z"
}
```

---

### `PATCH /questions/{id}`
Edit a question. Only the original author can edit.

**Auth required:** Yes (author only)

**Request body** (all fields optional):
```json
{
  "title": "Updated title",
  "body": "Updated body",
  "tags": ["math"]
}
```

**Response `200`:** Updated question object.

---

### `DELETE /questions/{id}`
Delete a question. Only the author can delete, and only if it has no accepted answer.

**Auth required:** Yes (author only)

**Response `204`:** No content.

---

### `GET /questions/search`
Full-text search across question titles and bodies.

**Auth required:** No

**Query params:**

| Param | Type | Description |
|---|---|---|
| `q` | string | Search query (required) |
| `page` | int | Page number |
| `limit` | int | Results per page |

**Response `200`:** Same shape as `GET /questions`.

---

## 4. Answers

### `GET /questions/{id}/answers`
List all answers for a question, sorted by votes then accepted status.

**Auth required:** No

**Response `200`:**
```json
{
  "answers": [
    {
      "id": "uuid",
      "body": "You should iterate over subsets using...",
      "is_accepted": true,
      "vote_count": 7,
      "author": { "id": "uuid", "username": "rifat_22" },
      "created_at": "2025-01-08T11:00:00Z"
    }
  ]
}
```

---

### `POST /questions/{id}/answers`
Submit a new answer to a question.

**Auth required:** Yes

**Request body:**
```json
{
  "body": "You should iterate over subsets using...\n```cpp\nfor (int mask = 0; mask < (1 << n); mask++)\n```"
}
```

**Response `201`:** Full answer object.

---

### `PATCH /answers/{id}`
Edit an existing answer. Only the author can edit.

**Auth required:** Yes (author only)

**Request body:**
```json
{
  "body": "Corrected explanation..."
}
```

**Response `200`:** Updated answer object.

---

### `DELETE /answers/{id}`
Delete an answer. Cannot delete an already-accepted answer.

**Auth required:** Yes (author only)

**Response `204`:** No content.

---

### `POST /answers/{id}/accept`
Mark an answer as accepted. Transfers the bounty points to the answer author. Only the question owner can accept.

**Auth required:** Yes (question owner only)

**Request body:** None.

**Response `200`:**
```json
{
  "message": "Answer accepted. 30 points transferred to rifat_22."
}
```

---

## 5. Votes

### `POST /questions/{id}/vote`
Upvote or downvote a question. Calling again with the same value removes the vote.

**Auth required:** Yes

**Request body:**
```json
{
  "value": 1
}
```

> `value` must be `1` (upvote) or `-1` (downvote).

**Response `200`:**
```json
{
  "vote_count": 5,
  "user_vote": 1
}
```

---

### `POST /answers/{id}/vote`
Upvote or downvote an answer. Same toggle logic as question votes.

**Auth required:** Yes

**Request body:**
```json
{
  "value": 1
}
```

**Response `200`:**
```json
{
  "vote_count": 7,
  "user_vote": 1
}
```

---

## 6. AI Hints

### `POST /ai/hint`
Request a Socratic AI hint for a question. Deducts 5 points from the requester's balance before calling the AI. Returns a guiding question or nudge, never the direct answer.

**Auth required:** Yes

**Request body:**
```json
{
  "question_id": "uuid",
  "user_context": "I tried using recursion but I'm getting TLE"
}
```

> The server checks the user has ≥ 5 points, deducts them, then calls the LLM. If the LLM call fails, points are refunded.

**Response `200`:**
```json
{
  "hint": "What would happen if instead of recomputing subproblems each time, you stored the result of each state? What data structure might help here?",
  "points_cost": 5,
  "remaining_points": 295
}
```

**Error `402`:** Insufficient points.
```json
{
  "error": "Not enough points. You need at least 5 points to request a hint."
}
```

---

### `POST /ai/scan`
Upload an image of a handwritten or printed problem. The AI extracts and returns the problem text.

**Auth required:** Yes

**Request body (`multipart/form-data`):**

| Field | Type | Description |
|---|---|---|
| `image` | file | JPEG or PNG, max 5MB |

**Response `200`:**
```json
{
  "extracted_text": "Find the sum of all prime numbers less than 100 using the Sieve of Eratosthenes.",
  "confidence": "high"
}
```

---

### `POST /ai/duplicate-check`
Check if a question is similar to an existing one before posting.

**Auth required:** Yes

**Request body:**
```json
{
  "title": "How does bitmask DP work?",
  "body": "I'm confused about iterating over subsets..."
}
```

**Response `200`:**
```json
{
  "is_duplicate": true,
  "similar_questions": [
    {
      "id": "uuid",
      "title": "How to solve a DP problem with bitmask?",
      "similarity_score": 0.91
    }
  ]
}
```

---

## 7. Daily Challenges

### `GET /challenges/today`
Fetch today's coding challenge fetched from the Codeforces API.

**Auth required:** No

**Response `200`:**
```json
{
  "id": "uuid",
  "codeforces_id": "1234A",
  "title": "Balanced Subsequence",
  "body": "Given an array of integers...",
  "difficulty": "medium",
  "source_url": "https://codeforces.com/problemset/problem/1234/A",
  "bonus_points": 50,
  "challenge_date": "2025-01-10",
  "solve_count": 12
}
```

---

### `GET /challenges`
List past daily challenges.

**Auth required:** No

**Query params:**

| Param | Type | Description |
|---|---|---|
| `page` | int | Page number |
| `limit` | int | Results per page (default `10`) |

**Response `200`:** Array of challenge objects.

---

### `POST /challenges/{id}/attempt`
Record that the user has started this challenge. Creates a `challenge_attempts` row with `is_solved: false`.

**Auth required:** Yes

**Request body:** None.

**Response `201`:**
```json
{
  "attempt_id": "uuid",
  "is_solved": false
}
```

---

### `POST /challenges/{id}/solve`
Mark a challenge as solved and award bonus points. Can only be called once per user per challenge.

**Auth required:** Yes

**Request body:** None.

**Response `200`:**
```json
{
  "message": "Challenge solved! +50 points awarded.",
  "points_awarded": 50,
  "remaining_points": 390,
  "streak_days": 6
}
```

---

### `GET /challenges/{id}/leaderboard`
Get the fastest solvers for a specific daily challenge.

**Auth required:** No

**Response `200`:**
```json
{
  "challenge_id": "uuid",
  "solvers": [
    {
      "rank": 1,
      "user": { "id": "uuid", "username": "ekram_32" },
      "solved_at": "2025-01-10T00:04:12Z"
    }
  ]
}
```

---

## 8. Leaderboard & Badges

### `GET /leaderboard`
Get top users ranked by points.

**Auth required:** No

**Query params:**

| Param | Type | Description |
|---|---|---|
| `period` | string | `weekly` (default) or `all` |
| `limit` | int | Number of results (default `20`, max `100`) |

**Response `200`:**
```json
{
  "period": "weekly",
  "rankings": [
    {
      "rank": 1,
      "user": { "id": "uuid", "username": "rifat_22", "avatar_url": "..." },
      "points": 520
    }
  ]
}
```

---

### `GET /badges`
List all available badges in the system.

**Auth required:** No

**Response `200`:**
```json
{
  "badges": [
    {
      "id": "uuid",
      "name": "first_answer",
      "description": "Submitted your first answer",
      "icon_url": "https://storage.supabase.co/badges/first_answer.png"
    },
    {
      "id": "uuid",
      "name": "streak_5",
      "description": "Maintained a 5-day activity streak",
      "icon_url": "https://storage.supabase.co/badges/streak_5.png"
    },
    {
      "id": "uuid",
      "name": "bounty_hunter",
      "description": "Won 10 bounties",
      "icon_url": "https://storage.supabase.co/badges/bounty_hunter.png"
    }
  ]
}
```

---

## 9. Notifications

### `GET /notifications`
Get in-app notifications for the authenticated user, newest first.

**Auth required:** Yes

**Query params:**

| Param | Type | Description |
|---|---|---|
| `unread_only` | boolean | If `true`, returns only unread notifications |

**Response `200`:**
```json
{
  "unread_count": 3,
  "notifications": [
    {
      "id": "uuid",
      "type": "answer_received",
      "message": "rifat_22 answered your question about bitmask DP",
      "reference_id": "answer-uuid",
      "is_read": false,
      "created_at": "2025-01-10T08:30:00Z"
    }
  ]
}
```

**Notification types:**

| Type | Trigger |
|---|---|
| `answer_received` | Someone answered your question |
| `answer_accepted` | Your answer was accepted |
| `bounty_awarded` | You received bounty points |
| `vote_received` | Your question or answer was upvoted |
| `badge_earned` | You earned a new badge |

---

### `PATCH /notifications/{id}/read`
Mark a single notification as read.

**Auth required:** Yes

**Response `200`:**
```json
{
  "id": "uuid",
  "is_read": true
}
```

---

### `PATCH /notifications/read-all`
Mark all notifications as read.

**Auth required:** Yes

**Response `200`:**
```json
{
  "updated": 3
}
```

---

### `POST /notifications/fcm-token`
Register a Firebase Cloud Messaging token for push notifications.

**Auth required:** Yes

**Request body:**
```json
{
  "token": "fcm-device-token-string"
}
```

**Response `201`:**
```json
{
  "message": "FCM token registered."
}
```

---

## 10. Tags

### `GET /tags`
List all available tags for filtering questions.

**Auth required:** No

**Response `200`:**
```json
{
  "tags": [
    { "id": "uuid", "name": "dsa" },
    { "id": "uuid", "name": "math" },
    { "id": "uuid", "name": "physics" },
    { "id": "uuid", "name": "dynamic-programming" },
    { "id": "uuid", "name": "calculus" },
    { "id": "uuid", "name": "graph-theory" }
  ]
}
```

---

## Error Responses

All endpoints return errors in this consistent shape:

```json
{
  "error": "Human-readable error message",
  "code": "MACHINE_READABLE_CODE"
}
```

Common HTTP status codes used across the API:

| Status | Meaning |
|---|---|
| `200` | OK |
| `201` | Created |
| `204` | No Content |
| `400` | Bad Request — missing or invalid fields |
| `401` | Unauthorized — missing or expired token |
| `403` | Forbidden — authenticated but not allowed |
| `402` | Payment Required — insufficient points |
| `404` | Not Found |
| `409` | Conflict — e.g. duplicate vote, already solved |
| `422` | Unprocessable Entity — validation error |
| `500` | Internal Server Error |