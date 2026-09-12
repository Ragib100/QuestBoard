# Database

Postgres, hosted by Supabase. Fourteen tables in `public`, plus Supabase's own
`auth` schema and two Storage buckets.

| File | Covers |
|---|---|
| [schema.md](schema.md) | **Every table and every column**, regenerated from the running database |
| [economy.md](economy.md) | The point ledger: reasons, invariants, and every path that moves points |
| [indexes-and-rls.md](indexes-and-rls.md) | Indexes, trigram search, the `updated_at` trigger, RLS policies |

The ORM mirror lives in `server/app/models/`
([../backend/models.md](../backend/models.md)) and the runnable copy in
`server/schema.sql`. **All three must stay in step.**

## Applying the schema

Paste `server/schema.sql` into the Supabase SQL editor and run it. It is
**idempotent** — re-running is safe and is in fact how you repair a database that
drifted, because the file deliberately mixes three kinds of statement:

| Statement | Why |
|---|---|
| `create table if not exists` | The base tables |
| `alter table ... add column if not exists` | Columns added after the first run. `create table if not exists` skips an existing table **entirely**, so a new column needs its own line or it silently never appears |
| `drop constraint ... ; add constraint ...` | The `reason` CHECK. Recreated rather than added-if-absent, so re-running **repairs** an out-of-date constraint instead of skipping it |

The file also carries two data statements: the badge and tag seeds
(`on conflict do nothing`, with a follow-up `update` that re-applies badge
descriptions, since names never change but the condition text is allowed to
improve), and an idempotent backfill for accounts that predate the ledgered
signup bonus.

Full walkthrough, including the connection string and the Storage buckets:
[../setup.md](../setup.md) steps 2–3.

## Conventions

**`auth.users` is Supabase's own table. Never write to it.** Our `public.users`
row shares its primary key, and **email lives only in `auth.users`** — it is
never copied into our schema. That is why admin user search covers username and
names but not email.

**The table is `questions`; the product calls it a quest.** Every foreign key,
route and JSON key says `question`. Do not rename one without the other
([../decisions.md](../decisions.md) D1).

**Timestamps are stored in UTC; every calendar question is answered in
Asia/Dhaka.** The live schema is mixed — some columns are `timestamptz` and some
are naive `timestamp` holding UTC, because `add column if not exists` kept
whatever type a column was created with. Two consequences that have already
caused bugs are spelled out in [schema.md](schema.md#timestamps-utc-in-the-rows-dhaka-on-the-screen):
a naive column serialises with **no zone marker**, and you must never hand
Postgres an aware value for a naive column.

**Polymorphic columns carry no foreign key.** `votes.target_id` and
`notifications.reference_id` both point at more than one table, so the type
column tells you where to look — and deleting a quest must delete its votes
explicitly, because nothing cascades them.

## Storage buckets

Neither is in Postgres, and the server never proxies file bytes — the client
uploads directly and sends only the resulting path or URL
([../architecture.md](../architecture.md)).

| Bucket | Holds | Stored as |
|---|---|---|
| `profile_image` | Avatars, at `<uid>/<epoch>.png` | `users.image_url` holds the **path**; the client builds the URL with `getPublicUrl` |
| `submissions` | Files attached to answers and challenge attempts | `attachment_url` holds the **public URL**, `attachment_name` the original filename |

Code itself is **not** in a bucket. `code_body` is plain text stored in
Postgres: it is small, it belongs to the row, and putting it in a bucket would
mean a second fetch to render an answer
([../decisions.md](../decisions.md) D27).

## Table inventory

| Table | Rows are |
|---|---|
| `users` | Profiles, keyed to `auth.users` |
| `questions` | Quests |
| `answers` | Answers, optionally carrying code and an attachment |
| `votes` | One per user per target |
| `point_transactions` | **The ledger** |
| `tags` / `question_tags` | 14 seeded tags, and the join |
| `notifications` | In-app notifications |
| `badges` / `user_badges` | The catalogue, and who has earned what |
| `ai_hints` | One per hint the model actually returned |
| `daily_challenges` | One Codeforces problem per calendar day |
| `challenge_attempts` | One per user per challenge |

Every table has an ORM model and at least one endpoint. The one vestige is
`questions.difficulty`, which nothing reads or writes — difficulty lives on the
daily challenge, not on quests.
