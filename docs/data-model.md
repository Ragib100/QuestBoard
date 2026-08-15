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
    is_suspended        boolean     not null default false,
    last_active         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
)
```

`image_url` holds the path inside the `profile_image` bucket (`<uid>/<epoch>.png`);
the client turns it into a URL with `getPublicUrl`. `points` is a **cache** of the
`point_transactions` sum — see the ledger rule below. `is_suspended` is set by an
admin and checked by `UserService.require_active` on every write path, not in the JWT
dependency ([decisions.md](decisions.md) D22).

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
    difficulty         varchar(10),                        -- vestigial, nothing reads it
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
are documented in [product.md](product.md#point-economy). A CHECK constraint enforces
the list; `schema.sql` **drops and recreates** it rather than adding it only when
absent, because it had already drifted out of sync once and silently broke two
features ([decisions.md](decisions.md) D24).

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

## `notifications` / `badges` / `user_badges`

Mirrors `server/app/models/notification.py` and `badge.py`. `notifications.type` has a
CHECK constraint listing the five allowed values, so adding a member to
`NotificationType` without a migration fails at insert time. `badges` is keyed by
`id` + `name` — there is **no** `code` column — and is seeded with eight rows;
`user_badges` has a composite primary key, which is what makes awarding idempotent
([decisions.md](decisions.md) D18).

## `ai_hints`

One row per hint the model actually returned.

```sql
ai_hints (
    id          uuid primary key default gen_random_uuid(),
    question_id uuid    not null references questions(id) on delete cascade,
    user_id     uuid    not null references users(id) on delete cascade,
    hint_text   text    not null,
    points_cost integer not null default 5,
    created_at  timestamp not null default now()
)
```

The table does double duty. The 3-per-hour rate limit is a COUNT over `created_at`,
and the `ai_skeptic` badge — "solved a question without using any AI hints" — is the
absence of a row for `(user_id, question_id)`. Both only work if a **failed** model
call leaves no row behind, which is why the deduction, the call and the insert share
one transaction.

## `daily_challenges` / `challenge_attempts`

```sql
daily_challenges (
    id             uuid primary key default gen_random_uuid(),
    codeforces_id  text,                   -- "1873/D": contest id + index
    title          text    not null,
    body           text    not null,
    cf_rating      integer,
    difficulty     varchar(10) check (difficulty in ('easy','medium','hard')),
    source_url     text,
    bonus_points   integer not null default 50,
    challenge_date date    not null unique,
    created_at     timestamptz not null default now()
)
challenge_attempts (
    id           uuid primary key default gen_random_uuid(),
    challenge_id uuid    not null references daily_challenges(id) on delete cascade,
    user_id      uuid    not null references users(id) on delete cascade,
    is_solved    boolean not null default false,
    solved_at    timestamp,
    created_at   timestamp not null default now(),
    unique (challenge_id, user_id)
)
```

There is no cron job: the unique `challenge_date` is what lets the first request of
the day create the row and everyone after read it, with a losing INSERT resolving to
a plain conflict. `body` is **not** the problem statement — Codeforces does not expose
statements through its API, so it holds the rating and topics and points at
`source_url`.

The unique `(challenge_id, user_id)` is what stops a bonus being paid twice. An
unsolved row is meaningful: it records that someone tried and Codeforces had no
accepted submission yet.

Every table in the database now has an ORM model and at least one endpoint. The one
remaining vestige is `questions.difficulty`, which nothing reads or writes —
difficulty lives on the daily challenge, not on quests.

## Search

Live. `pg_trgm` is enabled and both indexes exist:

```sql
create extension if not exists pg_trgm;
create index idx_questions_trgm_title on questions using gin (title gin_trgm_ops);
create index idx_questions_trgm_body  on questions using gin (body gin_trgm_ops);
```

`GET /api/questions?search=` still matches with `ILIKE '%term%'` — the trigram indexes
are what make that an index scan instead of a sequential one, so no query rewrite was
needed. Ranking is a plain title-hit-first ordering rather than `similarity()`, which
keeps the query working on a database where someone forgot to run the extension line.

## Row Level Security

The API connects as a privileged role and **bypasses RLS**, so authorization is
enforced in the service layer — every mutation checks ownership against
`get_current_user_id`. RLS still matters for what the Flutter client touches directly,
which today is only Storage. If you add a policy, keep it read-public / write-own.
