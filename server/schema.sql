-- QuestBoard schema — the tables that exist today.
--
-- Run this once in the Supabase SQL editor on a new project. It is idempotent,
-- so re-running it is safe. Every table the API touches is here — keep it in
-- sync with app/models/ and docs/data-model.md.

-- ---------------------------------------------------------------- users -----
-- Mirrors app/models/user.py. Shares its primary key with auth.users; the email
-- lives there and is deliberately not duplicated.
create table if not exists public.users (
    id                  uuid primary key references auth.users (id) on delete cascade,
    username            text        not null unique,
    first_name          text        not null default '',
    last_name           text        not null default '',
    phone_number        text,
    image_url           text        not null default '',
    codeforces_handle   text        not null default '',
    codeforces_verified boolean     not null default false,
    points              integer     not null default 100,
    streak_days         integer     not null default 0,
    is_admin            boolean     not null default false,
    is_suspended        boolean     not null default false,
    last_active         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- `create table if not exists` skips an existing table entirely, so columns
-- added after the first run need their own line.
alter table public.users add column if not exists is_suspended boolean not null default false;

-- ------------------------------------------------------------ questions -----
-- Mirrors app/models/question.py. Named `questions`; the product calls it a
-- quest (docs/decisions.md D1).
--
-- questions.accepted_answer_id and answers.question_id reference each other, so
-- the FK is added after both tables exist.
create table if not exists public.questions (
    id                 uuid primary key     default gen_random_uuid(),
    author_id          uuid        not null references public.users (id) on delete cascade,
    title              text        not null,
    body               text        not null,
    image_url          text,
    bounty_points      integer     not null default 0,
    is_solved          boolean     not null default false,
    accepted_answer_id uuid,
    view_count         integer     not null default 0,
    difficulty         varchar(10),
    created_at         timestamptz not null default now(),
    updated_at         timestamptz not null default now()
);

create table if not exists public.answers (
    id              uuid primary key     default gen_random_uuid(),
    question_id     uuid        not null references public.questions (id) on delete cascade,
    author_id       uuid        not null references public.users (id) on delete cascade,
    body            text        not null,
    image_url       text,
    -- An answer may carry a code submission: the source itself, the language it
    -- was written in, and optionally a file uploaded to the `submissions`
    -- bucket. All three are null for a plain-prose answer.
    code_body       text,
    code_language   varchar(20),
    attachment_url  text,
    attachment_name text,
    is_accepted     boolean     not null default false,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- Added after the first release; `create table if not exists` would skip them.
alter table public.answers add column if not exists code_body       text;
alter table public.answers add column if not exists code_language   varchar(20);
alter table public.answers add column if not exists attachment_url  text;
alter table public.answers add column if not exists attachment_name text;

alter table public.questions
    drop constraint if exists questions_accepted_answer_id_fkey;
alter table public.questions
    add constraint questions_accepted_answer_id_fkey
    foreign key (accepted_answer_id) references public.answers (id);

-- Polymorphic target_id has no FK by design: it points at a question or an
-- answer. The unique constraint is what makes vote toggling race-safe.
create table if not exists public.votes (
    id          uuid primary key     default gen_random_uuid(),
    user_id     uuid        not null references public.users (id) on delete cascade,
    target_type varchar(10) not null check (target_type in ('question', 'answer')),
    target_id   uuid        not null,
    value       smallint    not null check (value in (1, -1)),
    created_at  timestamptz not null default now(),
    unique (user_id, target_type, target_id)
);

-- The economy ledger. Append-only — users.points is a cache of sum(amount) and
-- the two are only ever written together, inside one transaction.
create table if not exists public.point_transactions (
    id           uuid primary key     default gen_random_uuid(),
    user_id      uuid        not null references public.users (id) on delete cascade,
    amount       integer     not null,
    reason       varchar(50) not null,
    reference_id uuid,
    created_at   timestamptz not null default now()
);

-- The list must match PointReason in app/models/point_transaction.py exactly.
-- It drifted once already: the constraint still said `hint_used` and had never
-- heard of `bounty_refunded`, so deleting a quest with a bounty and buying an
-- AI hint both died on an insert. Dropped and recreated rather than added, so
-- re-running this file repairs an out-of-date constraint instead of skipping it.
alter table public.point_transactions
    drop constraint if exists point_transactions_reason_check;
alter table public.point_transactions
    add constraint point_transactions_reason_check check (reason in (
        'ai_hint', 'bounty_awarded', 'bounty_posted', 'bounty_refunded',
        'challenge_solved', 'daily_bonus', 'signup_bonus',
        'vote_lost', 'vote_received'
    ));

-- Backfill: accounts created before the signup bonus was ledgered.
--
-- `users.points` defaults to 100, and for a long time the API let it, so every
-- account started with 100 points that no transaction explained and the profile
-- showed a balance with an empty history behind it. `create_user` now pays that
-- bonus through PointService; this reconciles the accounts that predate it.
--
-- The amount is the *actual* gap between the cached balance and the ledger, not
-- a hardcoded 100, so it lands exactly whatever the drift turned out to be.
-- Idempotent: an account that already has a signup_bonus row is skipped.
insert into public.point_transactions (user_id, amount, reason, reference_id)
select u.id,
       u.points - coalesce((
           select sum(t.amount) from public.point_transactions t
           where t.user_id = u.id
       ), 0),
       'signup_bonus',
       u.id
from public.users u
where not exists (
          select 1 from public.point_transactions t
          where t.user_id = u.id and t.reason = 'signup_bonus'
      )
  and u.points - coalesce((
          select sum(t.amount) from public.point_transactions t
          where t.user_id = u.id
      ), 0) <> 0;

create table if not exists public.tags (
    id   uuid primary key default gen_random_uuid(),
    name varchar(50) not null unique
);

create table if not exists public.question_tags (
    question_id uuid not null references public.questions (id) on delete cascade,
    tag_id      uuid not null references public.tags (id) on delete cascade,
    primary key (question_id, tag_id)
);

-- ------------------------------------------------- gamification (M3) -------
create table if not exists public.notifications (
    id           uuid primary key     default gen_random_uuid(),
    user_id      uuid        not null references public.users (id) on delete cascade,
    type         varchar(30) not null
                 check (type in ('answer_received', 'answer_accepted',
                                 'bounty_awarded', 'vote_received',
                                 'badge_earned')),
    message      text        not null,
    -- The quest, answer or badge this points at. Polymorphic, so no FK.
    reference_id uuid,
    is_read      boolean     not null default false,
    created_at   timestamp   not null default now()
);

create table if not exists public.badges (
    id          uuid primary key default gen_random_uuid(),
    name        varchar(50) not null unique,
    description text        not null,
    icon_url    text
);

-- The composite primary key is what makes awarding idempotent: a second
-- award of the same badge conflicts instead of duplicating.
create table if not exists public.user_badges (
    user_id    uuid      not null references public.users (id) on delete cascade,
    badge_id   uuid      not null references public.badges (id) on delete cascade,
    awarded_at timestamp not null default now(),
    primary key (user_id, badge_id)
);

-- ---------------------------------------- AI hints & daily challenge (M4) ---
-- One row per hint the model actually returned. Doubles as the rate-limit
-- ledger (the hourly cap is a COUNT over created_at) and as the evidence for
-- the ai_skeptic badge, so a failed model call must leave no row behind.
create table if not exists public.ai_hints (
    id          uuid primary key  default gen_random_uuid(),
    question_id uuid    not null  references public.questions (id) on delete cascade,
    user_id     uuid    not null  references public.users (id) on delete cascade,
    hint_text   text    not null,
    points_cost integer not null  default 5,
    created_at  timestamp not null default now()
);

-- One Codeforces problem per calendar day (UTC). challenge_date is unique,
-- which is what makes "today's challenge" a lookup rather than a decision:
-- the first request of the day creates the row, everyone after reads it.
create table if not exists public.daily_challenges (
    id             uuid primary key  default gen_random_uuid(),
    codeforces_id  text,                       -- "1873/D": contest id + index
    title          text    not null,
    body           text    not null,
    cf_rating      integer,
    difficulty     varchar(10) check (difficulty in ('easy', 'medium', 'hard')),
    source_url     text,
    bonus_points   integer not null default 50,
    challenge_date date    not null unique,
    created_at     timestamptz not null default now()
);

-- The scraped problem statement, cached forever. Codeforces has no statement
-- API and the problem page is behind Cloudflare, so a fetch can fail for
-- reasons unrelated to us; statements never change, so one that succeeds is
-- kept and never fetched again (decisions.md D45).
alter table public.daily_challenges add column if not exists statement            jsonb;
alter table public.daily_challenges add column if not exists statement_fetched_at timestamptz;

create table if not exists public.challenge_attempts (
    id              uuid primary key  default gen_random_uuid(),
    challenge_id    uuid    not null  references public.daily_challenges (id) on delete cascade,
    user_id         uuid    not null  references public.users (id) on delete cascade,
    is_solved       boolean not null  default false,
    -- What this solve actually paid. The award decays with the challenge's age,
    -- so bonus_points alone cannot tell you what a late solver received; this
    -- column is what keeps the leaderboard and the ledger telling one story.
    awarded_points  integer not null  default 0,
    -- The solution the user submitted through the app, if any. Solving is still
    -- verified against Codeforces — this is the record of the work, not proof.
    code_body       text,
    code_language   varchar(20),
    attachment_url  text,
    attachment_name text,
    solved_at       timestamp,
    created_at      timestamp not null default now(),
    unique (challenge_id, user_id)
);

alter table public.challenge_attempts add column if not exists awarded_points  integer not null default 0;
alter table public.challenge_attempts add column if not exists code_body       text;
alter table public.challenge_attempts add column if not exists code_language   varchar(20);
alter table public.challenge_attempts add column if not exists attachment_url  text;
alter table public.challenge_attempts add column if not exists attachment_name text;

insert into public.badges (name, description) values
    ('first_answer',  'Submitted your first answer'),
    ('first_bounty',  'Won your first bounty'),
    ('bounty_hunter', 'Won 10 bounties total'),
    ('streak_5',      'Maintained a 5-day activity streak'),
    ('streak_30',     'Maintained a 30-day activity streak'),
    ('top_helper',    'Ranked in the top 10 on the weekly leaderboard'),
    ('challenger',    'Solved 7 daily challenges'),
    ('ai_skeptic',    'Solved a question without using any AI hints')
on conflict (name) do nothing;

insert into public.tags (name) values
    ('dsa'), ('math'), ('physics'), ('chemistry'), ('calculus'),
    ('linear-algebra'), ('graph-theory'), ('dynamic-programming'),
    ('number-theory'), ('geometry'), ('data-structures'), ('algorithms'),
    ('probability'), ('statistics')
on conflict (name) do nothing;

create index if not exists questions_author_idx on public.questions (author_id);
create index if not exists questions_created_at_idx on public.questions (created_at desc);
create index if not exists answers_question_idx on public.answers (question_id);
create index if not exists votes_target_idx on public.votes (target_type, target_id);
create index if not exists point_tx_user_idx on public.point_transactions (user_id, created_at desc);
create index if not exists idx_hints_user_question on public.ai_hints (user_id, question_id, created_at desc);
create index if not exists idx_challenges_date on public.daily_challenges (challenge_date desc);
create index if not exists idx_attempts_user on public.challenge_attempts (user_id, is_solved);

-- GET /api/questions?search= matches with ILIKE '%term%', which no B-tree can
-- serve. A GIN trigram index can, so search stays a index scan as the board
-- grows instead of degrading into a sequential scan of every quest.
create extension if not exists pg_trgm;
create index if not exists idx_questions_trgm_title on public.questions using gin (title gin_trgm_ops);
create index if not exists idx_questions_trgm_body on public.questions using gin (body gin_trgm_ops);

-- ------------------------------------------------------- updated_at ---------
-- The ORM sets updated_at on its own writes; this keeps it honest for rows
-- edited directly in the Supabase table editor.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
    before update on public.users
    for each row
    execute function public.set_updated_at();

-- ------------------------------------------------------------------ RLS -----
-- The FastAPI server connects as the postgres role and bypasses RLS entirely;
-- authorization is enforced in the service layer. These policies only matter
-- if the Flutter client ever reads these tables through supabase-js directly.
alter table public.users enable row level security;
alter table public.questions enable row level security;
alter table public.answers enable row level security;
alter table public.votes enable row level security;
alter table public.point_transactions enable row level security;

drop policy if exists "Profiles are readable by everyone" on public.users;
create policy "Profiles are readable by everyone"
    on public.users for select
    using (true);

drop policy if exists "Users can update their own profile" on public.users;
create policy "Users can update their own profile"
    on public.users for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

drop policy if exists "Quests are readable by everyone" on public.questions;
create policy "Quests are readable by everyone"
    on public.questions for select
    using (true);

drop policy if exists "Authors can write their own quests" on public.questions;
create policy "Authors can write their own quests"
    on public.questions for all
    using (auth.uid() = author_id)
    with check (auth.uid() = author_id);
