# Data model

Postgres on Supabase. `auth.users` is Supabase's own table — never write to it. Our
`public.users` row shares its primary key and holds everything else. **Email lives only
in `auth.users`**; do not copy it.

Status legend: **live** = migrated and in use · **planned** = not created yet, shape is
a proposal until the migration lands.

---

## `users` — live

Mirrors `server/app/models/user.py`. Created by `POST /api/users` after email
verification, not by a DB trigger.

```sql
CREATE TABLE users (
    id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username            TEXT UNIQUE NOT NULL,
    first_name          TEXT NOT NULL DEFAULT '',
    last_name           TEXT NOT NULL DEFAULT '',
    phone_number        TEXT,
    image_url           TEXT NOT NULL DEFAULT '',  -- storage path, not a full URL
    codeforces_handle   TEXT NOT NULL DEFAULT '',
    codeforces_verified BOOLEAN NOT NULL DEFAULT false,
    points              INT NOT NULL DEFAULT 100,
    streak_days         INT NOT NULL DEFAULT 0,
    last_active         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

`image_url` holds the path inside the `profile_image` bucket (e.g.
`<uid>/1699999999.png`); the client resolves it with `getPublicUrl`. Pending migration:
`is_admin BOOLEAN NOT NULL DEFAULT false` — the admin screens need it.

## `quests` — live

Mirrors `server/app/models/quest.py`. The economy columns are **not** there yet.

```sql
CREATE TABLE quests (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    title       TEXT NOT NULL,
    description TEXT,
    tags        TEXT[],
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);
```

Pending migration to make the core loop possible:

```sql
ALTER TABLE quests
  ADD COLUMN bounty_points      INT NOT NULL DEFAULT 0 CHECK (bounty_points BETWEEN 0 AND 100),
  ADD COLUMN is_solved          BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN accepted_answer_id UUID;   -- FK added after `answers` exists
```

Tags are a `TEXT[]` column, not a join table — a fixed handful of subject tags does not
justify two extra tables. Index with `GIN (tags)` when filtering gets slow.

## `answers` — planned

```sql
CREATE TABLE answers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quest_id    UUID NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body        TEXT NOT NULL,
    is_accepted BOOLEAN NOT NULL DEFAULT false,
    vote_count  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX answers_quest_idx ON answers(quest_id);
```

## `votes` — planned

One row per user per target; the unique constraint is what makes toggling safe.

```sql
CREATE TABLE votes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('quest','answer')),
    target_id   UUID NOT NULL,
    value       SMALLINT NOT NULL CHECK (value IN (-1, 1)),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, target_type, target_id)
);
```

Polymorphic `target_id` has no FK by design. Re-voting the same value deletes the row;
the opposite value updates it.

## `point_transactions` — planned

The economy ledger. Append-only: never `UPDATE` or `DELETE` a row. `users.points` is
a running cache of `SUM(amount)` and must be updated in the same transaction as the
insert. Valid `reason` values are the table in [product.md](product.md#point-economy).

```sql
CREATE TABLE point_transactions (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount     INT NOT NULL,          -- negative for deductions
    reason     TEXT NOT NULL,
    ref_id     UUID,                  -- quest / answer / challenge it relates to
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX point_tx_user_idx ON point_transactions(user_id, created_at DESC);
```

## `notifications` — planned

```sql
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type       TEXT NOT NULL,   -- answer_received | answer_accepted | badge_earned | bounty_won
    message    TEXT NOT NULL,
    ref_id     UUID,
    is_read    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX notifications_unread_idx ON notifications(user_id) WHERE NOT is_read;
```

## `badges` / `user_badges` — planned

`badges` is a static lookup seeded once from the badge table in
[product.md](product.md#badges).

```sql
CREATE TABLE badges (
    code        TEXT PRIMARY KEY,   -- 'first_answer', 'streak_5', ...
    name        TEXT NOT NULL,
    description TEXT NOT NULL,
    icon        TEXT NOT NULL
);
CREATE TABLE user_badges (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_code TEXT NOT NULL REFERENCES badges(code),
    earned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, badge_code)
);
```

## `daily_challenges` / `challenge_attempts` — planned

```sql
CREATE TABLE daily_challenges (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codeforces_id  TEXT UNIQUE NOT NULL,   -- e.g. '1873/A'
    title          TEXT NOT NULL,
    url            TEXT NOT NULL,
    rating         INT,
    bonus_points   INT NOT NULL DEFAULT 50,
    challenge_date DATE UNIQUE NOT NULL
);
CREATE TABLE challenge_attempts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID NOT NULL REFERENCES daily_challenges(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_solved    BOOLEAN NOT NULL DEFAULT false,
    solved_at    TIMESTAMPTZ,
    UNIQUE (challenge_id, user_id)
);
```

Solves are verified against the Codeforces API using `users.codeforces_handle`, so a
user must link and verify a handle before the daily challenge counts.

## `ai_hints` — planned

```sql
CREATE TABLE ai_hints (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quest_id   UUID NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
    hint_text  TEXT NOT NULL,
    cost       INT NOT NULL DEFAULT 5,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Doubles as the rate-limit source: count rows for the user in the last hour, cap at 3.

---

## Search

Enable once, before building search or duplicate detection:

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX quests_title_trgm ON quests USING GIN (title gin_trgm_ops);
CREATE INDEX quests_body_trgm  ON quests USING GIN (description gin_trgm_ops);
```

## Row Level Security

The server connects with a privileged `DATABASE_URL` and **bypasses RLS**, so
authorization is enforced in the service layer — every mutation must check ownership
against `get_current_user_id`. RLS still matters for anything the Flutter client reads
from Supabase directly (currently only Storage). Keep policies read-only-public,
write-own if you add one.
