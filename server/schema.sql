-- QuestBoard schema — the tables that exist today.
--
-- Run this once in the Supabase SQL editor on a new project. It is idempotent,
-- so re-running it is safe. Keep it in sync with app/models/ and
-- docs/data-model.md; the planned tables (answers, votes, point_transactions…)
-- are documented there and are NOT created here yet.

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
    last_active         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

-- --------------------------------------------------------------- quests -----
-- Mirrors app/models/quest.py. The bounty columns are not here yet — see
-- docs/data-model.md and the M2 milestone in TASKS.md.
create table if not exists public.quests (
    id          uuid primary key     default gen_random_uuid(),
    created_at  timestamptz not null default now(),
    title       text        not null,
    description text,
    tags        text[],
    user_id     uuid        not null references public.users (id) on delete cascade
);

create index if not exists quests_user_id_idx on public.quests (user_id);
create index if not exists quests_created_at_idx on public.quests (created_at desc);

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
alter table public.quests enable row level security;

drop policy if exists "Profiles are readable by everyone" on public.users;
create policy "Profiles are readable by everyone"
    on public.users for select
    using (true);

drop policy if exists "Users can update their own profile" on public.users;
create policy "Users can update their own profile"
    on public.users for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

drop policy if exists "Quests are readable by everyone" on public.quests;
create policy "Quests are readable by everyone"
    on public.quests for select
    using (true);

drop policy if exists "Authors can write their own quests" on public.quests;
create policy "Authors can write their own quests"
    on public.quests for all
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
