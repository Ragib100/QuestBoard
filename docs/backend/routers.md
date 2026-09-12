# Routers

Every HTTP endpoint the server declares, file by file. Routers are thin: they
choose a path and a status code, inject dependencies, call a service, and
translate the exception it raised. **No router touches the database.**

For request/response bodies and product behaviour, read [api.md](api.md) — this
page is about the declarations themselves.

**41 routes total** (40 excluding the unauthenticated liveness root): 39 across
the seven router modules plus `GET /api/` and `GET /api/ping` in `main.py`.

## Mounting — `app/main.py`

```python
app = FastAPI(title="QuestBoard API", version="0.1.0")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, ...)

api_router = APIRouter(prefix="/api")
# user, question, answer, gamification, challenge, ai, admin
app.include_router(api_router)
```

Everything lives under `/api`. CORS is opt-in via `CORS_ORIGINS` because Flutter
web runs in a browser and is blocked without it; Android, desktop and the test
harness are unaffected either way.

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/` | none | Liveness. What uptime pings and Render health checks hit |
| GET | `/api/ping` | required | Returns `{user_id}` — verifies a token end to end |

## Auth dependencies

Three, from `app/dependencies/`:

| Dependency | Behaviour |
|---|---|
| `get_current_user_id` | Verifies the bearer token via `supabase-py`. `401` on missing, malformed or expired |
| `get_optional_user_id` | Returns the id when a valid token is present, `None` otherwise — **never rejects**. Used wherever browsing is public but a signed-in viewer gets extra fields (`my_vote`, `my_attempt`, their own rank) |
| `require_admin` | `get_current_user_id` plus a `users.is_admin` lookup. `403 Admins only.` otherwise. The flag is read from the database on every call, so revoking admin takes effect on the next request |

Suspension is **not** enforced here — the token knows nothing about
`is_suspended`. `UserService.require_active` checks it inside each write path
([../decisions.md](../decisions.md) D22).

---

## `routers/user.py` — prefix `/users`, tag `Users`

| Method | Path | Auth | Response | Service |
|---|---|---|---|---|
| POST | `` | required | `201 UserResponse` | `UserService.create_user` |
| GET | `/me` | required | `UserResponse` | `UserService.get` |
| GET | `/me/codeforces/verification` | required | `VerificationChallenge` | `codeforces_service.verification_problem` |
| POST | `/me/codeforces/verification` | required | `UserResponse` | `codeforces_service.has_compile_error` |
| GET | `/{user_id}` | **public** | `UserResponse` | `UserService.get` |
| PATCH | `/{user_id}` | required | `UserResponse` | `UserService.update` |
| GET | `/{user_id}/points` | **public** | `PointsResponse` | `UserService.points` |
| GET | `/{user_id}/badges` | **public** | `list[EarnedBadge]` | `BadgeService.for_user` |
| GET | `/{user_id}/streak` | **public** | `StreakResponse` | `UserService.get` |

Query params: `/points` takes `limit` (default 50).

`GET /me` returning `404` is meaningful: the caller has a valid Supabase session
but no `users` row, which means they never finished onboarding. The client
routes that to `ProfileCreate`.

`PATCH /{user_id}` refuses any id but the caller's own with `403`, and `409` on a
username collision.

## `routers/question.py` — prefix `/questions`, tag `Quests`

| Method | Path | Auth | Response | Service |
|---|---|---|---|---|
| GET | `` | optional | `QuestionPage` | `QuestionService.list_page` |
| POST | `` | required | `201 QuestionDetail` | `QuestionService.create` |
| GET | `/{question_id}` | optional | `QuestionDetail` | `QuestionService.get(count_view=True)` |
| PATCH | `/{question_id}` | required | `QuestionDetail` | `QuestionService.update` |
| DELETE | `/{question_id}` | required | `204` | `QuestionService.delete` |
| POST | `/{question_id}/answers` | required | `201 AnswerResponse` | `AnswerService.create` |
| POST | `/{question_id}/vote` | required | `VoteResponse` | `VoteService.cast` |

`GET ""` query params, all validated by FastAPI before the service sees them:

| Param | Type | Default | Constraint |
|---|---|---|---|
| `page` | int | 1 | `≥ 1` |
| `limit` | int | 20 | `1–50` |
| `tag` | str? | — | matched lowercase against `tags.name` |
| `sort` | str | `latest` | `^(latest\|bounty\|votes)$` |
| `search` | str? | — | `ILIKE '%term%'` over title and body |

`POST ""` is the one place the router makes a judgement: a `ValueError` whose
message mentions "points" becomes `402 Payment Required` rather than `400`,
because an unaffordable bounty is a payment problem, not a typo.

`POST /{id}/vote` commits (and rolls back) around `VoteService.cast` itself —
voting is a complete unit of work with no second step.

## `routers/answer.py` — prefix `/answers`, tag `Answers`

| Method | Path | Auth | Response | Service |
|---|---|---|---|---|
| PATCH | `/{answer_id}` | required | `AnswerResponse` | `AnswerService.update` |
| DELETE | `/{answer_id}` | required | `204` | `AnswerService.delete` |
| POST | `/{answer_id}/accept` | required | `AnswerResponse` | `AnswerService.accept` |
| POST | `/{answer_id}/vote` | required | `VoteResponse` | `VoteService.cast` |

`404` unknown · `403` not the author (or, on accept, not the quest author) ·
`409` the answer is accepted, or the quest is already solved.

## `routers/gamification.py` — no prefix, tag `Gamification`

| Method | Path | Auth | Response |
|---|---|---|---|
| GET | `/leaderboard` | optional | `LeaderboardResponse` |
| GET | `/badges` | **public** | `list[BadgeResponse]` |
| GET | `/notifications` | required | `NotificationPage` |
| GET | `/notifications/unread-count` | required | `{unread_count}` |
| PATCH | `/notifications/read-all` | required | `{marked}` |
| PATCH | `/notifications/{notification_id}/read` | required | `NotificationResponse` |

`/leaderboard` takes `period` (`^(weekly|all_time)$`, default `all_time`) and
`limit` (1–50, default 20). A signed-in caller also gets `me` — their own rank
pinned, even when they are outside the returned page.

Route order matters: `/notifications/unread-count` and
`/notifications/read-all` are declared **before** `/notifications/{id}/read`, so
the literal paths are not swallowed by the parameterised one.

Reading someone else's notification is `403`.

## `routers/challenge.py` — prefix `/challenges`, tag `Daily challenge`

| Method | Path | Auth | Response |
|---|---|---|---|
| GET | `/today` | optional | `TodayResponse` (= `ChallengeView`) |
| GET | `` | optional | `ChallengePage` |
| GET | `/{challenge_id}` | optional | `ChallengeView` |
| GET | `/{challenge_id}/statement` | **public** | `ProblemStatement` |
| POST | `/{challenge_id}/solve` | required | `AttemptResponse` |
| PUT | `/{challenge_id}/submission` | required | `AttemptResponse` |
| GET | `/{challenge_id}/leaderboard` | **public** | `list[ChallengeSolver]` |

Archive query params: `page` (≥1), `limit` (1–50), `include_today` (bool,
default false).

Two module helpers keep the calendar honest:

- `_today_here()` → `clock.today()`, the Dhaka calendar day. Ages and decay are
  counted in Dhaka days, never UTC days.
- `_viewer_is_verified(db, viewer_id)` → whether the caller may claim at all.

`GET /today` returns `503` only when Codeforces is unreachable *and* there is not
a single stored challenge to fall back on. When it falls back, `is_today` is
`false` and the client says so rather than mislabelling the problem.

Status codes unique to this router: `502` when Codeforces itself is unreachable
during a claim, `503` on the no-challenge-at-all case.

## `routers/ai.py` — prefix `/ai`, tag `AI`

| Method | Path | Auth | Response |
|---|---|---|---|
| GET | `/hint` | required | `HintStatus` |
| POST | `/hint` | required | `HintResponse` |

The exception mapping is wider here than anywhere else, because four different
things can go wrong and they need four different answers:

| Raised | Status | Means |
|---|---|---|
| `LookupError` | `404` | Unknown quest, or the caller has no profile |
| `PermissionError` | `429` | Past the 3-per-hour cap |
| `ValueError` | `402` | Under 5 points |
| `AiHintError` | `503` | No provider configured, or the model call failed |

A `503` always means **nothing was charged** — the deduction and the model call
share one transaction, which is rolled back on failure.

## `routers/admin.py` — prefix `/admin`, tag `admin`

Every route depends on `require_admin`.

| Method | Path | Response | Service |
|---|---|---|---|
| GET | `/stats` | `AdminStats` | `AdminService.stats` |
| GET | `/users` | `AdminUserPage` | `AdminService.list_users` |
| PATCH | `/users/{user_id}/suspend` | `AdminUser` | `AdminService.set_suspended` |
| DELETE | `/quests/{question_id}` | `204` | `AdminService.delete_quest` |

`/users` takes `page` (≥1), `limit` (1–50, default 20) and `search` over
username and first/last name — **not email**, which lives in `auth.users` and is
never copied into our schema.

`PATCH .../suspend` takes `{suspended: bool}`, explicit rather than a toggle, so
two admins acting at once cannot flip each other's decision. Suspending yourself
or another admin is `403`.

`DELETE /quests/{id}` is the only path that bypasses both the author check and
the has-answers rule. It refunds the bounty **unless** the quest was already
solved — that bounty is with the helper, and refunding it would mint points.
