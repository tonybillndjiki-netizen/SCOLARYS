
create or replace function private.scolaria_role_key(target_org uuid)
returns text language sql stable security definer set search_path = ''
as $$
  select r.key
  from public.scolaria_organization_members m
  join public.scolaria_roles r on r.id = m.role_id
  where m.organization_id = target_org
    and m.user_id = (select auth.uid())
    and m.status = 'active'
  limit 1;
$$;

create or replace function private.scolaria_user_in_class(target_class uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_class_memberships cm
    where cm.class_id = target_class
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
  );
$$;

revoke all on function private.scolaria_role_key(uuid) from public;
revoke all on function private.scolaria_user_in_class(uuid) from public;
grant execute on function private.scolaria_role_key(uuid) to authenticated;
grant execute on function private.scolaria_user_in_class(uuid) to authenticated;

create table if not exists public.scolaria_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  program_id uuid references public.scolaria_programs(id) on delete cascade,
  subject_id uuid references public.scolaria_subjects(id) on delete cascade,
  code text,
  name text not null,
  description text,
  framework text,
  ordinal integer not null default 1,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create table if not exists public.scolaria_courses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  class_id uuid not null references public.scolaria_classes(id) on delete cascade,
  subject_id uuid not null references public.scolaria_subjects(id) on delete restrict,
  academic_period_id uuid references public.scolaria_academic_periods(id) on delete set null,
  teacher_id uuid references auth.users(id) on delete set null,
  title text not null,
  description text,
  objectives text,
  estimated_hours numeric(7,2) check (estimated_hours is null or estimated_hours >= 0),
  status text not null default 'draft' check (status in ('draft','scheduled','published','archived')),
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function private.scolaria_can_manage_course(target_course uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_courses c
    where c.id = target_course
      and (
        (
          private.scolaria_has_permission(c.organization_id, 'courses.manage')
          and coalesce(private.scolaria_role_key(c.organization_id), '') <> 'teacher'
        )
        or c.teacher_id = (select auth.uid())
        or c.created_by = (select auth.uid())
      )
  );
$$;

create or replace function private.scolaria_can_view_course(target_course uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select private.scolaria_can_manage_course(target_course)
  or exists (
    select 1
    from public.scolaria_courses c
    where c.id = target_course
      and c.status = 'published'
      and private.scolaria_user_in_class(c.class_id)
  );
$$;

revoke all on function private.scolaria_can_manage_course(uuid) from public;
revoke all on function private.scolaria_can_view_course(uuid) from public;
grant execute on function private.scolaria_can_manage_course(uuid) to authenticated;
grant execute on function private.scolaria_can_view_course(uuid) to authenticated;

create table if not exists public.scolaria_course_competencies (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  course_id uuid not null references public.scolaria_courses(id) on delete cascade,
  competency_id uuid not null references public.scolaria_competencies(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, competency_id)
);

create table if not exists public.scolaria_chapters (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  course_id uuid not null references public.scolaria_courses(id) on delete cascade,
  title text not null,
  description text,
  objectives text,
  ordinal integer not null default 1 check (ordinal > 0),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes >= 0),
  structured_zones_enabled boolean not null default true,
  status text not null default 'draft' check (status in ('draft','scheduled','published','archived')),
  scheduled_at timestamptz,
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, ordinal)
);

create table if not exists public.scolaria_chapter_blocks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  chapter_id uuid not null references public.scolaria_chapters(id) on delete cascade,
  zone text not null default 'during' check (zone in ('before','during','after','general')),
  block_type text not null check (
    block_type in ('heading','text','image','video','pdf','document','link','file','table','callout','quote','resource','exercise','question','activity','assignment','quiz')
  ),
  ordinal integer not null default 1 check (ordinal > 0),
  content jsonb not null default '{}'::jsonb,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chapter_id, zone, ordinal)
);

create table if not exists public.scolaria_files (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete set null,
  bucket_id text not null default 'scolaria-resources',
  storage_path text not null,
  original_name text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  checksum text,
  visibility text not null default 'organization' check (visibility in ('private','organization','class','course')),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bucket_id, storage_path)
);

create table if not exists public.scolaria_resources (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  course_id uuid not null references public.scolaria_courses(id) on delete cascade,
  chapter_id uuid references public.scolaria_chapters(id) on delete cascade,
  file_id uuid references public.scolaria_files(id) on delete set null,
  title text not null,
  description text,
  resource_type text not null check (resource_type in ('file','pdf','document','image','video','link','drive','other')),
  url text,
  zone text not null default 'general' check (zone in ('before','during','after','general')),
  ordinal integer not null default 1,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_lessons (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  course_id uuid not null references public.scolaria_courses(id) on delete cascade,
  chapter_id uuid references public.scolaria_chapters(id) on delete set null,
  class_id uuid not null references public.scolaria_classes(id) on delete cascade,
  teacher_id uuid references auth.users(id) on delete set null,
  title text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  room text,
  meeting_url text,
  delivery_mode text not null default 'onsite' check (delivery_mode in ('onsite','remote','hybrid')),
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index if not exists scolaria_competencies_org_subject_idx on public.scolaria_competencies(organization_id, subject_id);
create index if not exists scolaria_courses_org_class_idx on public.scolaria_courses(organization_id, class_id);
create index if not exists scolaria_courses_teacher_idx on public.scolaria_courses(teacher_id);
create index if not exists scolaria_courses_subject_idx on public.scolaria_courses(subject_id);
create index if not exists scolaria_courses_period_idx on public.scolaria_courses(academic_period_id);
create index if not exists scolaria_course_comp_course_idx on public.scolaria_course_competencies(course_id);
create index if not exists scolaria_course_comp_comp_idx on public.scolaria_course_competencies(competency_id);
create index if not exists scolaria_chapters_course_idx on public.scolaria_chapters(course_id, ordinal);
create index if not exists scolaria_blocks_chapter_idx on public.scolaria_chapter_blocks(chapter_id, zone, ordinal);
create index if not exists scolaria_files_org_idx on public.scolaria_files(organization_id, created_at desc);
create index if not exists scolaria_resources_course_idx on public.scolaria_resources(course_id, chapter_id, ordinal);
create index if not exists scolaria_lessons_class_start_idx on public.scolaria_lessons(class_id, starts_at);
create index if not exists scolaria_lessons_course_idx on public.scolaria_lessons(course_id, starts_at);

do $$
declare t text;
begin
  foreach t in array array[
    'scolaria_competencies','scolaria_courses','scolaria_course_competencies',
    'scolaria_chapters','scolaria_chapter_blocks','scolaria_files','scolaria_resources','scolaria_lessons'
  ] loop
    execute format('drop trigger if exists %I on public.%I', t || '_updated_at', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.scolaria_set_updated_at()', t || '_updated_at', t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array['scolaria_courses','scolaria_chapters','scolaria_chapter_blocks','scolaria_files','scolaria_resources'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_audit', t);
    execute format('create trigger %I after insert or update or delete on public.%I for each row execute function private.scolaria_audit_change()', t || '_audit', t);
  end loop;
end $$;
