alter table public.study_conversations
  add column if not exists is_archived boolean not null default false,
  add column if not exists archived_at timestamptz;

create index if not exists study_conversations_user_archive_updated_idx
  on public.study_conversations (user_id, is_archived, updated_at desc);

alter table public.study_artifacts
  add column if not exists revision_group_id uuid,
  add column if not exists revision_number integer not null default 1,
  add column if not exists revised_from_artifact_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'study_artifacts_revision_number_check'
      and conrelid = 'public.study_artifacts'::regclass
  ) then
    alter table public.study_artifacts
      add constraint study_artifacts_revision_number_check
      check (revision_number >= 1);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'study_artifacts_revised_from_fk'
      and conrelid = 'public.study_artifacts'::regclass
  ) then
    alter table public.study_artifacts
      add constraint study_artifacts_revised_from_fk
      foreign key (revised_from_artifact_id)
      references public.study_artifacts(id)
      on delete set null;
  end if;
end;
$$;

create index if not exists study_artifacts_revision_group_idx
  on public.study_artifacts (user_id, revision_group_id, revision_number desc);

grant update (payload, updated_at) on table public.user_state to authenticated;

comment on column public.study_conversations.is_archived is
  'Whether the user moved this conversation out of the active list.';
comment on column public.study_artifacts.revision_group_id is
  'Stable family identifier shared by all revisions of one generated artifact.';
