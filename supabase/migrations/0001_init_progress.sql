-- StackSpeak — cross-platform progress sync (Pro feature)
-- One compact row per user; the app reads/writes a single platform-neutral
-- ProgressSnapshot JSON blob. Row Level Security restricts every user to their
-- own row, which is what makes shipping the anon key in the client safe.
--
-- Apply: Supabase dashboard → SQL Editor → paste & run, or `supabase db push`.

create table if not exists public.progress (
    user_id        uuid primary key references auth.users (id) on delete cascade,
    data           jsonb       not null,            -- the ProgressSnapshot JSON
    schema_version integer     not null default 1,  -- bump when the snapshot shape changes
    updated_at     timestamptz not null default now()
);

-- Keep updated_at honest on every write.
create or replace function public.set_progress_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists progress_set_updated_at on public.progress;
create trigger progress_set_updated_at
    before insert or update on public.progress
    for each row execute function public.set_progress_updated_at();

-- Row Level Security: a user may only touch their own row.
alter table public.progress enable row level security;

drop policy if exists "progress_select_own" on public.progress;
create policy "progress_select_own" on public.progress
    for select using (auth.uid() = user_id);

drop policy if exists "progress_insert_own" on public.progress;
create policy "progress_insert_own" on public.progress
    for insert with check (auth.uid() = user_id);

drop policy if exists "progress_update_own" on public.progress;
create policy "progress_update_own" on public.progress
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "progress_delete_own" on public.progress;
create policy "progress_delete_own" on public.progress
    for delete using (auth.uid() = user_id);
