# Server tests

```bash
cd server && source .venv/bin/activate
pytest                      # needs a live DATABASE_URL and network
ruff check app && black app # must also be clean before any PR
```

**70 test functions** across two files, plus `conftest.py`.

## They run against the real database

Not SQLite. The schema leans on `gen_random_uuid()`, `uuid` columns, CHECK
constraints and a self-referencing foreign key, and a fake database that
accepted all of them would not be testing the thing that breaks.

Isolation comes from a transaction instead:

```python
connection = engine.connect()
outer = connection.begin()
session = Session(bind=connection, join_transaction_mode="create_savepoint")
yield session
session.close(); outer.rollback(); connection.close()
```

`create_savepoint` lets the code under test call `db.commit()` **exactly as it
does in production** — the commit lands on a savepoint inside the outer
transaction, and the rollback discards it. That is what makes it safe to point
these at the live Supabase project.

The consequence: `pytest` needs network and a real `DATABASE_URL`. There is no
offline mode.

## Fixtures — `tests/conftest.py`

| Fixture | Gives you |
|---|---|
| `db` | The rolled-back `Session` described above |
| `make_user` | A `users` row with a balance you choose |
| `make_quest` | A quest by a given author, with a bounty |
| `auth_identity` | A row in `auth.users`, for testing profile creation itself |
| `make_challenge` | A `daily_challenges` row on a date you choose |

`AUTH_INSTANCE` is the zero UUID Supabase uses for `instance_id`.

## `tests/test_economy.py` — 28 tests

> The invariant these all defend: **`users.points` always equals the sum of that
> user's ledger rows, and points are only ever moved, never minted or burned.**

Every test asserts the balance *and* the ledger, because a bug that updates one
without the other is exactly the failure the ledger exists to prevent.

| Group | Covers |
|---|---|
| `PointService` | Balance and ledger move together · cannot spend below zero · every `PointReason` survives the CHECK constraint |
| Quest loop | Posting charges the author · overspending is refused · accepting transfers the bounty · **the economy is closed** · deleting an unanswered quest refunds · a quest with answers cannot be self-deleted |
| Votes | Delta arithmetic · a downvote still lands on a broke author · flipping a vote on a broke author cannot mint points · a zero movement writes nothing · self-votes and self-answers refused · only the author accepts, and only once |
| Moderation | Suspension blocks writing but not reading · admins cannot suspend themselves or each other · suspending is reversible · force-delete refunds an unsolved quest but **not** a paid-out one · force-delete removes answers and their votes · admin stats count real rows · force-delete leaves the ledger balanced |
| The admin gate | `require_admin` refuses an ordinary user, and a token with no profile · user search matches name and username · paging totals ignore the page window |

## `tests/test_challenges.py` — 42 tests

| Group | Covers |
|---|---|
| Decay | Matches the published table · stops at the floor · a future-dated challenge is full price · never reaches zero for a real bounty |
| Claiming | Today pays full · an old challenge pays the decayed award · the stored award matches the ledger row · claiming twice is refused · an unverified handle cannot claim · an unaccepted solve pays nothing |
| Submissions | Code needs no Codeforces verdict · needs no verified handle · submitting twice replaces it · survives a later claim · still allowed after solving · a missing challenge is a `LookupError` · a claim stores the code · a premature claim keeps the code · code with no language is labelled `text` · leading indentation survives the round trip · an unknown language is refused |
| Answers | An answer may be code with almost no prose · neither prose nor code is refused · a one-word quest is allowed |
| Statements | Fetched once then cached · a blocked statement is **not** an error · a challenge with no `codeforces_id` has no statement · the HTML is stripped of anything executable · sample lines survive both Codeforces layouts |
| Archive | Excludes today by default · reports the viewer's own attempt |
| The signup-bonus gap | A new profile ledgers its signup bonus |
| Recency | An old accepted submission does not pay · the refusal names the problem when nothing was submitted · the bound is the challenge's own Dhaka midnight · paging stops once past the bound · the earliest qualifying submission is credited |
| The Dhaka clock | The day rolls over at midnight Dhaka, not UTC · `start_of_day` is Dhaka midnight |

Codeforces calls are `monkeypatch`ed, so the suite never depends on a third
party being up — except the database, which is the point.

## What is not covered here

- **HTTP-level behaviour.** These call services directly. The endpoint guards
  were verified separately against the deployed API with real tokens; see the
  verification note at the top of [../../TASKS.md](../../TASKS.md).
- **The AI provider.** `AiService` is exercised through its charge/refund path
  only; a real hint was confirmed by hand against a free-tier provider.
- **The client.** See [../frontend/testing.md](../frontend/testing.md).
