# Data model

Postgres on Supabase. Everything below is **live** — this file was regenerated from
the running database, not written ahead of it. Verify with the Supabase table editor
before trusting a detail; if the two disagree, the database wins and this file is the
bug.

Two conventions to internalise:

- `auth.users` is Supabase's own table. Never write to it. Our `public.users` row
  shares its primary key. **Email lives only in `auth.users`** — never copy it.
- The table is `questions`; the product calls it a **quest**
  ([decisions.md](decisions.md) D1). Every foreign key, route and JSON key says
  `question`. Do not rename one without the other.

---

## `users`

Mirrors `server/app/models/user.py`. Created by `POST /api/users` after email
verification, not by a database trigger — so a verified account with no row here is
a user who never finished onboarding. `GET /api/users/me` returns 404 in that state,
which is how the client knows to show ProfileCreate.

```sql
users (
    id                  uuid primary key references auth.users(id) on delete cascade,
    username            text        not null unique,
    first_name          text        not null default '',
    last_name           text        not null default '',
    phone_number        text,
    image_url           text        not null default '',   -- storage path, not a URL
    codeforces_handle   text        not null default '',
    codeforces_verified boolean     not null default false,
    points              integer     not null default 100,
    streak_days         integer     not null default 0,
    is_admin            boolean     not null default false,
    last_active         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
)
```

`image_url` holds the path inside the `profile_image` bucket (`<uid>/<epoch>.png`);
the client turns it into a URL with `getPublicUrl`. `points` is a **cache** of the
`point_transactions` sum — see the ledger rule below.

## `questions`

Mirrors `server/app/models/question.py`.

```sql
questions (
    id                 uuid primary key default gen_random_uuid(),
    author_id          uuid    not null references users(id) on delete cascade,
    title              text    not null,
    body               text    not null,
    image_url          text,
    bounty_points      integer not null default 0,
    is_solved          boolean not null default false,
    accepted_answer_id uuid    references answers(id),
    view_count         integer not null default 0,
    difficulty         varchar(10),                        -- unused until M4
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
)
```

`accepted_answer_id` and `answers.question_id` reference each other, so the two tables
must be created in one migration.

## `answers`

```sql
answers (
    id          uuid primary key default gen_random_uuid(),
    question_id uuid    not null references questions(id) on delete cascade,
    author_id   uuid    not null references users(id) on delete cascade,
    body        text    not null,
    image_url   text,
    is_accepted boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
)
```

There is no `vote_count` column — scores are summed from `votes` on read.

## `votes`

One row per user per target. The unique constraint is what makes toggling safe: a
double tap can only ever collide on it.

```sql
votes (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid     not null references users(id) on delete cascade,
    target_type varchar(10) not null check (target_type in ('question','answer')),
    target_id   uuid     not null,
    value       smallint not null check (value in (1, -1)),
    created_at  timestamptz not null default now(),
    unique (user_id, target_type, target_id)
)
```

`target_id` is polymorphic and deliberately has no foreign key — deleting a question
or answer must therefore delete its votes explicitly, which the services do.

## `point_transactions`

The economy ledger, and the reason the numbers can be trusted.

**Append-only. Never `UPDATE` or `DELETE` a row.** `users.points` is a cache of
`sum(amount)`, and the two are written together inside one transaction by
`PointService` — the only code allowed to touch either
([decisions.md](decisions.md) D15).

```sql
point_transactions (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid    not null references users(id) on delete cascade,
    amount       integer not null,          -- negative for deductions
    reason       varchar(50) not null,
    reference_id uuid,                      -- the question/answer/challenge involved
    created_at   timestamptz not null default now()
)
```

Valid `reason` values live in `PointReason` (`app/models/point_transaction.py`) and
are documented in [product.md](product.md#point-economy).

## `tags` / `question_tags`

A fixed catalogue, seeded with 14 subject tags. Unknown tag names are **rejected**
rather than created, so the feed filter cannot fill with typos.

```sql
tags (
    id   uuid primary key default gen_random_uuid(),
    name varchar(50) not null unique
)
question_tags (
    question_id uuid not null references questions(id) on delete cascade,
    tag_id      uuid not null references tags(id) on delete cascade
)
```

Seeded: `dsa`, `math`, `physics`, `chemistry`, `calculus`, `linear-algebra`,
`graph-theory`, `dynamic-programming`, `number-theory`, `geometry`,
`data-structures`, `algorithms`, `probability`, `statistics`.

---

## Tables that exist but are not used yet

These were created up front and are **empty**. No ORM model, no endpoint — treat the
shapes as a starting point, not a contract, and confirm the columns before building
against them.

| Table | Milestone | Notes |
|---|---|---|
| `notifications` | M3 | `user_id`, `type` varchar(30), `message`, `reference_id`, `is_read` |
| `badges` | M3 | 8 seeded: `first_answer`, `first_bounty`, `streak_5`, `streak_30`, `bounty_hunter`, `top_helper`, `challenger`, `ai_skeptic`. Keyed by `id` + `name`, **not** by a `code` column |
| `user_badges` | M3 | `user_id`, `badge_id`, `awarded_at` |
| `ai_hints` | M4 | `question_id`, `user_id`, `hint_text`, `points_cost` (default 5) |
| `daily_challenges` | M4 | `codeforces_id`, `title`, `body`, `cf_rating`, `difficulty`, `source_url`, `bonus_points` (default 50), `challenge_date` |
| `challenge_attempts` | M4 | `challenge_id`, `user_id`, `is_solved`, `solved_at` |

## Search — not enabled yet

Run before building search or duplicate detection (M5):

```sql
create extension if not exists pg_trgm;
create index questions_title_trgm on questions using gin (title gin_trgm_ops);
create index questions_body_trgm  on questions using gin (body gin_trgm_ops);
```

Until then `GET /api/questions?search=` uses `ILIKE`, which is correct but does not
scale past a few thousand rows.

## Row Level Security

The API connects as a privileged role and **bypasses RLS**, so authorization is
enforced in the service layer — every mutation checks ownership against
`get_current_user_id`. RLS still matters for what the Flutter client touches directly,
which today is only Storage. If you add a policy, keep it read-public / write-own.
