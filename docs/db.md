# QuestBoard Database Reference

**Database:** Supabase PostgreSQL  
**Version:** PostgreSQL 15  
**Project:** QuestBoard — A Gamified Q&A Platform for STEM Problem Solving

> All tables live in the `public` schema unless noted otherwise.
> The `auth` schema is managed entirely by Supabase Auth — do not modify it.
> UUIDs are generated using `gen_random_uuid()` (pgcrypto, enabled by default on Supabase).

---

## Table of Contents

1. [Overview](#1-overview)
2. [Schema Diagram (Text)](#2-schema-diagram-text)
3. [Tables](#3-tables)
   - [users](#31-users)
   - [questions](#32-questions)
   - [answers](#33-answers)
   - [tags](#34-tags)
   - [question_tags](#35-question_tags)
   - [votes](#36-votes)
   - [point_transactions](#37-point_transactions)
   - [ai_hints](#38-ai_hints)
   - [daily_challenges](#39-daily_challenges)
   - [challenge_attempts](#310-challenge_attempts)
   - [badges](#311-badges)
   - [user_badges](#312-user_badges)
   - [notifications](#313-notifications)
4. [Relationships Summary](#4-relationships-summary)
5. [Key Design Decisions](#5-key-design-decisions)
6. [Supabase Storage Buckets](#6-supabase-storage-buckets)
7. [Database Triggers](#7-database-triggers)
8. [Row Level Security (RLS)](#8-row-level-security-rls)
9. [Indexes](#9-indexes)
10. [Full Database Setup SQL](#10-full-database-setup-sql)
11. [dbdiagram.io Code](#11-dbdiagramio-code)

---

## 1. Overview

QuestBoard uses a single Supabase PostgreSQL database for all persistent data. The schema is organized around five core domains:

| Domain | Tables |
|---|---|
| **Identity** | `users` |
| **Q&A** | `questions`, `answers`, `tags`, `question_tags`, `votes` |
| **Economy** | `point_transactions` |
| **AI** | `ai_hints` |
| **Challenges** | `daily_challenges`, `challenge_attempts` |
| **Gamification** | `badges`, `user_badges`, `notifications` |

**Starting point balance:** Every new user begins with **100 points**, credited automatically on account creation via a DB trigger.

**Points rule:** Points are never deleted or updated in-place. Every change is a new row in `point_transactions`. The `users.points` column is the fast-read cache of the running total.

---

## 2. Schema Diagram (Text)

```
auth.users (Supabase managed)
    │
    │ id = users.id (trigger on insert)
    ▼
┌─────────┐       ┌─────────────┐       ┌─────────┐
│  users  │──1:N──│  questions  │──1:N──│ answers │
└─────────┘       └─────────────┘       └─────────┘
    │ 1                │ N                   │ N
    │              question_tags          (votes)
    │                  │ N
    │               ┌──┴──┐
    │               │ tags│
    │               └─────┘
    │ 1
    ├──────────────── point_transactions (N)
    ├──────────────── ai_hints (N)
    ├──────────────── votes (N)
    ├──────────────── challenge_attempts (N)
    ├──────────────── user_badges (N)
    └──────────────── notifications (N)

daily_challenges ──1:N── challenge_attempts
badges ──1:N── user_badges
```

---

## 3. Tables

---

### 3.1 `users`

Stores public profile data for every registered user. The `id` must match the uuid issued by Supabase Auth (`auth.users.id`). This row is created automatically via trigger when a user signs up.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | — | Matches `auth.users.id` |
| `username` | `varchar(50)` | NOT NULL, UNIQUE | — | Public display name |
| `avatar_url` | `text` | nullable | `null` | Supabase Storage path |
| `bio` | `text` | nullable | `null` | Short user bio |
| `points` | `int` | NOT NULL | `100` | Current point balance (cache) |
| `streak_days` | `int` | NOT NULL | `0` | Consecutive active days |
| `last_active` | `timestamp` | nullable | `null` | Last activity timestamp |
| `created_at` | `timestamp` | NOT NULL | `now()` | Account creation time |
| `updated_at` | `timestamp` | NOT NULL | `now()` | Last profile update |

**Notes:**
- `password_hash` is NOT stored here — Supabase Auth owns credentials.
- `points` is always kept in sync with the sum of `point_transactions.amount` for this user. Never update `points` directly — always go through the transaction flow.
- `avatar_url` stores the Supabase Storage path: `avatars/{user_id}`.

**SQL:**
```sql
CREATE TABLE public.users (
  id          uuid PRIMARY KEY,
  username    varchar(50) NOT NULL UNIQUE,
  avatar_url  text,
  bio         text,
  points      int NOT NULL DEFAULT 100,
  streak_days int NOT NULL DEFAULT 0,
  last_active timestamp,
  created_at  timestamp NOT NULL DEFAULT now(),
  updated_at  timestamp NOT NULL DEFAULT now()
);
```

---

### 3.2 `questions`

The core entity of QuestBoard. Each question is posted by a user, optionally carries a bounty, and can have one accepted answer.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Question ID |
| `author_id` | `uuid` | NOT NULL, FK → `users.id` | — | Who posted it |
| `title` | `text` | NOT NULL | — | Short question title |
| `body` | `text` | NOT NULL | — | Full question (supports LaTeX and code blocks) |
| `image_url` | `text` | nullable | `null` | Optional attached image (Supabase Storage) |
| `bounty_points` | `int` | NOT NULL | `0` | Points locked as bounty |
| `is_solved` | `bool` | NOT NULL | `false` | True when an answer is accepted |
| `accepted_answer_id` | `uuid` | nullable, FK → `answers.id` | `null` | The winning answer |
| `view_count` | `int` | NOT NULL | `0` | Incremented on each unique view |
| `difficulty` | `varchar(10)` | nullable | `null` | `easy`, `medium`, or `hard` — AI-graded |
| `created_at` | `timestamp` | NOT NULL | `now()` | Post time |
| `updated_at` | `timestamp` | NOT NULL | `now()` | Last edit time |

**Notes:**
- When a question is posted with `bounty_points > 0`, that amount is immediately deducted from `users.points` and logged in `point_transactions` with `reason = 'bounty_posted'`.
- `accepted_answer_id` creates a circular FK with `answers.id`. Declare it as `DEFERRABLE INITIALLY DEFERRED` to avoid insert-order conflicts.
- `image_url` path format: `question-images/{question_id}/image`.

**SQL:**
```sql
CREATE TABLE public.questions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id          uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title              text NOT NULL,
  body               text NOT NULL,
  image_url          text,
  bounty_points      int NOT NULL DEFAULT 0,
  is_solved          bool NOT NULL DEFAULT false,
  accepted_answer_id uuid,
  view_count         int NOT NULL DEFAULT 0,
  difficulty         varchar(10) CHECK (difficulty IN ('easy', 'medium', 'hard')),
  created_at         timestamp NOT NULL DEFAULT now(),
  updated_at         timestamp NOT NULL DEFAULT now()
);
```

---

### 3.3 `answers`

Answers submitted by helpers in response to a question. One answer per question can be accepted, triggering bounty transfer.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Answer ID |
| `question_id` | `uuid` | NOT NULL, FK → `questions.id` | — | Parent question |
| `author_id` | `uuid` | NOT NULL, FK → `users.id` | — | Who answered |
| `body` | `text` | NOT NULL | — | Answer content (supports code and LaTeX) |
| `is_accepted` | `bool` | NOT NULL | `false` | True when the question owner accepts this |
| `created_at` | `timestamp` | NOT NULL | `now()` | Submit time |
| `updated_at` | `timestamp` | NOT NULL | `now()` | Last edit time |

**Notes:**
- When `is_accepted` is flipped to `true`: `questions.is_solved` is set to `true`, `questions.accepted_answer_id` is set to this answer's `id`, and `bounty_points` are transferred to the answer author via `point_transactions`.
- An accepted answer cannot be deleted.
- A question can only have one accepted answer — enforced in application logic.

**SQL:**
```sql
CREATE TABLE public.answers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  author_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body        text NOT NULL,
  is_accepted bool NOT NULL DEFAULT false,
  created_at  timestamp NOT NULL DEFAULT now(),
  updated_at  timestamp NOT NULL DEFAULT now()
);
```

---

### 3.4 `tags`

A fixed catalog of topic tags used to categorize questions.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Tag ID |
| `name` | `varchar(50)` | NOT NULL, UNIQUE | — | Tag label e.g. `dsa`, `math`, `physics` |

**Seed data (initial tags):**
```
dsa, math, physics, chemistry, calculus, linear-algebra,
graph-theory, dynamic-programming, number-theory, geometry,
data-structures, algorithms, probability, statistics
```

**SQL:**
```sql
CREATE TABLE public.tags (
  id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(50) NOT NULL UNIQUE
);
```

---

### 3.5 `question_tags`

Junction table linking questions to their tags (many-to-many).

| Column | Type | Constraints | Description |
|---|---|---|---|
| `question_id` | `uuid` | NOT NULL, FK → `questions.id` | The question |
| `tag_id` | `uuid` | NOT NULL, FK → `tags.id` | The tag |

**Primary key:** `(question_id, tag_id)`

**SQL:**
```sql
CREATE TABLE public.question_tags (
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  tag_id      uuid NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, tag_id)
);
```

---

### 3.6 `votes`

Polymorphic votes table covering both question votes and answer votes. A user can vote on any target at most once — the unique index enforces this.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Vote ID |
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | Who voted |
| `target_type` | `varchar(10)` | NOT NULL | — | `question` or `answer` |
| `target_id` | `uuid` | NOT NULL | — | ID of the question or answer |
| `value` | `smallint` | NOT NULL | — | `1` (upvote) or `-1` (downvote) |
| `created_at` | `timestamp` | NOT NULL | `now()` | Vote time |

**Unique index:** `(user_id, target_type, target_id)` — prevents double-voting.

**Toggle logic:** If a user sends the same `value` again, the vote is removed. If they send the opposite `value`, the existing row is updated.

**SQL:**
```sql
CREATE TABLE public.votes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  target_type varchar(10) NOT NULL CHECK (target_type IN ('question', 'answer')),
  target_id   uuid NOT NULL,
  value       smallint NOT NULL CHECK (value IN (1, -1)),
  created_at  timestamp NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_type, target_id)
);
```

---

### 3.7 `point_transactions`

Immutable audit log of every point change in the system. Never update or delete rows here. The running sum of `amount` per user equals their `users.points` balance.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Transaction ID |
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | Whose balance changed |
| `amount` | `int` | NOT NULL | — | Positive = earned, negative = spent |
| `reason` | `varchar(50)` | NOT NULL | — | See reason codes below |
| `reference_id` | `uuid` | nullable | `null` | Related object ID (question, answer, challenge) |
| `created_at` | `timestamp` | NOT NULL | `now()` | When it happened |

**Reason codes:**

| Reason | Amount | Trigger |
|---|---|---|
| `signup_bonus` | `+100` | New user created |
| `bounty_posted` | `-N` | User posts a question with bounty |
| `bounty_awarded` | `+N` | Answer accepted, bounty received |
| `hint_used` | `-5` | AI hint requested |
| `vote_received` | `+1` | Someone upvoted your question or answer |
| `vote_lost` | `-1` | Someone downvoted your question or answer |
| `challenge_solved` | `+N` | Daily challenge completed |
| `daily_bonus` | `+10` | First activity of the day (streak reward) |

**SQL:**
```sql
CREATE TABLE public.point_transactions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount       int NOT NULL,
  reason       varchar(50) NOT NULL,
  reference_id uuid,
  created_at   timestamp NOT NULL DEFAULT now()
);
```

---

### 3.8 `ai_hints`

Stores every AI hint generated for a user on a question. Used as an audit log and for rate-limiting hint requests.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Hint ID |
| `question_id` | `uuid` | NOT NULL, FK → `questions.id` | — | Which question |
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | Who requested it |
| `hint_text` | `text` | NOT NULL | — | The Socratic hint returned by the LLM |
| `points_cost` | `int` | NOT NULL | `5` | Points deducted for this hint |
| `created_at` | `timestamp` | NOT NULL | `now()` | Request time |

**Notes:**
- Rows are immutable — never updated after insert.
- To rate-limit: count rows where `user_id = X AND question_id = Y AND created_at > now() - interval '1 hour'`. Block if count ≥ 3.
- `points_cost` is stored per-row to support variable pricing in future (e.g., harder questions cost more hints).

**SQL:**
```sql
CREATE TABLE public.ai_hints (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  hint_text   text NOT NULL,
  points_cost int NOT NULL DEFAULT 5,
  created_at  timestamp NOT NULL DEFAULT now()
);
```

---

### 3.9 `daily_challenges`

One row per day, populated automatically by a cron job that hits the Codeforces API at midnight.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Challenge ID |
| `codeforces_id` | `varchar(20)` | nullable | `null` | e.g. `1234A` |
| `title` | `text` | NOT NULL | — | Problem title |
| `body` | `text` | NOT NULL | — | Full problem statement |
| `difficulty` | `varchar(10)` | nullable | `null` | `easy`, `medium`, or `hard` |
| `source_url` | `text` | nullable | `null` | Link to original Codeforces problem |
| `bonus_points` | `int` | NOT NULL | `50` | Points awarded on solve |
| `challenge_date` | `date` | NOT NULL, UNIQUE | — | One challenge per day |
| `created_at` | `timestamp` | NOT NULL | `now()` | When the row was inserted |

**SQL:**
```sql
CREATE TABLE public.daily_challenges (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  codeforces_id  varchar(20),
  title          text NOT NULL,
  body           text NOT NULL,
  difficulty     varchar(10) CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source_url     text,
  bonus_points   int NOT NULL DEFAULT 50,
  challenge_date date NOT NULL UNIQUE,
  created_at     timestamp NOT NULL DEFAULT now()
);
```

---

### 3.10 `challenge_attempts`

Tracks each user's progress on daily challenges. One row per `(user, challenge)` pair — never insert a second row, only update the existing one.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Attempt ID |
| `challenge_id` | `uuid` | NOT NULL, FK → `daily_challenges.id` | — | Which challenge |
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | Who attempted |
| `is_solved` | `bool` | NOT NULL | `false` | Flips to `true` on successful solve |
| `solved_at` | `timestamp` | nullable | `null` | When `is_solved` was set to `true` |
| `created_at` | `timestamp` | NOT NULL | `now()` | When the attempt was first recorded |

**Unique index:** `(challenge_id, user_id)` — one attempt row per user per challenge.

**SQL:**
```sql
CREATE TABLE public.challenge_attempts (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid NOT NULL REFERENCES public.daily_challenges(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_solved    bool NOT NULL DEFAULT false,
  solved_at    timestamp,
  created_at   timestamp NOT NULL DEFAULT now(),
  UNIQUE (challenge_id, user_id)
);
```

---

### 3.11 `badges`

Catalog of all available badges. Rows here are created by the development team — not by users.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Badge ID |
| `name` | `varchar(50)` | NOT NULL, UNIQUE | — | Machine-readable name |
| `description` | `text` | NOT NULL | — | Human-readable explanation |
| `icon_url` | `text` | nullable | `null` | Supabase Storage path |

**Seed data:**

| Name | Description |
|---|---|
| `first_answer` | Submitted your first answer |
| `first_bounty` | Won your first bounty |
| `streak_5` | Maintained a 5-day activity streak |
| `streak_30` | Maintained a 30-day activity streak |
| `bounty_hunter` | Won 10 bounties total |
| `top_helper` | Ranked in the top 10 on the weekly leaderboard |
| `challenger` | Solved 7 daily challenges |
| `ai_skeptic` | Solved a question without using any AI hints |

**SQL:**
```sql
CREATE TABLE public.badges (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        varchar(50) NOT NULL UNIQUE,
  description text NOT NULL,
  icon_url    text
);
```

---

### 3.12 `user_badges`

Junction table recording which badges each user has earned and when.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | The user |
| `badge_id` | `uuid` | NOT NULL, FK → `badges.id` | — | The badge |
| `awarded_at` | `timestamp` | NOT NULL | `now()` | When it was awarded |

**Primary key:** `(user_id, badge_id)`

**SQL:**
```sql
CREATE TABLE public.user_badges (
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  badge_id   uuid NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  awarded_at timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, badge_id)
);
```

---

### 3.13 `notifications`

In-app notification inbox for each user. Separate from Firebase push notifications — this drives the bell icon and unread count in the Flutter UI.

| Column | Type | Constraints | Default | Description |
|---|---|---|---|---|
| `id` | `uuid` | PK | `gen_random_uuid()` | Notification ID |
| `user_id` | `uuid` | NOT NULL, FK → `users.id` | — | Recipient |
| `type` | `varchar(30)` | NOT NULL | — | See type codes below |
| `message` | `text` | NOT NULL | — | Human-readable notification text |
| `reference_id` | `uuid` | nullable | `null` | Related object (question, answer, badge) |
| `is_read` | `bool` | NOT NULL | `false` | Read status |
| `created_at` | `timestamp` | NOT NULL | `now()` | When it was created |

**Type codes:**

| Type | Meaning |
|---|---|
| `answer_received` | Someone answered your question |
| `answer_accepted` | Your answer was accepted |
| `bounty_awarded` | You received bounty points |
| `vote_received` | Your content was upvoted |
| `badge_earned` | You earned a new badge |

**SQL:**
```sql
CREATE TABLE public.notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type         varchar(30) NOT NULL,
  message      text NOT NULL,
  reference_id uuid,
  is_read      bool NOT NULL DEFAULT false,
  created_at   timestamp NOT NULL DEFAULT now()
);
```

---

## 4. Relationships Summary

| Relationship | Type | Description |
|---|---|---|
| `users` → `questions` | 1 : N | A user authors many questions |
| `users` → `answers` | 1 : N | A user submits many answers |
| `questions` → `answers` | 1 : N | A question has many answers |
| `questions` → `question_tags` | 1 : N | A question has many tags |
| `tags` → `question_tags` | 1 : N | A tag appears on many questions |
| `users` → `votes` | 1 : N | A user casts many votes |
| `users` → `point_transactions` | 1 : N | A user has many point events |
| `users` → `ai_hints` | 1 : N | A user requests many hints |
| `questions` → `ai_hints` | 1 : N | A question can have many hints (from different users) |
| `daily_challenges` → `challenge_attempts` | 1 : N | A challenge has many attempts |
| `users` → `challenge_attempts` | 1 : N | A user attempts many challenges |
| `badges` → `user_badges` | 1 : N | A badge can be earned by many users |
| `users` → `user_badges` | 1 : N | A user earns many badges |
| `users` → `notifications` | 1 : N | A user receives many notifications |
| `questions` → `questions.accepted_answer_id` | 1 : 1 | A question has at most one accepted answer |

---

## 5. Key Design Decisions

### Points are a ledger, not a counter
`users.points` is a denormalized cache for fast reads. The source of truth is the sum of `point_transactions.amount` for that user. Always update both in a single DB transaction:

```sql
BEGIN;
  INSERT INTO point_transactions (user_id, amount, reason, reference_id)
  VALUES ($1, -5, 'hint_used', $2);

  UPDATE users SET points = points - 5 WHERE id = $1;
COMMIT;
```

### Polymorphic votes table
Rather than separate `question_votes` and `answer_votes` tables, a single `votes` table uses `target_type` + `target_id`. This keeps vote logic in one place. The unique constraint on `(user_id, target_type, target_id)` prevents abuse at the DB level.

### Circular FK on questions ↔ answers
`questions.accepted_answer_id` references `answers.id`, while `answers.question_id` references `questions.id`. To insert both without ordering issues, the FK on `accepted_answer_id` is deferred:

```sql
ALTER TABLE public.questions
  ADD CONSTRAINT fk_accepted_answer
  FOREIGN KEY (accepted_answer_id)
  REFERENCES public.answers(id)
  DEFERRABLE INITIALLY DEFERRED;
```

### One attempt row per user per challenge
`challenge_attempts` uses a unique index on `(challenge_id, user_id)`. On first visit, `INSERT` a row with `is_solved = false`. On solve, `UPDATE` that same row — never insert a second one.

### Notifications are separate from push
The `notifications` table drives the in-app bell icon. Firebase Cloud Messaging (FCM) handles the actual push notification delivery. Both are triggered by the same backend event, but they are independent — a user can clear in-app notifications without affecting FCM history.

---

## 6. Supabase Storage Buckets

| Bucket | Path Pattern | Public | Used By |
|---|---|---|---|
| `avatars` | `avatars/{user_id}` | Yes | `users.avatar_url` |
| `question-images` | `question-images/{question_id}/image` | Yes | `questions.image_url` |
| `badges` | `badges/{badge_name}.png` | Yes | `badges.icon_url` |

All buckets are public read. Uploads are restricted to authenticated users via Supabase Storage RLS policies.

---

## 7. Database Triggers

### `on_auth_user_created`
Fires after a new user is created in `auth.users`. Inserts a matching row into `public.users` and credits the signup bonus in `point_transactions`.

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Create public profile
  INSERT INTO public.users (id, username, created_at, updated_at)
  VALUES (
    NEW.id,
    SPLIT_PART(NEW.email, '@', 1), -- default username from email
    now(),
    now()
  );

  -- Credit signup bonus
  INSERT INTO public.point_transactions (user_id, amount, reason)
  VALUES (NEW.id, 100, 'signup_bonus');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### `update_updated_at`
Automatically updates the `updated_at` column on `users`, `questions`, and `answers` whenever a row is modified.

```sql
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_questions_updated_at
  BEFORE UPDATE ON public.questions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_answers_updated_at
  BEFORE UPDATE ON public.answers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
```

---

## 8. Row Level Security (RLS)

All tables have RLS enabled on Supabase. Key policies:

| Table | Read | Insert | Update | Delete |
|---|---|---|---|---|
| `users` | Anyone | Trigger only | Own row | Not allowed |
| `questions` | Anyone | Authenticated | Own row | Own row (if unsolved) |
| `answers` | Anyone | Authenticated | Own row | Own row (if not accepted) |
| `votes` | Anyone | Authenticated | Own row | Own row |
| `point_transactions` | Own rows | Service role only | Not allowed | Not allowed |
| `ai_hints` | Own rows | Authenticated | Not allowed | Not allowed |
| `notifications` | Own rows | Service role only | Own rows | Own rows |
| `daily_challenges` | Anyone | Service role only | Service role only | Not allowed |
| `challenge_attempts` | Own rows | Authenticated | Own rows | Not allowed |
| `badges` | Anyone | Service role only | Service role only | Not allowed |
| `user_badges` | Anyone | Service role only | Not allowed | Not allowed |
| `tags` | Anyone | Service role only | Not allowed | Not allowed |
| `question_tags` | Anyone | Authenticated | Not allowed | Own question's tags |

> **Service role** = your FastAPI backend using the Supabase service key. Never expose the service key to the Flutter client.

---

## 9. Indexes

Indexes beyond primary keys, for query performance:

```sql
-- Questions feed (sorted by newest, bounty, votes)
CREATE INDEX idx_questions_created_at ON public.questions (created_at DESC);
CREATE INDEX idx_questions_bounty ON public.questions (bounty_points DESC);
CREATE INDEX idx_questions_author ON public.questions (author_id);

-- Answers per question
CREATE INDEX idx_answers_question ON public.answers (question_id);
CREATE INDEX idx_answers_author ON public.answers (author_id);

-- Votes lookup
CREATE INDEX idx_votes_target ON public.votes (target_type, target_id);

-- Point transactions per user
CREATE INDEX idx_ptx_user ON public.point_transactions (user_id, created_at DESC);

-- AI hints rate limiting
CREATE INDEX idx_hints_user_question ON public.ai_hints (user_id, question_id, created_at DESC);

-- Notifications unread count
CREATE INDEX idx_notifications_user_unread ON public.notifications (user_id, is_read);

-- Challenge by date
CREATE INDEX idx_challenges_date ON public.daily_challenges (challenge_date DESC);

-- Leaderboard (weekly sort)
CREATE INDEX idx_users_points ON public.users (points DESC);
```

---

## 10. Full Database Setup SQL

Copy and paste this entire block into the Supabase **SQL Editor** and run it once. It handles creation order, the circular FK, triggers, indexes, seed data, and RLS policies in one shot.

> **Before running:** Make sure you are in the `public` schema. Do not run this on a database that already has these tables — it will error on duplicates. If you need to reset, run the drop block at the bottom first.

```sql
-- ============================================================
-- QuestBoard — Full Database Setup
-- Run this in Supabase SQL Editor (once, on a fresh project)
-- ============================================================


-- ─── EXTENSIONS ─────────────────────────────────────────────
-- pgcrypto is enabled by default on Supabase (for gen_random_uuid)
-- pg_trgm enables full-text similarity search on questions
CREATE EXTENSION IF NOT EXISTS pg_trgm;


-- ─── HELPER FUNCTION: updated_at trigger ────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ─── 1. USERS ────────────────────────────────────────────────
CREATE TABLE public.users (
  id          uuid         PRIMARY KEY,
  username    varchar(50)  NOT NULL UNIQUE,
  avatar_url  text,
  bio         text,
  points      int          NOT NULL DEFAULT 100,
  streak_days int          NOT NULL DEFAULT 0,
  last_active timestamp,
  created_at  timestamp    NOT NULL DEFAULT now(),
  updated_at  timestamp    NOT NULL DEFAULT now()
);

CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ─── 2. TAGS ─────────────────────────────────────────────────
CREATE TABLE public.tags (
  id   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(50) NOT NULL UNIQUE
);

-- Seed tags
INSERT INTO public.tags (name) VALUES
  ('dsa'),
  ('math'),
  ('physics'),
  ('chemistry'),
  ('calculus'),
  ('linear-algebra'),
  ('graph-theory'),
  ('dynamic-programming'),
  ('number-theory'),
  ('geometry'),
  ('data-structures'),
  ('algorithms'),
  ('probability'),
  ('statistics');


-- ─── 3. QUESTIONS (without circular FK yet) ──────────────────
CREATE TABLE public.questions (
  id                 uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id          uuid         NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title              text         NOT NULL,
  body               text         NOT NULL,
  image_url          text,
  bounty_points      int          NOT NULL DEFAULT 0,
  is_solved          bool         NOT NULL DEFAULT false,
  accepted_answer_id uuid,                      -- FK added after answers table
  view_count         int          NOT NULL DEFAULT 0,
  difficulty         varchar(10)  CHECK (difficulty IN ('easy', 'medium', 'hard')),
  created_at         timestamp    NOT NULL DEFAULT now(),
  updated_at         timestamp    NOT NULL DEFAULT now()
);

CREATE TRIGGER set_questions_updated_at
  BEFORE UPDATE ON public.questions
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ─── 4. ANSWERS ──────────────────────────────────────────────
CREATE TABLE public.answers (
  id          uuid       PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid       NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  author_id   uuid       NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  body        text       NOT NULL,
  is_accepted bool       NOT NULL DEFAULT false,
  created_at  timestamp  NOT NULL DEFAULT now(),
  updated_at  timestamp  NOT NULL DEFAULT now()
);

CREATE TRIGGER set_answers_updated_at
  BEFORE UPDATE ON public.answers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Now add the circular FK from questions → answers (deferred to avoid ordering issues)
ALTER TABLE public.questions
  ADD CONSTRAINT fk_accepted_answer
  FOREIGN KEY (accepted_answer_id)
  REFERENCES public.answers(id)
  DEFERRABLE INITIALLY DEFERRED;


-- ─── 5. QUESTION_TAGS ────────────────────────────────────────
CREATE TABLE public.question_tags (
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  tag_id      uuid NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (question_id, tag_id)
);


-- ─── 6. VOTES ────────────────────────────────────────────────
CREATE TABLE public.votes (
  id          uuid       PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid       NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  target_type varchar(10) NOT NULL CHECK (target_type IN ('question', 'answer')),
  target_id   uuid       NOT NULL,
  value       smallint   NOT NULL CHECK (value IN (1, -1)),
  created_at  timestamp  NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_type, target_id)
);


-- ─── 7. POINT_TRANSACTIONS ───────────────────────────────────
CREATE TABLE public.point_transactions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount       int         NOT NULL,
  reason       varchar(50) NOT NULL
                CHECK (reason IN (
                  'signup_bonus', 'bounty_posted', 'bounty_awarded',
                  'hint_used', 'vote_received', 'vote_lost',
                  'challenge_solved', 'daily_bonus'
                )),
  reference_id uuid,
  created_at   timestamp   NOT NULL DEFAULT now()
);


-- ─── 8. AI_HINTS ─────────────────────────────────────────────
CREATE TABLE public.ai_hints (
  id          uuid      PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid      NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  user_id     uuid      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  hint_text   text      NOT NULL,
  points_cost int       NOT NULL DEFAULT 5,
  created_at  timestamp NOT NULL DEFAULT now()
);


-- ─── 9. DAILY_CHALLENGES ─────────────────────────────────────
CREATE TABLE public.daily_challenges (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  codeforces_id  varchar(20),
  title          text        NOT NULL,
  body           text        NOT NULL,
  difficulty     varchar(10) CHECK (difficulty IN ('easy', 'medium', 'hard')),
  source_url     text,
  bonus_points   int         NOT NULL DEFAULT 50,
  challenge_date date        NOT NULL UNIQUE,
  created_at     timestamp   NOT NULL DEFAULT now()
);


-- ─── 10. CHALLENGE_ATTEMPTS ──────────────────────────────────
CREATE TABLE public.challenge_attempts (
  id           uuid      PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id uuid      NOT NULL REFERENCES public.daily_challenges(id) ON DELETE CASCADE,
  user_id      uuid      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  is_solved    bool      NOT NULL DEFAULT false,
  solved_at    timestamp,
  created_at   timestamp NOT NULL DEFAULT now(),
  UNIQUE (challenge_id, user_id)
);


-- ─── 11. BADGES ──────────────────────────────────────────────
CREATE TABLE public.badges (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        varchar(50) NOT NULL UNIQUE,
  description text        NOT NULL,
  icon_url    text
);

-- Seed badges
INSERT INTO public.badges (name, description) VALUES
  ('first_answer',  'Submitted your first answer'),
  ('first_bounty',  'Won your first bounty'),
  ('streak_5',      'Maintained a 5-day activity streak'),
  ('streak_30',     'Maintained a 30-day activity streak'),
  ('bounty_hunter', 'Won 10 bounties total'),
  ('top_helper',    'Ranked in the top 10 on the weekly leaderboard'),
  ('challenger',    'Solved 7 daily challenges'),
  ('ai_skeptic',    'Solved a question without using any AI hints');


-- ─── 12. USER_BADGES ─────────────────────────────────────────
CREATE TABLE public.user_badges (
  user_id    uuid      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  badge_id   uuid      NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
  awarded_at timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, badge_id)
);


-- ─── 13. NOTIFICATIONS ───────────────────────────────────────
CREATE TABLE public.notifications (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type         varchar(30) NOT NULL
                CHECK (type IN (
                  'answer_received', 'answer_accepted',
                  'bounty_awarded', 'vote_received', 'badge_earned'
                )),
  message      text        NOT NULL,
  reference_id uuid,
  is_read      bool        NOT NULL DEFAULT false,
  created_at   timestamp   NOT NULL DEFAULT now()
);


-- ─── INDEXES ─────────────────────────────────────────────────
CREATE INDEX idx_questions_created_at  ON public.questions        (created_at DESC);
CREATE INDEX idx_questions_bounty      ON public.questions        (bounty_points DESC);
CREATE INDEX idx_questions_author      ON public.questions        (author_id);
CREATE INDEX idx_questions_trgm_title  ON public.questions        USING gin (title gin_trgm_ops);
CREATE INDEX idx_questions_trgm_body   ON public.questions        USING gin (body gin_trgm_ops);
CREATE INDEX idx_answers_question      ON public.answers          (question_id);
CREATE INDEX idx_answers_author        ON public.answers          (author_id);
CREATE INDEX idx_votes_target          ON public.votes            (target_type, target_id);
CREATE INDEX idx_ptx_user              ON public.point_transactions (user_id, created_at DESC);
CREATE INDEX idx_hints_user_question   ON public.ai_hints         (user_id, question_id, created_at DESC);
CREATE INDEX idx_notifications_unread  ON public.notifications    (user_id, is_read);
CREATE INDEX idx_challenges_date       ON public.daily_challenges (challenge_date DESC);
CREATE INDEX idx_users_points          ON public.users            (points DESC);


-- ─── TRIGGER: auto-create user profile on signup ─────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, username, created_at, updated_at)
  VALUES (
    NEW.id,
    SPLIT_PART(NEW.email, '@', 1),
    now(),
    now()
  );

  INSERT INTO public.point_transactions (user_id, amount, reason)
  VALUES (NEW.id, 100, 'signup_bonus');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ─── ROW LEVEL SECURITY ──────────────────────────────────────
ALTER TABLE public.users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.answers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_tags       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_transactions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_hints            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_challenges    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_attempts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.badges              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications       ENABLE ROW LEVEL SECURITY;

-- users
CREATE POLICY "Public read users"        ON public.users FOR SELECT USING (true);
CREATE POLICY "User updates own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- questions
CREATE POLICY "Public read questions"    ON public.questions FOR SELECT USING (true);
CREATE POLICY "Auth can post questions"  ON public.questions FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Author edits question"    ON public.questions FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "Author deletes question"  ON public.questions FOR DELETE USING (auth.uid() = author_id AND is_solved = false);

-- answers
CREATE POLICY "Public read answers"      ON public.answers FOR SELECT USING (true);
CREATE POLICY "Auth can post answers"    ON public.answers FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Author edits answer"      ON public.answers FOR UPDATE USING (auth.uid() = author_id AND is_accepted = false);
CREATE POLICY "Author deletes answer"    ON public.answers FOR DELETE USING (auth.uid() = author_id AND is_accepted = false);

-- tags
CREATE POLICY "Public read tags"         ON public.tags FOR SELECT USING (true);

-- question_tags
CREATE POLICY "Public read question_tags" ON public.question_tags FOR SELECT USING (true);
CREATE POLICY "Auth manages own question_tags"
  ON public.question_tags FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.questions q
      WHERE q.id = question_id AND q.author_id = auth.uid()
    )
  );

-- votes
CREATE POLICY "Public read votes"        ON public.votes FOR SELECT USING (true);
CREATE POLICY "Auth can vote"            ON public.votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User manages own vote"    ON public.votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "User deletes own vote"    ON public.votes FOR DELETE USING (auth.uid() = user_id);

-- point_transactions (read own only, insert via service role)
CREATE POLICY "User reads own transactions"
  ON public.point_transactions FOR SELECT USING (auth.uid() = user_id);

-- ai_hints (read own only)
CREATE POLICY "User reads own hints"     ON public.ai_hints FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Auth can request hints"   ON public.ai_hints FOR INSERT WITH CHECK (auth.uid() = user_id);

-- daily_challenges
CREATE POLICY "Public read challenges"   ON public.daily_challenges FOR SELECT USING (true);

-- challenge_attempts
CREATE POLICY "User reads own attempts"  ON public.challenge_attempts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Auth can attempt"         ON public.challenge_attempts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "User updates own attempt" ON public.challenge_attempts FOR UPDATE USING (auth.uid() = user_id);

-- badges
CREATE POLICY "Public read badges"       ON public.badges FOR SELECT USING (true);

-- user_badges
CREATE POLICY "Public read user_badges"  ON public.user_badges FOR SELECT USING (true);

-- notifications
CREATE POLICY "User reads own notifs"    ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "User updates own notifs"  ON public.notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "User deletes own notifs"  ON public.notifications FOR DELETE USING (auth.uid() = user_id);


-- ─── DONE ─────────────────────────────────────────────────────
-- Schema setup complete. Tables created: 13
-- Triggers: on_auth_user_created, set_*_updated_at (x3)
-- Indexes: 13
-- RLS policies: enabled on all tables
-- Seed data: tags (14 rows), badges (8 rows)
```

> **To reset and start fresh** (drops everything — be careful):
> ```sql
> DROP TABLE IF EXISTS public.notifications      CASCADE;
> DROP TABLE IF EXISTS public.user_badges        CASCADE;
> DROP TABLE IF EXISTS public.badges             CASCADE;
> DROP TABLE IF EXISTS public.challenge_attempts CASCADE;
> DROP TABLE IF EXISTS public.daily_challenges   CASCADE;
> DROP TABLE IF EXISTS public.ai_hints           CASCADE;
> DROP TABLE IF EXISTS public.point_transactions CASCADE;
> DROP TABLE IF EXISTS public.votes              CASCADE;
> DROP TABLE IF EXISTS public.question_tags      CASCADE;
> DROP TABLE IF EXISTS public.answers            CASCADE;
> DROP TABLE IF EXISTS public.questions          CASCADE;
> DROP TABLE IF EXISTS public.tags               CASCADE;
> DROP TABLE IF EXISTS public.users              CASCADE;
> DROP FUNCTION IF EXISTS public.handle_new_user CASCADE;
> DROP FUNCTION IF EXISTS public.set_updated_at  CASCADE;
> ```

---

## 11. dbdiagram.io Code

Paste this at [dbdiagram.io](https://dbdiagram.io/d) to visualize the schema:

```
// QuestBoard — Supabase PostgreSQL Schema
// https://dbdiagram.io

Table users {
  id          uuid        [pk, note: "Matches auth.users.id"]
  username    varchar(50) [unique, not null]
  avatar_url  text
  bio         text
  points      int         [not null, default: 100]
  streak_days int         [not null, default: 0]
  last_active timestamp
  created_at  timestamp   [not null, default: `now()`]
  updated_at  timestamp   [not null, default: `now()`]

  note: "No password_hash — credentials owned by Supabase Auth"
}

Table questions {
  id                 uuid      [pk, default: `gen_random_uuid()`]
  author_id          uuid      [not null, ref: > users.id]
  title              text      [not null]
  body               text      [not null]
  image_url          text
  bounty_points      int       [not null, default: 0]
  is_solved          bool      [not null, default: false]
  accepted_answer_id uuid
  view_count         int       [not null, default: 0]
  difficulty         varchar(10) [note: "easy | medium | hard"]
  created_at         timestamp [not null, default: `now()`]
  updated_at         timestamp [not null, default: `now()`]
}

Table answers {
  id          uuid      [pk, default: `gen_random_uuid()`]
  question_id uuid      [not null, ref: > questions.id]
  author_id   uuid      [not null, ref: > users.id]
  body        text      [not null]
  is_accepted bool      [not null, default: false]
  created_at  timestamp [not null, default: `now()`]
  updated_at  timestamp [not null, default: `now()`]
}

Ref: questions.accepted_answer_id > answers.id

Table tags {
  id   uuid        [pk, default: `gen_random_uuid()`]
  name varchar(50) [unique, not null]
}

Table question_tags {
  question_id uuid [not null, ref: > questions.id]
  tag_id      uuid [not null, ref: > tags.id]

  indexes {
    (question_id, tag_id) [pk]
  }
}

Table votes {
  id          uuid      [pk, default: `gen_random_uuid()`]
  user_id     uuid      [not null, ref: > users.id]
  target_type varchar(10) [not null, note: "question | answer"]
  target_id   uuid      [not null]
  value       smallint  [not null, note: "+1 or -1"]
  created_at  timestamp [not null, default: `now()`]

  indexes {
    (user_id, target_type, target_id) [unique]
  }

  note: "Polymorphic — covers both question and answer votes"
}

Table point_transactions {
  id           uuid      [pk, default: `gen_random_uuid()`]
  user_id      uuid      [not null, ref: > users.id]
  amount       int       [not null, note: "Positive = earned, negative = spent"]
  reason       varchar(50) [not null, note: "signup_bonus | bounty_posted | bounty_awarded | hint_used | vote_received | vote_lost | challenge_solved | daily_bonus"]
  reference_id uuid
  created_at   timestamp [not null, default: `now()`]

  note: "Immutable audit log — never update or delete rows"
}

Table ai_hints {
  id          uuid      [pk, default: `gen_random_uuid()`]
  question_id uuid      [not null, ref: > questions.id]
  user_id     uuid      [not null, ref: > users.id]
  hint_text   text      [not null]
  points_cost int       [not null, default: 5]
  created_at  timestamp [not null, default: `now()`]
}

Table daily_challenges {
  id             uuid      [pk, default: `gen_random_uuid()`]
  codeforces_id  varchar(20)
  title          text      [not null]
  body           text      [not null]
  difficulty     varchar(10) [note: "easy | medium | hard"]
  source_url     text
  bonus_points   int       [not null, default: 50]
  challenge_date date      [unique, not null]
  created_at     timestamp [not null, default: `now()`]
}

Table challenge_attempts {
  id           uuid      [pk, default: `gen_random_uuid()`]
  challenge_id uuid      [not null, ref: > daily_challenges.id]
  user_id      uuid      [not null, ref: > users.id]
  is_solved    bool      [not null, default: false]
  solved_at    timestamp
  created_at   timestamp [not null, default: `now()`]

  indexes {
    (challenge_id, user_id) [unique]
  }
}

Table badges {
  id          uuid        [pk, default: `gen_random_uuid()`]
  name        varchar(50) [unique, not null]
  description text        [not null]
  icon_url    text
}

Table user_badges {
  user_id    uuid      [not null, ref: > users.id]
  badge_id   uuid      [not null, ref: > badges.id]
  awarded_at timestamp [not null, default: `now()`]

  indexes {
    (user_id, badge_id) [pk]
  }
}

Table notifications {
  id           uuid      [pk, default: `gen_random_uuid()`]
  user_id      uuid      [not null, ref: > users.id]
  type         varchar(30) [not null, note: "answer_received | answer_accepted | bounty_awarded | vote_received | badge_earned"]
  message      text      [not null]
  reference_id uuid
  is_read      bool      [not null, default: false]
  created_at   timestamp [not null, default: `now()`]
}
```