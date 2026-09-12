# The point economy

QuestBoard runs a **closed** point economy: asking costs points, helping earns
them. This page is the mechanical contract — the ledger, the invariants, and
every code path that moves a point. For the product rules behind the numbers
(what each event is worth, and why), see
[../product.md](../product.md#point-economy).

## The one rule

> **`users.points` always equals the sum of that user's `point_transactions`
> rows, and points are only ever moved, never minted or burned.**

`users.points` is a **cache** of the ledger. `point_transactions` is
**append-only** — never `UPDATE`, never `DELETE` a row.

`PointService.apply` is the only code allowed to touch either, and it writes both
in the same unit of work ([../decisions.md](../decisions.md) D15). Nothing else
in the server assigns to `user.points`.

```python
PointService.apply(db, user, amount, reason, reference_id=None, allow_negative=False)
```

## Reasons

Exactly nine, defined in `PointReason` (`server/app/models/point_transaction.py`)
and enforced by a CHECK constraint on the column.

| `reason` | Δ | Written by |
|---|---|---|
| `signup_bonus` | +100 | `UserService.create_user` |
| `bounty_posted` | −bounty | `QuestionService.create` |
| `bounty_refunded` | +bounty | `QuestionService.delete`, `AdminService.delete_quest` |
| `bounty_awarded` | +bounty | `AnswerService.accept` |
| `vote_received` | +1 | `VoteService.cast` |
| `vote_lost` | −1 | `VoteService.cast` |
| `daily_bonus` | +10 | `ActivityService.record` |
| `challenge_solved` | +award | `ChallengeService.claim` |
| `ai_hint` | −5 | `AiService.hint` |

Adding a member to `PointReason` without updating the CHECK constraint in
`schema.sql` fails at insert time. **That has already happened**: the constraint
still said `hint_used` and had never heard of `bounty_refunded`, so deleting a
quest with a bounty and buying an AI hint both died on an insert
([../decisions.md](../decisions.md) D24). `schema.sql` now drops and recreates
the constraint on every run, so re-running the file repairs it.

## The four sources of new points

Everything else is a transfer. Only these create points:

1. `signup_bonus` — once per account.
2. `daily_bonus` — once per Dhaka day, on first *participation* (posting,
   answering, accepting, voting; reading never counts).
3. `challenge_solved` — the decayed award, paid on a verified Codeforces verdict.
4. …and nothing else.

Bounties, votes, refunds and hints all net to **zero** across the ledger:

- A bounty is debited at post time and credited at accept time — the same number,
  moved.
- A vote debits nobody; it moves ±1 to the content's author. (An upvote *adds* to
  the author without a matching debit, which is the one deliberate exception, and
  a downvote removes it again — the pair is symmetric.)
- A refund returns exactly what was locked.
- A hint deducts 5 and, on failure, the whole transaction is rolled back.

As of the D28 audit the live database reports **0** accounts whose balance the
ledger cannot explain.

## Invariants, and how each is kept

### A balance may not go below zero on the holder's own action

`PointService.apply` raises `ValueError` when a deduction would take the balance
negative, and the router turns that into `402`. This is what makes posting an
unaffordable bounty, or buying a hint with 3 points, fail cleanly and early.

### …except when someone else's action moves it

`allow_negative=True` exists for exactly one caller: a **downvote** debiting an
author who has already spent everything.

That movement is not the author's own action to be refused. Refusing it would
fail *the voter's* request over someone else's balance, and clamping it at zero
would let a downvote-then-upvote flip mint the difference. A balance that dips
below zero is the honest record of what happened; a wrong one is neither rare nor
honest.

### A zero movement writes nothing

`apply` returns `None` for `amount == 0`. `users.points` does not change, and a
`0` row is noise in a history whose job is to explain a balance.

### Every point a user holds has a row

`users.points` defaults to `100` and the API used to let it, so each account
started with 100 points no transaction explained — a profile showing a balance
with an empty history behind it.

`UserService.create_user` now inserts with `points=0` and pays the bonus through
`PointService`. `schema.sql` carries an idempotent backfill that ledgers the
*actual* gap between cached balance and ledger sum (not a hardcoded 100) for
accounts that predate the fix.

### Multi-step movements are one transaction

The bounty transfer debits one user and credits another. The hint deducts, then
calls a model that may fail. Both must be atomic, so:

- `PointService.apply` **flushes but never commits** — the caller owns the
  transaction ([../decisions.md](../decisions.md) D20).
- The flush is not optional: the session runs `autoflush=False`, so a badge check
  counting `bounty_awarded` rows later in the same transaction would not see the
  row just written.

A half-applied economy is unrecoverable, which is why this is the one place the
codebase is explicit about transaction boundaries.

## Every path that moves points

| Path | Movement |
|---|---|
| `POST /users` | `+100 signup_bonus` |
| `POST /questions` | `daily_bonus` **first** (a user whose streak payment would cover the cost should not be refused), then `−bounty bounty_posted`. `402` if short |
| `DELETE /questions/{id}` | `+bounty bounty_refunded`, only while unanswered |
| `POST /answers/{id}/accept` | `+bounty bounty_awarded` to the helper. The asker was debited at post time, so nothing moves on their side |
| `POST /{questions,answers}/{id}/vote` | `±1` to the author, **by the delta** between old and new vote — a flip from −1 to +1 writes one movement of 2 |
| `POST /challenges/{id}/solve` | `+award_for(bonus, date) challenge_solved`, and the amount paid is stored on the attempt |
| `POST /ai/hint` | `−5 ai_hint`, deducted **before** the model call and rolled back with it on failure |
| `DELETE /admin/quests/{id}` | `+bounty bounty_refunded` **unless already solved** — that bounty is with the helper, and refunding it would mint points |

Any action that participates also runs `ActivityService.record`, which may add
the `daily_bonus`, and `BadgeService.sync`, which may award a badge — both in the
same transaction as the action itself.

## Challenge award decay

A challenge is worth its full `bonus_points` on its own day and loses **10% of
that base per day** afterwards, with a floor at **20%** of the base.

| Age | 0d | 1d | 3d | 5d | 7d | 8d+ |
|---|---|---|---|---|---|---|
| Award (base 50) | 50 | 45 | 35 | 25 | 15 | 10 |

Computed by `award_for()` from `challenge_date` **at claim time** and never
stored on the challenge — a stored copy would be wrong by the next morning. What
*is* stored is `challenge_attempts.awarded_points`, the amount actually paid, so
the ledger and the per-challenge leaderboard agree about a solve forever after
([../decisions.md](../decisions.md) D28).

## Verifying it

`server/tests/test_economy.py` asserts the balance **and** the ledger on every
path, because a bug that updates one without the other is exactly the failure the
ledger exists to prevent. It includes an explicit
`test_the_economy_is_closed`. See [../backend/testing.md](../backend/testing.md).

A quick read against a live database:

```sql
-- Accounts whose balance the ledger cannot explain. Should return no rows.
select u.id, u.username, u.points,
       coalesce(sum(t.amount), 0) as ledger
  from public.users u
  left join public.point_transactions t on t.user_id = u.id
 group by u.id
having u.points <> coalesce(sum(t.amount), 0);
```
