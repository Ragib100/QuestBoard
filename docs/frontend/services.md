# Services and models

Everything in `client/lib/services/` and `client/lib/models/`. **A widget never
calls `http` and never builds a URL** — it calls a service, and the service calls
`ApiClient`.

Every service is a singleton with a private constructor:

```dart
class QuestService {
  QuestService._();
  static final QuestService instance = QuestService._();
}
```

---

## `ApiClient` — `services/api/api_client.dart`

275 lines. The one place that knows how to reach the API: base URL, bearer token,
JSON decoding, and turning failures into `ApiException`s.

### Timeouts

| Constant | Value | For |
|---|---|---|
| `defaultTimeout` | 10s | Long enough for a cold Render dyno, short enough that a wrong `API_URL` surfaces as an error instead of a frozen screen |
| `fastTimeout` | 4s | Calls made while the user stares at a blank screen — startup routing would rather guess quickly than block |
| `_probeTimeout` | 3s | One reachability probe |

### Multi-candidate base URL

`API_URL` may hold several comma-separated candidates. A phone plugged in over
USB reaches the dev machine at `localhost` (with `adb reverse`), an emulator at
`10.0.2.2`, and a phone on the same Wi-Fi at the laptop's LAN address — which
changes whenever the network does. Listing all three and letting the app find the
live one removes the single most common cause of "cannot reach the server": an
`API_URL` that was correct last week.

`_probe()` fires `GET {base}/api/` at **every** candidate at once and keeps the
first that answers `200`, caching it for the process lifetime. When none answer
it falls back to the first candidate, so the resulting failure is a normal
"could not reach the server" rather than a malformed URL. A single candidate
skips the probe entirely.

`_invalidateBase()` clears that cache whenever a request fails at the network
layer, so moving between Wi-Fi and USB recovers on retry instead of needing an
app restart.

### Methods

`get` · `post` · `patch` · `put` · `delete`, all returning the decoded JSON
(`null` on `204` or an empty body).

`_headers({auth = true})` attaches
`Authorization: Bearer ${session.accessToken}`. If the session is null it
throws rather than sending an unauthenticated request.

### Retry, and why only reads

`_send` retries on a backoff (`_readBackoff`) **only when `retry` is set, and
only `get` sets it.** A network failure means we never learned whether the
request arrived, so replaying a `POST` could accept an answer twice or claim a
challenge twice.

### `ApiException`

| Member | Meaning |
|---|---|
| `message` | Always safe to show a user — the API's `detail` string, never a raw exception |
| `statusCode` | |
| `isOffline` | **The request never reached a server** |
| `isNotFound` | `404` — authenticated but not onboarded |
| `isPaymentRequired` | `402` — not enough points |

`isOffline` is worth distinguishing because it is the only failure that fixes
itself: a `403` will still be a `403` in ten seconds, so the screen shows it and
stops, while this one is worth waiting through. Pass it to `ErrorState(offline:)`
and the screen shows a reconnecting spinner that retries itself instead of
demanding a tap ([../decisions.md](../decisions.md) D46).

`_detailOf` flattens both FastAPI error shapes: `{"detail": "..."}` and the
validation form where `detail` is a list of field objects.

---

## Service singletons — `services/common/`

### `AuthService` — 82 lines

The only service that talks to **Supabase**, not to FastAPI. FastAPI issues no
tokens.

| Method | Does |
|---|---|
| `signUp({email, password, ...})` | Sends the verification email |
| `resendVerification({email})` | |
| `login({email, password})` | |
| `logout()` | |
| `forgotPassword({email})` | `resetPasswordForEmail` |
| `updatePassword({password})` | Only valid during a `passwordRecovery` session |
| `currentUser` / `currentSession` | Getters |

### `UserService` — 160 lines

| Method | Endpoint |
|---|---|
| `createUser(...)` | `POST /users` |
| `me({timeout})` | `GET /users/me` |
| `getProfile(userId)` | `GET /users/{id}` |
| `updateProfile(...)` | `PATCH /users/{id}` |
| `points(userId, {limit})` | `GET /users/{id}/points` → `(balance, entries)` |
| `uploadAvatar(File)` | Straight to the `profile_image` bucket — **the server never sees the bytes** |
| `avatarUrl(storagePath)` | Turns the stored path into a public URL |

`image_url` on the profile is a **storage path** (`<uid>/<epoch>.png`), not a
URL. `avatarUrl` is what makes it displayable.

### `QuestService` — 92 lines

| Method | Endpoint |
|---|---|
| `list({page, limit, tag, sort, search})` | `GET /questions` → `QuestPage` |
| `get(id, {authenticated})` | `GET /questions/{id}` |
| `create({title, body, tags, bountyPoints})` | `POST /questions` |
| `delete(id)` | `DELETE /questions/{id}` |
| `answer(questId, body, {submission})` | `POST /questions/{id}/answers` |
| `accept(answerId)` | `POST /answers/{id}/accept` |
| `voteQuest(id, value)` / `voteAnswer(id, value)` | → `(count, mine)` |

### `GamificationService` — 71 lines

`leaderboard({period, limit})` · `badgesFor(userId)` · `notifications()` →
`(items, unread)` · `unreadCount()` · `markRead(id)` · `markAllRead()`.

`badgesFor` merges the catalogue with the user's earned badges, so locked ones
stay visible with their condition (D21, D50).

### `ChallengeService` — 125 lines

`today({authenticated})` · `detail(id)` · `archive({page, limit, includeToday})`
· `claim(...)` · `saveSubmission(...)` · `statement(id)` · `leaderboard(id)` ·
`verificationChallenge()` · `confirmVerification()`.

`claim` and `saveSubmission` are separate calls because they are separate acts
(D38): saving code needs no verdict and no verified handle.

### `HintService` — 29 lines

`status()` → `HintStatus` · `forQuest(questId)` → `AiHint`.

`status()` is called **before** the button renders, so it can say what a hint
costs and hide itself entirely when the server has no provider (ground rule 4).

### `AdminService` — 43 lines

`stats()` · `users({page, limit, search})` · `setSuspended(userId, suspended)` ·
`deleteQuest(questId)`.

### `AttachmentService` — 119 lines

`pickAndUpload()` → `UploadedFile?`. Uses `file_picker`, which returns **bytes**
on every platform — `image_picker` only picks images, and the web build has no
filesystem to read a path from. Uploads to the public `submissions` bucket and
returns the public URL plus the original filename. Throws
`AttachmentException`.

### `SupabaseServices` — 64 lines

The Storage wrapper: `uploadImage`, `uploadBytes`, `deleteImage`,
`getPublicUrl`. Storage is **client-direct** — the server never proxies file
bytes ([../architecture.md](../architecture.md)).

---

## Models — `client/lib/models/`

Plain data classes with `fromJson` factories. Timestamps go through
`parseServerTime` from [`core/app_time.dart`](core.md#app_timedart), never
`DateTime.parse`.

### `quest.dart` — 207 lines

| Class | Fields |
|---|---|
| `UserSummary` | `id`, `username`, `firstName`, `lastName`, `imageUrl`, `points`, + `displayName` |
| `Answer` | body, `submission`, `isAccepted`, `author`, `voteCount`, `myVote`, `createdAt` |
| `Quest` | title, body, `bountyPoints`, `isSolved`, `viewCount`, tags, counts, `answers` |
| `QuestPage` | `items`, `page`, `limit`, `total`, `hasMore` |

### `profile.dart` — 86 lines

`Profile` mirrors `UserResponse`: id, username, names, phone, `imageUrl`,
`codeforcesHandle`, `codeforcesVerified`, `points`, `streakDays`, `isAdmin`,
`isSuspended`, `createdAt` — plus a `displayName` getter that goes through
`core/display_name.dart`, so an email never reaches the screen.

`PointEntry` — `amount`, `reason`, `createdAt`, and a `label` getter that turns a
`PointReason` string into readable text.

### `challenge.dart` — 288 lines

| Class | Notes |
|---|---|
| `DailyChallenge` | + `submitUrl`, `awardPoints`, `ageDays` (all computed server-side per request) and `isAtFloor` |
| `ChallengeAttempt` | `isSolved`, `solvedAt`, `awardedPoints`, `submission` |
| `TodayChallenge` | `challenge`, `isToday`, `solverCount`, `myAttempt`, `codeforcesVerified`, `isSolved` |
| `ChallengeSolver` | `rank`, `solvedAt`, `user`, `awardedPoints` |
| `StatementSample` / `ProblemStatement` | `available`, `html`, limits, samples, urls |
| `CodeforcesVerification` | `handle`, `codeforcesId`, `problemUrl`, `submitUrl` |
| `ChallengePage` | The standard page shape |

`awardPoints` is what the row advertises, because it is what the server will
actually pay — `bonusPoints` alone would be a number the API refuses to honour.

### `gamification.dart` — 139 lines

`AchievementBadge` (with `description`, which **is** the condition),
`LeaderboardEntry`, `Leaderboard` (entries + `me`), `NotificationType`,
`AppNotification`.

### `admin.dart` — 100 lines

`AdminStats`, `AdminUser` (with `displayName` and `initial`), `AdminUserPage`.

### `code_submission.dart` — 56 lines

`CodeSubmission` — `codeBody`, `codeLanguage`, `attachmentUrl`,
`attachmentName`, plus `hasCode`, `hasAttachment`, `isEmpty`. Shared by answers
and challenge attempts, mirroring `server/app/schemas/code.py`.

### `ai_hint.dart` — 43 lines

`HintStatus` (`available`, `pointsCost`, `hintsRemaining`) and `AiHint`
(`hintText`, `pointsCost`, `pointsRemaining`, `hintsRemaining`).
