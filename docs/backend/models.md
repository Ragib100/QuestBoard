# Models

The SQLAlchemy ORM layer, `server/app/models/`. Each class mirrors one table in
[../db/schema.md](../db/schema.md) and `server/schema.sql` — keep all three in step.

`models/__init__.py` imports every model, and **that is the import you should
use**. Relationships reference each other by class *name*, which only resolves
once every class has been imported:

```python
from app.models import Question, User, PointReason   # yes
from app.models.question import Question             # no
```

`db/base.py` holds the `DeclarativeBase`; `db/database.py` holds the engine,
`SessionLocal` (`autoflush=False`, `autocommit=False`) and the `get_db`
dependency.

## Constants exported from the package

| Constant | Value | Defined in |
|---|---|---|
| `SIGNUP_BONUS` | `100` | `user.py` |
| `HINT_COST` | `5` | `ai_hint.py` |
| `CHALLENGE_BONUS` | `50` | `challenge.py` |
| `DECAY_PER_DAY` | `0.10` | `challenge.py` |
| `DECAY_FLOOR` | `0.20` | `challenge.py` |
| `TARGET_QUESTION` / `TARGET_ANSWER` | `"question"` / `"answer"` | `vote.py` |

Plus four string-constant classes — `PointReason`, `NotificationType`,
`BadgeCode`, `Difficulty` — and one pure function, `award_for`.

---

## `user.py` — `User`

Table `users`. Shares its primary key with Supabase's `auth.users`; **email
lives only there and is never copied.**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | uuid | no | — | PK, = `auth.users.id` |
| `username` | string | no | — | unique. Seeded with the signup email — **never render it directly** |
| `first_name` | string | no | `''` | |
| `last_name` | string | no | `''` | |
| `phone_number` | string | yes | — | |
| `image_url` | string | no | `''` | Path inside the `profile_image` bucket, not a URL |
| `codeforces_handle` | string | no | `''` | |
| `codeforces_verified` | bool | no | `false` | Cleared whenever the handle changes |
| `points` | int | no | `100` | **A cache of the ledger sum** |
| `streak_days` | int | no | `0` | |
| `last_active` | timestamptz | yes | — | Compared in Dhaka days |
| `created_at` / `updated_at` | timestamptz | no | `now()` | `updated_at` also has a DB trigger |
| `is_admin` | bool | no | `false` | Read from the DB on every admin call |
| `is_suspended` | bool | no | `false` | Set by an admin |

Relationships: `questions`, `answers` (both `back_populates="author"`).

The column default of `100` is mirrored so a row inserted directly in SQL still
gets it, but the API hands the bonus out through `PointService` so the ledger has
a `signup_bonus` row explaining the balance.

A suspended account can still **read** — banning someone from a Q&A board they
may be cited in helps nobody — but cannot post, answer or vote. That is enforced
in `UserService.require_active`, not in the JWT dependency, because the token
knows nothing about this column ([../decisions.md](../decisions.md) D22).

## `question.py` — `Question`, `Tag`, `question_tags`

Table `questions`. A quest: a question carrying a point bounty. The table is
named `questions` and every foreign key that points at it says `question`
([../decisions.md](../decisions.md) D1) — do not rename one without the other.

| Column | Type | Null | Default |
|---|---|---|---|
| `id` | uuid | no | `gen_random_uuid()` |
| `author_id` | uuid → `users.id` ON DELETE CASCADE | no | — |
| `title` | text | no | — |
| `body` | text | no | — |
| `image_url` | text | yes | — |
| `bounty_points` | int | no | `0` |
| `is_solved` | bool | no | `false` |
| `accepted_answer_id` | uuid → `answers.id` ON DELETE SET NULL | yes | — |
| `view_count` | int | no | `0` |
| `difficulty` | varchar(10) | yes | — |
| `created_at` / `updated_at` | timestamptz | no | `now()` |

Relationships: `author`; `tags` (many-to-many via `question_tags`,
`lazy="selectin"`); `answers` (`cascade="all, delete-orphan"`).

`Tag` is just `id` + unique `name` (varchar 50). `question_tags` is a plain
association `Table` with a composite primary key.

`questions.accepted_answer_id` and `answers.question_id` reference each other, so
`schema.sql` adds that foreign key after both tables exist.

## `answer.py` — `Answer`

| Column | Type | Null | Notes |
|---|---|---|---|
| `id` | uuid | no | PK |
| `question_id` | uuid → `questions.id` CASCADE | no | |
| `author_id` | uuid → `users.id` CASCADE | no | |
| `body` | text | no | May be empty **only** when `code_body` is set |
| `image_url` | text | yes | |
| `code_body` | text | yes | The source itself — small enough for Postgres |
| `code_language` | varchar(20) | yes | One of `schemas/code.py::LANGUAGES` |
| `attachment_url` | text | yes | Public URL in the `submissions` bucket |
| `attachment_name` | text | yes | Original filename, so the UI can label the link |
| `is_accepted` | bool | no | |
| `created_at` / `updated_at` | timestamptz | no | |

The server never sees attachment bytes: the client uploads straight to Storage
and sends the URL. `code_body` *is* stored in Postgres — it belongs to the
answer, and putting it in a bucket would mean a second fetch to render an answer
([../decisions.md](../decisions.md) D27).

## `vote.py` — `Vote`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid → `users.id` CASCADE | |
| `target_type` | varchar(10) | `"question"` or `"answer"` |
| `target_id` | uuid | **Polymorphic — no foreign key by design** |
| `value` | smallint | `CHECK (value in (1, -1))` |
| `created_at` | timestamptz | |

`UniqueConstraint("user_id", "target_type", "target_id")` is what makes the
toggle safe: re-voting the same value deletes the row, the opposite flips it, and
a race can only ever collide on the constraint.

Because there is no FK, deleting a quest must delete its votes explicitly —
`QuestionService.delete` and `AdminService.delete_quest` both do.

## `point_transaction.py` — `PointTransaction`, `PointReason`

**Append-only.** Never `UPDATE` or `DELETE` a row: `users.points` is a cache of
this table's sum and the two only ever move together.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid → `users.id` CASCADE | |
| `amount` | int | Signed. Negative is a deduction |
| `reason` | varchar(50) | Must be a `PointReason` — a DB CHECK enforces it |
| `reference_id` | uuid | The quest, answer, challenge or user it refers to |
| `created_at` | timestamp | Naive, holding UTC |

`PointReason`: `signup_bonus` · `bounty_posted` · `bounty_refunded` ·
`bounty_awarded` · `vote_received` · `vote_lost` · `daily_bonus` ·
`challenge_solved` · `ai_hint`.

Adding a member here without updating the CHECK constraint in `schema.sql` fails
at insert time. That has already happened once
([../decisions.md](../decisions.md) D24).

## `notification.py` — `Notification`, `NotificationType`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid → `users.id` CASCADE | |
| `type` | varchar(30) | CHECK-constrained |
| `message` | text | Rendered as written |
| `reference_id` | uuid | Polymorphic — the type says which table |
| `is_read` | bool | |
| `created_at` | timestamptz | |

`NotificationType`: `answer_received` · `answer_accepted` · `bounty_awarded` ·
`vote_received` · `badge_earned`. `vote_received` is in the enum and the
constraint but is never produced (D19).

## `badge.py` — `Badge`, `UserBadge`, `BadgeCode`

`Badge`: `id`, unique `name` (varchar 50), `description` (text, not null),
`icon_url`.

`description` is the badge's **condition**, and it is the only copy of it: the
profile prints it under every badge, earned or not, so someone can see what a
locked one takes ([../decisions.md](../decisions.md) D50).

`UserBadge`: composite primary key `(user_id, badge_id)` — that is what makes
awarding idempotent — plus `awarded_at`. `badge` is `lazy="joined"`.

`BadgeCode` names all eight; all are awardable except `TOP_HELPER`, which needs
a weekly-rank check on a schedule.

## `challenge.py` — `DailyChallenge`, `ChallengeAttempt`, `Difficulty`, `award_for`

### `award_for(bonus_points, challenge_date, on=None) -> int`

Pure and deterministic. What solving a challenge of that date is worth on Dhaka
day `on`:

```
floor   = max(1, round(bonus * 0.20))
decayed = bonus - round(bonus * 0.10 * age_days)
award   = max(floor, decayed)
```

For the standard 50-point challenge:

| Age | 0d | 1d | 3d | 5d | 7d | 8d+ |
|---|---|---|---|---|---|---|
| Award | 50 | 45 | 35 | 25 | 15 | 10 |

The decayed value is **never stored** on the challenge, because a stored copy
would be wrong by the next morning. What *is* stored is
`challenge_attempts.awarded_points` — what a specific solve actually paid.

### `DailyChallenge`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `codeforces_id` | text | `"1873/D"` — contest id + problem index |
| `title` | text | not null |
| `body` | text | not null — a generated summary, the last-resort fallback |
| `cf_rating` | int | |
| `difficulty` | varchar(10) | `easy` / `medium` / `hard`, CHECK-constrained |
| `source_url` | text | |
| `bonus_points` | int | default `50` |
| `challenge_date` | date | **unique** — this is what makes "today's challenge" a lookup rather than a decision |
| `statement` | jsonb | `{html, time_limit, memory_limit, samples[]}`, cached forever |
| `statement_fetched_at` | timestamptz | |
| `created_at` | timestamptz | |

`submit_url` is **not** a column — it is derived from `codeforces_id` at
serialisation time, like `award_points` and `age_days`.

### `ChallengeAttempt`

Unique on `(challenge_id, user_id)`, so claiming twice conflicts instead of
paying twice.

| Column | Type | Notes |
|---|---|---|
| `is_solved` | bool | |
| `awarded_points` | int | What this solve actually paid — the only record of the decay |
| `code_body` / `code_language` | text / varchar(20) | The solution written in the app |
| `attachment_url` / `attachment_name` | text | An uploaded file |
| `solved_at` | timestamp | |
| `created_at` | timestamp | |

A row with `is_solved = false` is a real, useful row: a failed claim still keeps
the code.

## `ai_hint.py` — `AiHint`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `question_id` | uuid → `questions.id` CASCADE | |
| `user_id` | uuid → `users.id` CASCADE | |
| `hint_text` | text | |
| `points_cost` | int | default `HINT_COST` = 5 |
| `created_at` | timestamp | |

**One row per hint the model actually returned.** It doubles as the rate-limit
ledger (the hourly cap is a `COUNT` over `created_at`) and as the evidence for
`ai_skeptic`, so a failed model call must leave no row behind.
