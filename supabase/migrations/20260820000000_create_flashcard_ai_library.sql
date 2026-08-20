create table if not exists public.study_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'New study session',
  topic text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.study_conversations enable row level security;

revoke all on table public.study_conversations from anon, authenticated;
grant select, insert, update, delete on table public.study_conversations to authenticated;

drop policy if exists "Users can manage own study conversations"
  on public.study_conversations;
create policy "Users can manage own study conversations"
  on public.study_conversations
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists study_conversations_user_updated_at_idx
  on public.study_conversations (user_id, updated_at desc);

create table if not exists public.study_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.study_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content text not null,
  actions jsonb not null default '[]'::jsonb,
  sequence_no integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.study_messages enable row level security;

revoke all on table public.study_messages from anon, authenticated;
grant select, insert, update, delete on table public.study_messages to authenticated;

drop policy if exists "Users can manage own study messages"
  on public.study_messages;
create policy "Users can manage own study messages"
  on public.study_messages
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists study_messages_conversation_sequence_idx
  on public.study_messages (conversation_id, sequence_no, created_at);

create table if not exists public.study_artifacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid references public.study_conversations(id) on delete set null,
  kind text not null check (kind in ('flashcards', 'quiz', 'topic_map', 'study_plan')),
  title text not null,
  topic text not null,
  summary text not null default '',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.study_artifacts enable row level security;

revoke all on table public.study_artifacts from anon, authenticated;
grant select, insert, update, delete on table public.study_artifacts to authenticated;

drop policy if exists "Users can manage own study artifacts"
  on public.study_artifacts;
create policy "Users can manage own study artifacts"
  on public.study_artifacts
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists study_artifacts_user_created_at_idx
  on public.study_artifacts (user_id, created_at desc);

create or replace function public.set_study_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists study_conversations_set_updated_at on public.study_conversations;
create trigger study_conversations_set_updated_at
  before update on public.study_conversations
  for each row
  execute function public.set_study_updated_at();

drop trigger if exists study_artifacts_set_updated_at on public.study_artifacts;
create trigger study_artifacts_set_updated_at
  before update on public.study_artifacts
  for each row
  execute function public.set_study_updated_at();

revoke execute on function public.set_study_updated_at()
  from public, anon, authenticated;

comment on table public.study_artifacts is
  'User-owned generated study material. Keep source-grounded content and avoid storing secrets.';
