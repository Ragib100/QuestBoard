# Indexes, search, triggers and RLS

Everything in `server/schema.sql` that is not a table definition.

## Indexes

Eight ordinary indexes, chosen from the queries that actually run:

| Index | On | Serves |
|---|---|---|
| `questions_author_idx` | `questions (author_id)` | A user's own quests |
| `questions_created_at_idx` | `questions (created_at desc)` | `sort=latest`, the default feed order |
| `answers_question_idx` | `answers (question_id)` | Loading a quest's answers, and the answer-count subquery |
| `votes_target_idx` | `votes (target_type, target_id)` | The vote-count subquery on every feed row |
| `point_tx_user_idx` | `point_transactions (user_id, created_at desc)` | The profile ledger, and the weekly leaderboard window |
| `idx_hints_user_question` | `ai_hints (user_id, question_id, created_at desc)` | The hourly rate-limit `COUNT`, and the `ai_skeptic` check |
| `idx_challenges_date` | `daily_challenges (challenge_date desc)` | "Today's challenge", and the archive |
| `idx_attempts_user` | `challenge_attempts (user_id, is_solved)` | `solved_by`, which the `challenger` badge counts |

Primary keys and unique constraints carry their own indexes and are not repeated
here — notably `votes (user_id, target_type, target_id)`,
`challenge_attempts (challenge_id, user_id)`, `daily_challenges (challenge_date)`
and `user_badges (user_id, badge_id)`, each of which is doing real work
(idempotent awards, a safe vote toggle, a lazily-created daily row).

## Search

`GET /api/questions?search=` matches with `ILIKE '%term%'`, which **no B-tree can
serve**. A GIN trigram index can:

```sql
create extension if not exists pg_trgm;
create index idx_questions_trgm_title on questions using gin (title gin_trgm_ops);
create index idx_questions_trgm_body  on questions using gin (body  gin_trgm_ops);
```

So search stays an index scan as the board grows, instead of degrading into a
sequential scan of every quest — and no query rewrite was needed.

Ranking is a plain **title-hit-first** ordering
(`case when title ilike :term then 0 else 1 end`) rather than `similarity()`.
That keeps the query working on a database where someone forgot to run the
extension line: it would be slower, but it would still return the right rows.

An explicit `sort=bounty` or `sort=votes` overrides the search ranking — the user
asking for a specific order wins over our idea of relevance.

The same two indexes are what would make the Tier 3 duplicate-check nearly free
once it is built ([../product.md](../product.md#scope)).

## CHECK constraints

| Table | Constraint |
|---|---|
| `votes` | `value in (1, -1)` |
| `votes` | `target_type in ('question', 'answer')` |
| `point_transactions` | `reason` in the nine `PointReason` values |
| `notifications` | `type` in the five `NotificationType` values |
| `daily_challenges` | `difficulty in ('easy', 'medium', 'hard')` |

The `reason` constraint is the one that has bitten: it drifted out of sync with
`PointReason` and silently broke two features. `schema.sql` **drops and
recreates** it on every run rather than adding it only when absent, so re-running
the file repairs an out-of-date constraint instead of skipping it
([../decisions.md](../decisions.md) D24).

## The `updated_at` trigger

```sql
create or replace function public.set_updated_at() returns trigger ...
create trigger users_set_updated_at before update on public.users
    for each row execute function public.set_updated_at();
```

The ORM sets `updated_at` on its own writes. This keeps it honest for rows edited
directly in the Supabase table editor — which happens, during setup and while
debugging.

Only `users` carries the trigger today; `questions` and `answers` rely on the
ORM's `onupdate=func.now()`.

## Row Level Security

RLS is enabled on `users`, `questions`, `answers`, `votes` and
`point_transactions`, with policies that are **read-public, write-own**:

| Policy | Table | Rule |
|---|---|---|
| Profiles are readable by everyone | `users` | `select using (true)` |
| Users can update their own profile | `users` | `auth.uid() = id` |
| Quests are readable by everyone | `questions` | `select using (true)` |
| Authors can write their own quests | `questions` | `auth.uid() = author_id` |

**These policies are not what protects the API.** The FastAPI server connects as
the `postgres` role and bypasses RLS entirely; authorization is enforced in the
service layer, where every mutation checks ownership against
`get_current_user_id` ([../decisions.md](../decisions.md) D10).

RLS matters for what the Flutter client touches **directly**, which today is only
Storage. The policies above are defence in depth for the day someone reads a
table through `supabase-js`. If you add one, keep it read-public / write-own.
