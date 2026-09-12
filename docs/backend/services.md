# Services

Every business rule in QuestBoard lives here. Services are classes of static and
class methods that take a `Session`, do the work, and raise a plain Python
exception on a domain violation. They know nothing about HTTP.

Fourteen modules in `server/app/services/`:

| Module | Owns |
|---|---|
| [`point_service.py`](#pointservice) | The only writer of `users.points` |
| [`user_service.py`](#userservice) | Profiles, suspension gate, the ledger read |
| [`question_service.py`](#questionservice) | The quest feed, search, create/update/delete |
| [`answer_service.py`](#answerservice) | Answers and the bounty transfer |
| [`vote_service.py`](#voteservice) | Up/down votes and the ±1 to the author |
| [`activity_service.py`](#activityservice) | Streaks and the daily bonus |
| [`badge_service.py`](#badgeservice) | Awarding achievements inline |
| [`notification_service.py`](#notificationservice) | In-app notifications |
| [`leaderboard_service.py`](#leaderboardservice) | Weekly and all-time rankings |
| [`challenge_service.py`](#challengeservice) | The daily challenge, its archive and decay |
| [`codeforces_service.py`](#codeforces_service) | The public Codeforces API client |
| [`statement_service.py`](#statement_service) | Scraping and sanitising a problem statement |
| [`ai_service.py`](#aiservice) | Socratic hints, rate limiting, the charge-and-refund |
| [`admin_service.py`](#adminservice) | Moderation, deliberately bypassing ownership checks |

---

## `PointService`

`point_service.py` · 65 lines · **the most important file in the server.**

```python
PointService.apply(db, user, amount, reason, reference_id=None, allow_negative=False)
    -> PointTransaction | None
```

Moves `amount` points (negative to deduct), writes the ledger row and updates
the cached balance **in the same unit of work**, so the two can never drift.

- Raises `ValueError` when a deduction would take the balance below zero, so the
  caller can turn it into a `402` before anything else has happened.
- Returns `None` for a zero movement — `users.points` does not change and a
  ledger row saying so is noise in someone's history.
- **Never commits.** It flushes (the session runs with `autoflush=False`, so a
  badge check counting bounties later in the same transaction would otherwise
  not see the row) and leaves the transaction to the caller.
- `allow_negative=True` exists for exactly one caller: a downvote debiting an
  author who has already spent everything. Refusing it would fail *the voter's*
  request, and clamping at zero would let a downvote-then-upvote flip mint the
  difference. A balance that dips below zero is the honest record.

See [../db/economy.md](../db/economy.md) for the full ledger contract.

## `UserService`

`user_service.py` · 145 lines.

| Method | Behaviour |
|---|---|
| `require_active(db, user_id)` | The suspension gate. Returns the user, or raises `PermissionError` when `is_suspended`. Called at the top of every write path |
| `create_user(db, user_id, user_data)` | Creates the profile after email verification. `ValueError` if the row exists or the username is taken |
| `get(db, user_id)` | `LookupError` when there is no row — which is how the client learns someone is mid-onboarding |
| `update(db, user_id, user_data)` | Own profile only. Changing `codeforces_handle` clears `codeforces_verified` |
| `points(db, user_id, limit=50)` | `{balance, transactions}`, newest first |

`create_user` deliberately sets `points=0` on the new row rather than taking the
column's default of 100, then pays the signup bonus through `PointService`.
Taking the default would leave every account holding 100 points no transaction
explains, and `users.points` is meant to be a cache of the ledger's sum.

## `QuestionService`

`question_service.py` · 277 lines.

| Method | Behaviour |
|---|---|
| `create(db, user_id, data)` | Records activity **first**, then charges the bounty — a user whose streak payment would cover the cost should not be refused. `ValueError` on an unknown tag or an unaffordable bounty |
| `list_page(db, page, limit, tag, sort, search)` | The feed. Returns `(items, total)` with per-row vote and answer counts as subquery aggregates |
| `get(db, question_id, count_view=False)` | One quest. `count_view=True` increments `view_count` |
| `update(db, question_id, user_id, data)` | Author only. Bounty is not editable |
| `delete(db, question_id, user_id)` | Author only, and only while unanswered. Refunds the bounty and deletes the quest's votes by hand — `votes.target_id` is polymorphic, so no foreign key cascades it |
| `enrich(db, question, viewer_id)` | Stitches vote counts, answers and the viewer's own votes onto a loaded row |

**Sorting and search.** `sort` is one of `latest`, `bounty`, `votes`; anything
else raises `ValueError`. When `search` is present and `sort` is still the
default `latest`, results are ordered title-hits-first — a search has its own
idea of "best first". An explicit `bounty` or `votes` is the user overriding
that, so it still wins.

`ILIKE '%term%'` cannot use a B-tree, which is why `schema.sql` creates GIN
trigram indexes over `title` and `body` ([../db/indexes-and-rls.md](../db/indexes-and-rls.md)).

## `AnswerService`

`answer_service.py` · 203 lines.

| Method | Behaviour |
|---|---|
| `create(db, question_id, user_id, data)` | `LookupError` unknown quest · `ValueError` the quest is solved · `PermissionError` answering your own quest. Records activity, syncs badges, notifies the quest author |
| `update(db, answer_id, user_id, data)` | Author only, and never an accepted answer |
| `delete(db, answer_id, user_id)` | Same guards |
| `accept(db, answer_id, user_id)` | **The core of the economy** |

`accept` is one transaction doing five things: mark the answer accepted, close
the quest, credit the helper with the bounty, write the `bounty_awarded` ledger
row, and notify. A partial apply here would create or destroy points.

The bounty is only *credited* here — it was debited from the asker at post time,
so accepting does not touch the asker's balance. Winning it can unlock
`first_bounty` or `bounty_hunter`, so `BadgeService.sync` runs on the helper
before the commit.

Guards: `403` not the quest author · `409` already solved.

## `VoteService`

`vote_service.py` · 125 lines.

| Method | Behaviour |
|---|---|
| `count_for(db, target_type, target_id)` | `SUM(value)`, coalesced to 0 |
| `my_vote(db, user_id, target_type, target_id)` | `1`, `-1` or `0` |
| `cast(db, user_id, target_type, target_id, value)` | Returns `(vote_count, my_vote)` |

Toggle rules: the **same** value again clears the vote, the **opposite** flips
it. The author's balance moves by the *delta* between the old and new vote,
never recomputed from scratch, so the ledger stays a true history — a flip from
−1 to +1 writes a movement of 2, not two separate rows.

Self-voting raises `PermissionError`. The unique constraint on
`(user_id, target_type, target_id)` is what makes a race collide safely.

## `ActivityService`

`activity_service.py` · 61 lines · `DAILY_BONUS = 10`.

`record(db, user)` updates the streak and grants the once-a-day bonus, returning
`True` when this was the user's first activity today.

- Called at the start of every action that counts as **participating** — posting,
  answering, accepting, voting. Reading never counts, or opening the app would
  be enough to keep a streak alive.
- Yesterday → `streak_days += 1`. Any other gap → `streak_days = 1`.
- `last_active` is stored without a zone on some rows and is always UTC, so it
  is converted to **Dhaka** before the day is compared: the day a streak counts
  is the user's day, not Greenwich's.
- Does not commit — the bonus and the action that earned it either both land or
  neither does.

## `BadgeService`

`badge_service.py` · 165 lines.

| Method | Behaviour |
|---|---|
| `sync(db, user)` | Awards every badge the user's current stats justify; returns the newly granted ones |
| `award(db, user, code)` | Grants one badge if not already held |
| `for_user(db, user_id)` | Earned badges with `awarded_at` |
| `catalogue(db)` | Every badge that exists |

Checks run **inline**, in the same transaction as the event that triggered them,
not as a background task ([../decisions.md](../decisions.md) D18). They are three
cheap `COUNT`s, and running them inline means a badge can never be silently lost
when a worker dies.

Awarding is idempotent: `user_badges` has a composite primary key, so a repeat
award conflicts and is skipped.

`_qualifying_codes` is the whole rule set:

| Badge | Condition |
|---|---|
| `first_answer` | `≥ 1` answer posted |
| `first_bounty` | `≥ 1` `bounty_awarded` ledger row |
| `bounty_hunter` | `≥ 10` of them |
| `streak_5` / `streak_30` | `streak_days ≥ 5` / `≥ 30` |
| `challenger` | `≥ 7` daily challenges solved |
| `ai_skeptic` | an accepted answer on a quest you bought no AI hint for |
| `top_helper` | **not awarded** — needs a weekly-rank check on a schedule |

`ChallengeService` is imported inside the method, not at module scope: it awards
badges after a solve, so a module-level import would close the cycle.

## `NotificationService`

`notification_service.py` · 95 lines.

| Method | Behaviour |
|---|---|
| `create(db, user_id, notification_type, message, reference_id)` | Adds a row; does not commit |
| `list_for(db, user_id, ...)` | Paginated, newest first |
| `unread_count(db, user_id)` | One `COUNT` — what the nav bell polls |
| `mark_read(db, notification_id, user_id)` | `PermissionError` on someone else's |
| `mark_all_read(db, user_id)` | Returns how many were marked |

Four types are produced: `answer_received`, `answer_accepted`, `bounty_awarded`,
`badge_earned`. `vote_received` exists in the enum and the CHECK constraint but
is deliberately never created — votes do not notify
([../decisions.md](../decisions.md) D19).

## `LeaderboardService`

`leaderboard_service.py` · 88 lines · periods `weekly` and `all_time`.

- **All-time** reads `users.points` directly.
- **Weekly** sums `point_transactions` over the last seven days. No cron, no
  snapshot table, no Monday morning where the reset did not run — the ledger is
  already an append-only history, so the number can always be recomputed
  ([../decisions.md](../decisions.md) D17).

The weekly window uses `clock.naive_utc_now()`, because
`point_transactions.created_at` is `timestamp without time zone`; handing
Postgres an aware value made the comparison depend on the session timezone.

`rank_of(db, user_id, period)` returns the caller's own standing so it can be
pinned outside the top. `rank` is `None` when they have earned nothing in the
period — an honest "unranked", not a fabricated last place.

## `ChallengeService`

`challenge_service.py` · 472 lines — the largest service.

| Method | Behaviour |
|---|---|
| `today(db)` | Today's challenge, creating it from Codeforces on the first request of the day |
| `get(db, challenge_id)` | One challenge, `LookupError` if missing |
| `archive_page(db, page, limit, include_today, viewer_id)` | Past challenges with the viewer's attempt and solver counts |
| `statement(db, challenge_id)` | Cached scrape, or a fresh fetch |
| `award_now(challenge)` | `award_for(bonus_points, challenge_date)` as of today |
| `attempt_of(db, challenge_id, user_id, for_update=False)` | The caller's attempt row |
| `solver_count` / `solved_by` | Counts |
| `save_submission(...)` | Stores code on the attempt **without** touching Codeforces |
| `claim(db, challenge_id, user_id, data=None)` | Verifies against Codeforces, then pays |
| `leaderboard(db, challenge_id, limit=50)` | Solvers by `solved_at` with the award each received |

**There is no cron.** Today's row is created lazily by whoever asks first.
`daily_challenges.challenge_date` is unique, so a race between two first-askers
hits an `IntegrityError` and re-reads the row the other one inserted.

When Codeforces is unreachable, `today()` falls back to the most recent stored
challenge and the router labels it `is_today: false` — a real problem with an
honest label beats an error or an invented one. `LookupError` only when there is
not a single stored challenge.

**`claim` in order:** verified handle → not already claimed → the challenge has a
Codeforces problem → an `OK` verdict dated **on or after midnight Dhaka on
`challenge_date`** → pay `award_for(...)` → store the submission → award
`challenge_solved`. An accepted submission from before the challenge opened does
not pay, and the refusal says which of the two cases it is
([../decisions.md](../decisions.md) D31).

A failed check still records an **unsolved** attempt, with the code, so nothing
typed is lost.

**`save_submission` is a different act from claiming** ([../decisions.md](../decisions.md)
D38): it works before the problem is solved, after it is solved, and without a
verified handle. Requiring a Codeforces verdict to save a draft meant there was
no way to submit code at all.

## `codeforces_service`

`codeforces_service.py` · 218 lines · module-level functions, not a class.

Thin client for the **public, read-only** Codeforces API
(`https://codeforces.com/api`), timeout 8s. Codeforces has no submit method and
no statement method, which is the whole reason the app hosts their pages in a
WebView instead ([../decisions.md](../decisions.md) D43).

| Function | Purpose |
|---|---|
| `pick_problem(seed)` | Deterministic daily pick, rated `MIN_RATING 800`–`MAX_RATING 1600` |
| `problem_url(id)` / `submit_url(id)` | Derived from `"1873/D"`, never stored |
| `difficulty_for(rating)` | → `easy` / `medium` / `hard` |
| `solved_at(handle, id, since)` | The earliest qualifying `OK`, or `None` |
| `has_solved(handle, id, since)` | Boolean form of the above |
| `last_attempt_at(handle, id)` | Used to explain *why* a claim failed |
| `verification_problem(user_id)` | Deterministic per user — nothing stored server-side |
| `has_compile_error(handle, id)` | The handle-ownership proof, within `VERIFICATION_WINDOW` (30 min) |

Paging stops at `MAX_SUBMISSIONS_SCANNED = 1000` (`PAGE_SIZE = 100`), and stops
early once the scan is past the `since` bound. Raises `CodeforcesError`, which
the routers turn into `502`.

## `statement_service`

`statement_service.py` · 185 lines.

The one place this app parses someone else's HTML. `fetch(codeforces_id)` gets
the problem page, lifts `div.problem-statement` out of it, and returns a
`Statement` with `html`, `time_limit`, `memory_limit` and `samples`.

Sanitisation is not optional — the client renders this in a WebView:

- `_FORBIDDEN_TAGS` (`script`, `style`, `iframe`, `object`, `embed`, `form`,
  `link`) are removed entirely.
- Every `on*` event attribute is stripped (`_EVENT_ATTR`).
- Every URL is absolutised against `ORIGIN`.

Statements never change, so a success is cached on
`daily_challenges.statement` **forever** and a failure is **never** cached —
Cloudflare lets the next caller through often enough that one refusal must not
become a permanent "no statement" ([../decisions.md](../decisions.md) D45).

That scrape fails far more in production than in development, and the difference
is the IP: Cloudflare reads a datacenter address as a robot and a phone's as a
person. So `available: false` is the *common* answer on the deployed API, and
the mobile client reads the page itself instead (D47).

## `AiService`

`ai_service.py` · 222 lines.

Constants: `HOURLY_LIMIT = 3` · `MAX_TOKENS = 2000` · `TIMEOUT = 45.0` ·
`HINT_COST = 5` (in `models/ai_hint.py`).

| Method | Behaviour |
|---|---|
| `is_configured()` | Whether any provider is set — drives `available` on `GET /ai/hint` |
| `hint(db, question_id, user_id)` | Returns `(hint_text, points_remaining)` |
| `remaining_today(db, user_id)` | Hints left this hour |

Two providers, tried in order: `_ask_openai_compatible` (any OpenAI-compatible
`/chat/completions` — Gemini, Groq, OpenRouter, Cerebras all expose one and all
have a free tier) and `_ask_anthropic`. `AI_BASE_URL` wins when set.

`SYSTEM_PROMPT` makes it a **Socratic tutor**: it asks guiding questions and
never gives the answer. That is the product, not a safety afterthought — the app
exists to make students learn, not copy.

**The charge-and-refund order:**

1. Refuse if not configured (`AiHintError` → `503`).
2. Refuse past `HOURLY_LIMIT` (`PermissionError` → `429`), counted as a `COUNT`
   over `ai_hints.created_at` in the last hour.
3. **Deduct 5 points** through `PointService`, so an expensive model call cannot
   be started by someone who cannot pay for it (`ValueError` → `402`).
4. Call the model. On **any** failure, `db.rollback()` — nothing has been
   committed, so the points go back exactly where they were.
5. Insert the `ai_hints` row and commit.

A failed call must leave **no** `ai_hints` row: that table doubles as the
rate-limit ledger and as the evidence for the `ai_skeptic` badge.

## `AdminService`

`admin_service.py` · 155 lines.

Every method deliberately bypasses the ownership checks the normal services
enforce. `require_admin` on the router is what keeps that safe.

| Method | Behaviour |
|---|---|
| `stats(db)` | Six live counts. `points_in_circulation` is `SUM(users.points)` — one table, and it agrees with the ledger by construction (D15) |
| `list_users(db, page, limit, search)` | Paginated; `search` covers username and first/last name, never email |
| `set_suspended(db, user_id, admin_id, suspended)` | `LookupError` unknown · `PermissionError` on yourself or another admin |
| `delete_quest(db, question_id)` | Force-delete: refunds the bounty **unless already solved**, then removes the answers and their votes |

The already-solved carve-out matters: that bounty is with the helper, and
refunding it would mint points into a closed economy.
