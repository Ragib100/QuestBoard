# QuestBoard Database Schema

## Quests Table

```sql
CREATE TABLE quests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    title text NOT NULL,
    description text,
    tags text[],
    user_id uuid NOT NULL,
    CONSTRAINT quests_pkey PRIMARY KEY (id),
    CONSTRAINT quests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE quests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to own quests" ON public.quests FOR
ALL USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow read access to all quests" ON public.quests FOR
SELECT USING (true);
```
