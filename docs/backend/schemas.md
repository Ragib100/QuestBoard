# Schemas

Pydantic request and response shapes, `server/app/schemas/`. One per direction:
`QuestionCreate` in, `QuestionResponse` out. Response schemas that are built from
ORM rows carry `model_config = ConfigDict(from_attributes=True)`.

A validation failure here is FastAPI's `422`, with Pydantic's own error body.
Every other error is a hand-raised `HTTPException` with a `detail` string
([../decisions.md](../decisions.md) D4).

## Limits, in one place

| Constant | Value | Defined in | Applies to |
|---|---|---|---|
| `MAX_TITLE_CHARS` | `300` | `question.py` | Quest title |
| `MAX_BODY_CHARS` | `50_000` | `question.py`, `answer.py` | Quest body, answer body |
| `MAX_BOUNTY` | `100` | `question.py` | `bounty_points` (0–100) |
| `MAX_CODE_CHARS` | `20_000` | `code.py` | `code_body` |
| `LANGUAGES` | 17 values | `code.py` | `code_language` |

There is **no minimum length** on a quest or an answer
([../decisions.md](../decisions.md) D30): a short question is still a question,
and the old 10/20-character floors mostly taught people to pad. Empty is still
rejected — that is a mistake, not a style. The ceilings exist to bound the row,
not the writer, so the client never mentions them.

---

## `user.py`

| Schema | Direction | Fields |
|---|---|---|
| `UserCreate` | in | `username` (3–30), `first_name` (≤100), `last_name` (≤100), `phone_number?` (≤20), `image_url`, `codeforces_handle` |
| `UserUpdate` | in | All optional: `username?` (≤30), names, `phone_number?`, `image_url?`, `codeforces_handle?`, `codeforces_verified?` |
| `UserSummary` | out | `id`, `username`, `first_name`, `last_name`, `image_url`, `points` — the author block embedded in quests and answers |
| `UserResponse` | out | The full profile, plus `codeforces_verified`, `streak_days`, `last_active`, `is_admin`, `is_suspended` |
| `PointTransactionResponse` | out | `amount`, `reason`, `reference_id`, `created_at` |
| `PointsResponse` | out | `{balance, transactions[]}` |

No response schema ever carries an email or another user's phone number.

## `question.py`

| Schema | Direction | Notes |
|---|---|---|
| `QuestionCreate` | in | `title`, `body`, `tags[]` (≤5), `bounty_points` (0–100), `image_url?`. Blank or whitespace-only title/body → `422` via `_required` |
| `QuestionUpdate` | in | All optional. **`bounty` is deliberately absent** — it is spent at post time and cannot be edited without unwinding the ledger. Omitting a field leaves it alone; sending it blank is an attempt to erase it and is refused |
| `AnswerResponse` | out | Answer + `author`, `vote_count`, `my_vote`, and the four code fields |
| `QuestionSummary` | out | Feed row — no body, no answers |
| `QuestionDetail` | out | Extends `QuestionSummary` with `body`, `image_url`, `accepted_answer_id`, `my_vote`, `answers[]` |
| `QuestionPage` | out | `{items, page, limit, total, has_more}` — the standard page shape |

## `answer.py`

`AnswerCreate` and `AnswerUpdate` are both `_AnswerWrite`, which extends
`CodeSubmission` with `body` (default `""`, ≤50,000) and `image_url?`.

The `_body_or_code` model validator is the rule: an answer has to say something,
but "something" is not a character count — *"yes, use a set"* is a complete
answer. Non-empty prose passes; **code alone also passes**, because the code
*is* the answer. Demanding prose on top of a working solution is a rule that
only ever produced "here you go". Neither → `ValueError`.

## `code.py` — shared by answers and challenge attempts

`CodeSubmission` is a mixin with four optional, nullable fields: `code_body`,
`code_language`, `attachment_url`, `attachment_name`. Both writers carry the same
four columns, so they share one mixin rather than two copies that drift.

| Validator | Rule |
|---|---|
| `_check_code` | ≤ `MAX_CODE_CHARS`. **Only trailing whitespace is stripped** — leading indentation is meaningful in Python, and stripping it would silently break the submitted code |
| `_check_language` | Lowercased, must be in `LANGUAGES`, else `ValueError` |
| `_trim` | Trims the URL and filename |
| `has_code` | Property: is there non-blank code |

`LANGUAGES` = `text`, `c`, `cpp`, `csharp`, `java`, `python`, `javascript`,
`typescript`, `dart`, `go`, `rust`, `kotlin`, `swift`, `php`, `ruby`, `sql`,
`bash`. Bounded because the column is `varchar(20)` and because a free-text
language is a label nothing can render consistently. `text` is the honest
fallback.

`apply_submission(row, data)` copies the fields onto an ORM row:

- A field **left out** of the request is left alone.
- An **empty string** clears the column to `NULL` — that is what "remove my
  attachment" has to mean.
- Code with no language becomes `"text"`: unlabelled rather than unknown, since
  the reader still needs something to put on the block.

## `vote.py`

`VoteRequest` — `value: Literal[-1, 1]`. `VoteResponse` — `{vote_count, my_vote}`.

## `gamification.py`

| Schema | Notes |
|---|---|
| `BadgeResponse` | `id`, `name`, `description`, `icon_url?` |
| `EarnedBadge` | `BadgeResponse` + `awarded_at` |
| `LeaderboardEntry` | `rank`, `score`, `user` |
| `LeaderboardResponse` | `period`, `entries[]`, `me?` — `me.rank` is `null` when the caller has earned nothing in the period |
| `StreakResponse` | `streak_days`, `last_active?` |
| `NotificationResponse` | `id`, `type`, `message`, `reference_id?`, `is_read`, `created_at` |
| `NotificationPage` | `{items, unread_count}` |

## `challenge.py`

| Schema | Notes |
|---|---|
| `ChallengeResponse` | The challenge row, plus three fields computed per request and never stored: `submit_url`, `award_points`, `age_days` |
| `AttemptResponse` | `is_solved`, `solved_at?`, `awarded_points`, and the four code fields |
| `ChallengeView` | `{challenge, is_today, solver_count, my_attempt?, codeforces_verified}` — today's challenge and an archived one use the same shape, which is what lets one screen render both |
| `TodayResponse` | An alias for `ChallengeView`, kept so `/challenges/today` did not change shape when archived challenges started sharing it |
| `ChallengePage` | `{items, page, limit, total, has_more}` |
| `SolveRequest` | `CodeSubmission` with nothing added — every field optional, because the bonus is paid on the Codeforces verdict and a claim with no code is still a valid claim |
| `StatementSample` | `{input, output}` |
| `ProblemStatement` | `{available, html, time_limit, memory_limit, samples[], source_url?, submit_url?}` |
| `ChallengeSolver` | `rank`, `solved_at?`, `awarded_points`, `user` |
| `VerificationChallenge` | `handle`, `codeforces_id`, `problem_url`, `submit_url`, `window_minutes` |

`ProblemStatement.available: false` is returned with a **200**, not a 502.
Codeforces refusing us is a routine outcome rather than an error, and the client
has two fallbacks for it.

## `ai.py`

| Schema | Fields |
|---|---|
| `HintRequest` | `question_id` |
| `HintResponse` | `hint_text`, `points_cost`, `points_remaining`, `hints_remaining` |
| `HintStatus` | `available`, `points_cost`, `hints_remaining` |

`HintStatus` exists so the button can say what it will cost **before** anyone
spends anything, and so it can be hidden entirely when no provider is configured
(ground rule 4 — no fake success).

## `admin.py`

| Schema | Fields |
|---|---|
| `AdminStats` | `total_users`, `suspended_users`, `total_quests`, `open_quests`, `total_answers`, `points_in_circulation` — every one a live `COUNT`/`SUM` |
| `AdminUser` | `id`, `username`, names, `image_url`, `points`, `is_admin`, `is_suspended`, `created_at` |
| `AdminUserPage` | The standard page shape |
| `SuspendRequest` | `{suspended: bool}` — explicit rather than a toggle, so two admins acting at once cannot flip each other's decision back |

## `utils/serialize.py`

Not a schema module, but where schemas get built. Vote and answer counts are
aggregates, not columns, so the services return them alongside the model and
these helpers do the stitching in one place:

| Function | Produces |
|---|---|
| `answer_payload(row)` | `AnswerResponse` |
| `question_summary(row)` | `QuestionSummary` |
| `question_detail(row)` | `QuestionDetail` |
| `challenge_view(challenge, *, today, attempt, solver_count, codeforces_verified)` | `ChallengeView`, computing `award_points`, `age_days` and `submit_url` |

`challenge_view` computes rather than reads those three because each is an answer
to "as of when", and the only honest answer is "as of this request".
