-- SCOLARYS Phase 3: activate LMS RLS and expose transactional course/studio RPCs.

alter table public.scolaria_competencies enable row level security;
alter table public.scolaria_courses enable row level security;
alter table public.scolaria_course_competencies enable row level security;
alter table public.scolaria_chapters enable row level security;
alter table public.scolaria_chapter_blocks enable row level security;
alter table public.scolaria_files enable row level security;
alter table public.scolaria_resources enable row level security;
alter table public.scolaria_lessons enable row level security;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

revoke all on table
  public.scolaria_competencies,
  public.scolaria_courses,
  public.scolaria_course_competencies,
  public.scolaria_chapters,
  public.scolaria_chapter_blocks,
  public.scolaria_files,
  public.scolaria_resources,
  public.scolaria_lessons
from anon, authenticated;

grant select, insert, update, delete on table
  public.scolaria_competencies,
  public.scolaria_courses,
  public.scolaria_course_competencies,
  public.scolaria_chapters,
  public.scolaria_chapter_blocks,
  public.scolaria_files,
  public.scolaria_resources,
  public.scolaria_lessons
to authenticated;

revoke delete on table public.scolaria_chapters from authenticated;
drop policy if exists scolaria_chapters_delete on public.scolaria_chapters;
drop policy if exists scolaria_chapters_delete_via_rpc_only on public.scolaria_chapters;
create policy scolaria_chapters_delete_via_rpc_only
on public.scolaria_chapters for delete to authenticated
using (false);

-- Fail before taking schema locks if historical LMS rows violate tenant or
-- parent consistency. The production LMS tables were verified empty before
-- this migration was authored, but this keeps other environments diagnosable.
do $$
begin
  if exists (
    select 1 from public.scolaria_competencies child
    join public.scolaria_programs parent on parent.id = child.program_id
    where child.program_id is not null and parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_COMPETENCY_PROGRAM'; end if;

  if exists (
    select 1 from public.scolaria_competencies child
    join public.scolaria_subjects parent on parent.id = child.subject_id
    where child.subject_id is not null and parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_COMPETENCY_SUBJECT'; end if;

  if exists (
    select 1 from public.scolaria_courses child
    join public.scolaria_classes parent on parent.id = child.class_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_COURSE_CLASS'; end if;

  if exists (
    select 1 from public.scolaria_courses child
    join public.scolaria_subjects parent on parent.id = child.subject_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_COURSE_SUBJECT'; end if;

  if exists (
    select 1 from public.scolaria_courses child
    join public.scolaria_academic_periods parent on parent.id = child.academic_period_id
    where child.academic_period_id is not null and parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_COURSE_PERIOD'; end if;

  if exists (
    select 1 from public.scolaria_course_competencies child
    join public.scolaria_courses parent on parent.id = child.course_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_LINK_COURSE'; end if;

  if exists (
    select 1 from public.scolaria_course_competencies child
    join public.scolaria_competencies parent on parent.id = child.competency_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_LINK_COMPETENCY'; end if;

  if exists (
    select 1 from public.scolaria_chapters child
    join public.scolaria_courses parent on parent.id = child.course_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_CHAPTER_COURSE'; end if;

  if exists (
    select 1 from public.scolaria_chapter_blocks child
    join public.scolaria_chapters parent on parent.id = child.chapter_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_BLOCK_CHAPTER'; end if;

  if exists (
    select 1 from public.scolaria_resources child
    join public.scolaria_courses parent on parent.id = child.course_id
    where parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_RESOURCE_COURSE'; end if;

  if exists (
    select 1 from public.scolaria_resources child
    join public.scolaria_chapters parent on parent.id = child.chapter_id
    where child.chapter_id is not null
      and (parent.organization_id <> child.organization_id or parent.course_id <> child.course_id)
  ) then raise exception 'LMS_TENANT_PREFLIGHT_RESOURCE_CHAPTER'; end if;

  if exists (
    select 1 from public.scolaria_resources child
    join public.scolaria_files parent on parent.id = child.file_id
    where child.file_id is not null and parent.organization_id <> child.organization_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_RESOURCE_FILE'; end if;

  if exists (
    select 1 from public.scolaria_lessons child
    join public.scolaria_courses parent on parent.id = child.course_id
    where parent.organization_id <> child.organization_id or parent.class_id <> child.class_id
  ) then raise exception 'LMS_TENANT_PREFLIGHT_LESSON_COURSE'; end if;

  if exists (
    select 1 from public.scolaria_lessons child
    join public.scolaria_chapters parent on parent.id = child.chapter_id
    where child.chapter_id is not null
      and (parent.organization_id <> child.organization_id or parent.course_id <> child.course_id)
  ) then raise exception 'LMS_TENANT_PREFLIGHT_LESSON_CHAPTER'; end if;
end
$$;

-- Composite keys make tenant consistency a database invariant, including for
-- trusted server jobs that bypass RLS.
create unique index if not exists scolaria_classes_id_org_uidx
  on public.scolaria_classes(id, organization_id);
create unique index if not exists scolaria_subjects_id_org_uidx
  on public.scolaria_subjects(id, organization_id);
create unique index if not exists scolaria_periods_id_org_uidx
  on public.scolaria_academic_periods(id, organization_id);
create unique index if not exists scolaria_programs_id_org_uidx
  on public.scolaria_programs(id, organization_id);
create unique index if not exists scolaria_competencies_id_org_uidx
  on public.scolaria_competencies(id, organization_id);
create unique index if not exists scolaria_courses_id_org_uidx
  on public.scolaria_courses(id, organization_id);
create unique index if not exists scolaria_courses_id_class_org_uidx
  on public.scolaria_courses(id, class_id, organization_id);
create unique index if not exists scolaria_chapters_id_org_uidx
  on public.scolaria_chapters(id, organization_id);
create unique index if not exists scolaria_chapters_id_course_org_uidx
  on public.scolaria_chapters(id, course_id, organization_id);
create unique index if not exists scolaria_files_id_org_uidx
  on public.scolaria_files(id, organization_id);
create index if not exists scolaria_courses_org_status_updated_idx
  on public.scolaria_courses(organization_id, status, updated_at desc, id);
create index if not exists scolaria_courses_org_subject_updated_idx
  on public.scolaria_courses(organization_id, subject_id, updated_at desc);
create index if not exists scolaria_courses_org_teacher_updated_idx
  on public.scolaria_courses(organization_id, teacher_id, updated_at desc);
create index if not exists scolaria_courses_org_period_updated_idx
  on public.scolaria_courses(organization_id, academic_period_id, updated_at desc);
create index if not exists scolaria_resources_file_idx
  on public.scolaria_resources(file_id);
create index if not exists scolaria_lessons_chapter_idx
  on public.scolaria_lessons(chapter_id);
create index if not exists scolaria_lessons_teacher_idx
  on public.scolaria_lessons(teacher_id);

alter table public.scolaria_competencies
  add constraint scolaria_competencies_program_org_fk
  foreign key (program_id, organization_id)
  references public.scolaria_programs(id, organization_id)
  on delete cascade;
alter table public.scolaria_competencies
  add constraint scolaria_competencies_subject_org_fk
  foreign key (subject_id, organization_id)
  references public.scolaria_subjects(id, organization_id)
  on delete cascade;
alter table public.scolaria_courses
  add constraint scolaria_courses_class_org_fk
  foreign key (class_id, organization_id)
  references public.scolaria_classes(id, organization_id)
  on delete cascade;
alter table public.scolaria_courses
  add constraint scolaria_courses_subject_org_fk
  foreign key (subject_id, organization_id)
  references public.scolaria_subjects(id, organization_id)
  on delete restrict;
alter table public.scolaria_courses
  add constraint scolaria_courses_period_org_fk
  foreign key (academic_period_id, organization_id)
  references public.scolaria_academic_periods(id, organization_id)
  on delete no action;
alter table public.scolaria_course_competencies
  add constraint scolaria_course_comp_course_org_fk
  foreign key (course_id, organization_id)
  references public.scolaria_courses(id, organization_id)
  on delete cascade;
alter table public.scolaria_course_competencies
  add constraint scolaria_course_comp_competency_org_fk
  foreign key (competency_id, organization_id)
  references public.scolaria_competencies(id, organization_id)
  on delete cascade;
alter table public.scolaria_chapters
  add constraint scolaria_chapters_course_org_fk
  foreign key (course_id, organization_id)
  references public.scolaria_courses(id, organization_id)
  on delete cascade;
alter table public.scolaria_chapter_blocks
  add constraint scolaria_blocks_chapter_org_fk
  foreign key (chapter_id, organization_id)
  references public.scolaria_chapters(id, organization_id)
  on delete cascade;
alter table public.scolaria_resources
  add constraint scolaria_resources_course_org_fk
  foreign key (course_id, organization_id)
  references public.scolaria_courses(id, organization_id)
  on delete cascade;
alter table public.scolaria_resources
  add constraint scolaria_resources_chapter_course_org_fk
  foreign key (chapter_id, course_id, organization_id)
  references public.scolaria_chapters(id, course_id, organization_id)
  on delete cascade;
alter table public.scolaria_resources
  add constraint scolaria_resources_file_org_fk
  foreign key (file_id, organization_id)
  references public.scolaria_files(id, organization_id)
  on delete no action;
alter table public.scolaria_lessons
  add constraint scolaria_lessons_course_class_org_fk
  foreign key (course_id, class_id, organization_id)
  references public.scolaria_courses(id, class_id, organization_id)
  on delete cascade;
alter table public.scolaria_lessons
  add constraint scolaria_lessons_chapter_course_org_fk
  foreign key (chapter_id, course_id, organization_id)
  references public.scolaria_chapters(id, course_id, organization_id)
  on delete no action;

create or replace function private.scolaria_user_in_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_class_memberships cm
    join public.scolaria_classes c
      on c.id = cm.class_id
     and c.organization_id = cm.organization_id
    join public.scolaria_organization_members om
      on om.organization_id = cm.organization_id
     and om.user_id = cm.user_id
     and om.status = 'active'
    where cm.class_id = target_class
      and cm.user_id = (select auth.uid())
      and cm.status = 'active'
  );
$$;

revoke all on function private.scolaria_user_in_class(uuid) from public;
grant execute on function private.scolaria_user_in_class(uuid) to authenticated;

create or replace function private.scolaria_teacher_in_org(
  target_org uuid,
  target_teacher uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_teacher is null
  or exists (
    select 1
    from public.scolaria_organization_members m
    join public.scolaria_roles r
      on r.id = m.role_id
     and r.organization_id = m.organization_id
    where m.organization_id = target_org
      and m.user_id = target_teacher
      and m.status = 'active'
      and r.key = 'teacher'
  );
$$;

create or replace function private.scolaria_can_manage_course(target_course uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_courses c
    where c.id = target_course
      and private.scolaria_user_in_org(c.organization_id)
      and private.scolaria_has_permission(c.organization_id, 'courses.manage')
      and (
        coalesce(private.scolaria_role_key(c.organization_id), '') <> 'teacher'
        or c.teacher_id = (select auth.uid())
      )
  );
$$;

create or replace function private.scolaria_can_read_resource_path(resource_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.scolaria_files f
    where f.bucket_id = 'scolarys-resources'
      and f.storage_path = resource_path
      and private.scolaria_user_in_org(f.organization_id)
      and (
        f.owner_id = (select auth.uid())
        or (
          private.scolaria_has_permission(f.organization_id, 'courses.manage')
          and coalesce(private.scolaria_role_key(f.organization_id), '') <> 'teacher'
        )
        or exists (
          select 1
          from public.scolaria_resources r
          where r.file_id = f.id
            and r.organization_id = f.organization_id
            and (
              private.scolaria_can_manage_course(r.course_id)
              or (
                r.status = 'published'
                and private.scolaria_can_view_course(r.course_id)
                and (
                  r.chapter_id is null
                  or exists (
                    select 1
                    from public.scolaria_chapters ch
                    where ch.id = r.chapter_id
                      and ch.course_id = r.course_id
                      and ch.organization_id = r.organization_id
                      and ch.status = 'published'
                  )
                )
              )
            )
        )
      )
  );
$$;

create or replace function private.scolaria_reject_lms_audit_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and new.created_by is distinct from old.created_by then
    raise exception 'CREATED_BY_IMMUTABLE';
  end if;
  return new;
end;
$$;

create or replace function private.scolaria_reject_file_location_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null
     and (
       new.bucket_id is distinct from old.bucket_id
       or new.storage_path is distinct from old.storage_path
       or new.owner_id is distinct from old.owner_id
     ) then
    raise exception 'FILE_LOCATION_IMMUTABLE';
  end if;
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'scolaria_competencies',
    'scolaria_courses',
    'scolaria_course_competencies',
    'scolaria_chapters',
    'scolaria_chapter_blocks',
    'scolaria_files',
    'scolaria_resources',
    'scolaria_lessons'
  ] loop
    execute format('drop trigger if exists scolaria_reject_audit_change on public.%I', table_name);
    execute format(
      'create trigger scolaria_reject_audit_change before update on public.%I for each row execute function private.scolaria_reject_lms_audit_change()',
      table_name
    );
  end loop;
end
$$;

drop trigger if exists scolaria_reject_file_location_change on public.scolaria_files;
create trigger scolaria_reject_file_location_change
before update on public.scolaria_files
for each row execute function private.scolaria_reject_file_location_change();

revoke all on function private.scolaria_teacher_in_org(uuid, uuid) from public;
revoke all on function private.scolaria_can_manage_course(uuid) from public;
grant execute on function private.scolaria_teacher_in_org(uuid, uuid) to authenticated;
grant execute on function private.scolaria_can_manage_course(uuid) to authenticated;

drop policy if exists scolaria_courses_insert on public.scolaria_courses;
drop policy if exists scolaria_courses_update on public.scolaria_courses;

create policy scolaria_courses_insert
on public.scolaria_courses for insert to authenticated
with check (
  created_by = (select auth.uid())
  and (
    private.scolaria_is_super_admin()
    or (
      private.scolaria_user_in_org(organization_id)
      and private.scolaria_has_permission(organization_id, 'courses.manage')
      and (
        coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
        or teacher_id = (select auth.uid())
      )
    )
  )
  and private.scolaria_teacher_in_org(organization_id, teacher_id)
  and exists (
    select 1
    from public.scolaria_classes c
    where c.id = scolaria_courses.class_id
      and c.organization_id = scolaria_courses.organization_id
  )
  and exists (
    select 1
    from public.scolaria_subjects s
    where s.id = scolaria_courses.subject_id
      and s.organization_id = scolaria_courses.organization_id
      and s.is_active
  )
  and exists (
    select 1
    from public.scolaria_class_subjects cs
    where cs.class_id = scolaria_courses.class_id
      and cs.subject_id = scolaria_courses.subject_id
      and cs.organization_id = scolaria_courses.organization_id
  )
  and (
    academic_period_id is null
    or exists (
      select 1
      from public.scolaria_academic_periods ap
      where ap.id = scolaria_courses.academic_period_id
        and ap.organization_id = scolaria_courses.organization_id
    )
  )
);

create policy scolaria_courses_update
on public.scolaria_courses for update to authenticated
using (private.scolaria_can_manage_course(id))
with check (
  (
    private.scolaria_is_super_admin()
    or (
      private.scolaria_user_in_org(organization_id)
      and private.scolaria_has_permission(organization_id, 'courses.manage')
      and (
        coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
        or teacher_id = (select auth.uid())
      )
    )
  )
  and private.scolaria_teacher_in_org(organization_id, teacher_id)
  and exists (
    select 1
    from public.scolaria_classes c
    where c.id = scolaria_courses.class_id
      and c.organization_id = scolaria_courses.organization_id
  )
  and exists (
    select 1
    from public.scolaria_subjects s
    where s.id = scolaria_courses.subject_id
      and s.organization_id = scolaria_courses.organization_id
      and s.is_active
  )
  and exists (
    select 1
    from public.scolaria_class_subjects cs
    where cs.class_id = scolaria_courses.class_id
      and cs.subject_id = scolaria_courses.subject_id
      and cs.organization_id = scolaria_courses.organization_id
  )
  and (
    academic_period_id is null
    or exists (
      select 1
      from public.scolaria_academic_periods ap
      where ap.id = scolaria_courses.academic_period_id
        and ap.organization_id = scolaria_courses.organization_id
    )
  )
);

-- Repair the LMS policies whose original correlated subqueries resolved
-- unqualified outer columns against the inner relation.
drop policy if exists scolaria_competencies_insert on public.scolaria_competencies;
drop policy if exists scolaria_competencies_update on public.scolaria_competencies;

create policy scolaria_competencies_insert
on public.scolaria_competencies for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.scolaria_has_permission(organization_id, 'competencies.manage')
  and (
    program_id is null
    or exists (
      select 1
      from public.scolaria_programs p
      where p.id = scolaria_competencies.program_id
        and p.organization_id = scolaria_competencies.organization_id
    )
  )
  and (
    subject_id is null
    or exists (
      select 1
      from public.scolaria_subjects s
      where s.id = scolaria_competencies.subject_id
        and s.organization_id = scolaria_competencies.organization_id
    )
  )
);

create policy scolaria_competencies_update
on public.scolaria_competencies for update to authenticated
using (private.scolaria_has_permission(organization_id, 'competencies.manage'))
with check (
  private.scolaria_has_permission(organization_id, 'competencies.manage')
  and (
    program_id is null
    or exists (
      select 1
      from public.scolaria_programs p
      where p.id = scolaria_competencies.program_id
        and p.organization_id = scolaria_competencies.organization_id
    )
  )
  and (
    subject_id is null
    or exists (
      select 1
      from public.scolaria_subjects s
      where s.id = scolaria_competencies.subject_id
        and s.organization_id = scolaria_competencies.organization_id
    )
  )
);

drop policy if exists scolaria_course_competencies_insert on public.scolaria_course_competencies;
drop policy if exists scolaria_course_competencies_update on public.scolaria_course_competencies;

create policy scolaria_course_competencies_insert
on public.scolaria_course_competencies for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_course_competencies.course_id
      and c.organization_id = scolaria_course_competencies.organization_id
  )
  and exists (
    select 1
    from public.scolaria_competencies cp
    join public.scolaria_courses c
      on c.id = scolaria_course_competencies.course_id
     and c.organization_id = scolaria_course_competencies.organization_id
    join public.scolaria_classes cl
      on cl.id = c.class_id
     and cl.organization_id = c.organization_id
    where cp.id = scolaria_course_competencies.competency_id
      and cp.organization_id = scolaria_course_competencies.organization_id
      and (cp.program_id is null or cp.program_id = cl.program_id)
      and (cp.subject_id is null or cp.subject_id = c.subject_id)
  )
);

create policy scolaria_course_competencies_update
on public.scolaria_course_competencies for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_course_competencies.course_id
      and c.organization_id = scolaria_course_competencies.organization_id
  )
  and exists (
    select 1
    from public.scolaria_competencies cp
    join public.scolaria_courses c
      on c.id = scolaria_course_competencies.course_id
     and c.organization_id = scolaria_course_competencies.organization_id
    join public.scolaria_classes cl
      on cl.id = c.class_id
     and cl.organization_id = c.organization_id
    where cp.id = scolaria_course_competencies.competency_id
      and cp.organization_id = scolaria_course_competencies.organization_id
      and (cp.program_id is null or cp.program_id = cl.program_id)
      and (cp.subject_id is null or cp.subject_id = c.subject_id)
  )
);

drop policy if exists scolaria_chapters_insert on public.scolaria_chapters;
drop policy if exists scolaria_chapters_update on public.scolaria_chapters;

create policy scolaria_chapters_insert
on public.scolaria_chapters for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_chapters.course_id
      and c.organization_id = scolaria_chapters.organization_id
  )
);

create policy scolaria_chapters_update
on public.scolaria_chapters for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_chapters.course_id
      and c.organization_id = scolaria_chapters.organization_id
  )
);

drop policy if exists scolaria_chapter_blocks_select on public.scolaria_chapter_blocks;
drop policy if exists scolaria_chapter_blocks_insert on public.scolaria_chapter_blocks;
drop policy if exists scolaria_chapter_blocks_update on public.scolaria_chapter_blocks;

create policy scolaria_chapter_blocks_select
on public.scolaria_chapter_blocks for select to authenticated
using (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = scolaria_chapter_blocks.chapter_id
      and ch.organization_id = scolaria_chapter_blocks.organization_id
      and (
        private.scolaria_can_manage_course(ch.course_id)
        or (
          scolaria_chapter_blocks.status = 'published'
          and ch.status = 'published'
          and private.scolaria_can_view_course(ch.course_id)
        )
      )
  )
);

create policy scolaria_chapter_blocks_insert
on public.scolaria_chapter_blocks for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = scolaria_chapter_blocks.chapter_id
      and ch.organization_id = scolaria_chapter_blocks.organization_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
);

create policy scolaria_chapter_blocks_update
on public.scolaria_chapter_blocks for update to authenticated
using (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = scolaria_chapter_blocks.chapter_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
)
with check (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = scolaria_chapter_blocks.chapter_id
      and ch.organization_id = scolaria_chapter_blocks.organization_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
);

drop policy if exists scolaria_files_select on public.scolaria_files;
drop policy if exists scolaria_files_insert on public.scolaria_files;
drop policy if exists scolaria_files_update on public.scolaria_files;
drop policy if exists scolaria_files_delete on public.scolaria_files;

create policy scolaria_files_select
on public.scolaria_files for select to authenticated
using (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and (
      owner_id = (select auth.uid())
      or (
        private.scolaria_has_permission(organization_id, 'courses.manage')
        and coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      )
      or exists (
        select 1
        from public.scolaria_resources r
        where r.file_id = scolaria_files.id
          and r.organization_id = scolaria_files.organization_id
          and (
            private.scolaria_can_manage_course(r.course_id)
            or (
              r.status = 'published'
              and private.scolaria_can_view_course(r.course_id)
              and (
                r.chapter_id is null
                or exists (
                  select 1
                  from public.scolaria_chapters ch
                  where ch.id = r.chapter_id
                    and ch.course_id = r.course_id
                    and ch.organization_id = r.organization_id
                    and ch.status = 'published'
                )
              )
            )
          )
      )
    )
  )
);

create policy scolaria_files_insert
on public.scolaria_files for insert to authenticated
with check (
  created_by = (select auth.uid())
  and owner_id = (select auth.uid())
  and bucket_id = 'scolarys-resources'
  and array_length(storage.foldername(storage_path), 1) >= 2
  and (storage.foldername(storage_path))[1] = organization_id::text
  and (storage.foldername(storage_path))[2] = owner_id::text
  and private.scolaria_can_upload_resource_path(storage_path)
  and (
    private.scolaria_is_super_admin()
    or (
      private.scolaria_user_in_org(organization_id)
      and private.scolaria_has_permission(organization_id, 'courses.manage')
    )
  )
);

create policy scolaria_files_update
on public.scolaria_files for update to authenticated
using (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_has_permission(organization_id, 'courses.manage')
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or owner_id = (select auth.uid())
    )
  )
)
with check (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and private.scolaria_has_permission(organization_id, 'courses.manage')
    and bucket_id = 'scolarys-resources'
    and array_length(storage.foldername(storage_path), 1) >= 2
    and (storage.foldername(storage_path))[1] = organization_id::text
    and (storage.foldername(storage_path))[2] = owner_id::text
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or owner_id = (select auth.uid())
    )
  )
);

create policy scolaria_files_delete
on public.scolaria_files for delete to authenticated
using (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_has_permission(organization_id, 'courses.manage')
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or owner_id = (select auth.uid())
    )
  )
);

drop policy if exists scolaria_resources_insert on public.scolaria_resources;
drop policy if exists scolaria_resources_update on public.scolaria_resources;
drop policy if exists scolaria_resources_select on public.scolaria_resources;

create policy scolaria_resources_select
on public.scolaria_resources for select to authenticated
using (
  private.scolaria_can_manage_course(course_id)
  or (
    status = 'published'
    and private.scolaria_can_view_course(course_id)
    and (
      chapter_id is null
      or exists (
        select 1
        from public.scolaria_chapters ch
        where ch.id = scolaria_resources.chapter_id
          and ch.course_id = scolaria_resources.course_id
          and ch.organization_id = scolaria_resources.organization_id
          and ch.status = 'published'
      )
    )
  )
);

create policy scolaria_resources_insert
on public.scolaria_resources for insert to authenticated
with check (
  created_by = (select auth.uid())
  and private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_resources.course_id
      and c.organization_id = scolaria_resources.organization_id
  )
  and (
    chapter_id is null
    or exists (
      select 1
      from public.scolaria_chapters ch
      where ch.id = scolaria_resources.chapter_id
        and ch.course_id = scolaria_resources.course_id
        and ch.organization_id = scolaria_resources.organization_id
    )
  )
  and (
    file_id is null
    or exists (
      select 1
      from public.scolaria_files f
      where f.id = scolaria_resources.file_id
        and f.organization_id = scolaria_resources.organization_id
    )
  )
);

create policy scolaria_resources_update
on public.scolaria_resources for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_resources.course_id
      and c.organization_id = scolaria_resources.organization_id
  )
  and (
    chapter_id is null
    or exists (
      select 1
      from public.scolaria_chapters ch
      where ch.id = scolaria_resources.chapter_id
        and ch.course_id = scolaria_resources.course_id
        and ch.organization_id = scolaria_resources.organization_id
    )
  )
  and (
    file_id is null
    or exists (
      select 1
      from public.scolaria_files f
      where f.id = scolaria_resources.file_id
        and f.organization_id = scolaria_resources.organization_id
    )
  )
);

drop policy if exists scolaria_lessons_select on public.scolaria_lessons;
drop policy if exists scolaria_lessons_insert on public.scolaria_lessons;
drop policy if exists scolaria_lessons_update on public.scolaria_lessons;

create policy scolaria_lessons_select
on public.scolaria_lessons for select to authenticated
using (
  exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_lessons.course_id
      and c.organization_id = scolaria_lessons.organization_id
      and c.class_id = scolaria_lessons.class_id
      and (
        private.scolaria_can_manage_course(c.id)
        or private.scolaria_can_view_course(c.id)
      )
  )
);

create policy scolaria_lessons_insert
on public.scolaria_lessons for insert to authenticated
with check (
  created_by = (select auth.uid())
  and exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_lessons.course_id
      and c.organization_id = scolaria_lessons.organization_id
      and c.class_id = scolaria_lessons.class_id
      and private.scolaria_can_manage_course(c.id)
  )
  and (
    chapter_id is null
    or exists (
      select 1
      from public.scolaria_chapters ch
      where ch.id = scolaria_lessons.chapter_id
        and ch.course_id = scolaria_lessons.course_id
        and ch.organization_id = scolaria_lessons.organization_id
    )
  )
  and private.scolaria_teacher_in_org(organization_id, teacher_id)
  and (
    coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
    or teacher_id = (select auth.uid())
  )
);

create policy scolaria_lessons_update
on public.scolaria_lessons for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  exists (
    select 1
    from public.scolaria_courses c
    where c.id = scolaria_lessons.course_id
      and c.organization_id = scolaria_lessons.organization_id
      and c.class_id = scolaria_lessons.class_id
      and private.scolaria_can_manage_course(c.id)
  )
  and (
    chapter_id is null
    or exists (
      select 1
      from public.scolaria_chapters ch
      where ch.id = scolaria_lessons.chapter_id
        and ch.course_id = scolaria_lessons.course_id
        and ch.organization_id = scolaria_lessons.organization_id
    )
  )
  and private.scolaria_teacher_in_org(organization_id, teacher_id)
  and (
    coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
    or teacher_id = (select auth.uid())
  )
);

create or replace function private.scolaria_touch_parent_course()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_course_id uuid;
  new_course_id uuid;
begin
  if tg_table_name = 'scolaria_chapter_blocks' then
    if tg_op <> 'INSERT' then
      select ch.course_id
      into old_course_id
      from public.scolaria_chapters ch
      where ch.id = old.chapter_id;
    end if;
    if tg_op <> 'DELETE' then
      select ch.course_id
      into new_course_id
      from public.scolaria_chapters ch
      where ch.id = new.chapter_id;
    end if;
  else
    if tg_op <> 'INSERT' then
      old_course_id := old.course_id;
    end if;
    if tg_op <> 'DELETE' then
      new_course_id := new.course_id;
    end if;
  end if;

  update public.scolaria_courses
  set updated_at = now()
  where id in (old_course_id, new_course_id)
    and updated_at is distinct from now()
    and (
      (select auth.uid()) is null
      or private.scolaria_can_manage_course(id)
    );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists scolaria_chapters_touch_course on public.scolaria_chapters;
create trigger scolaria_chapters_touch_course
after insert or update or delete on public.scolaria_chapters
for each row execute function private.scolaria_touch_parent_course();

drop trigger if exists scolaria_blocks_touch_course on public.scolaria_chapter_blocks;
create trigger scolaria_blocks_touch_course
after insert or update or delete on public.scolaria_chapter_blocks
for each row execute function private.scolaria_touch_parent_course();

drop trigger if exists scolaria_resources_touch_course on public.scolaria_resources;
create trigger scolaria_resources_touch_course
after insert or update or delete on public.scolaria_resources
for each row execute function private.scolaria_touch_parent_course();

drop trigger if exists scolaria_lessons_touch_course on public.scolaria_lessons;
create trigger scolaria_lessons_touch_course
after insert or update or delete on public.scolaria_lessons
for each row execute function private.scolaria_touch_parent_course();

revoke all on function private.scolaria_touch_parent_course() from public;

create or replace function public.scolaria_create_course(
  course_title text,
  course_class_id uuid,
  course_subject_id uuid,
  course_description text default null,
  course_academic_period_id uuid default null,
  course_teacher_id uuid default null,
  course_objectives text default null,
  course_estimated_hours numeric default null,
  competency_ids uuid[] default array[]::uuid[]
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_course_id uuid;
  target_org uuid;
  target_program uuid;
  actor_id uuid := (select auth.uid());
begin
  if actor_id is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;

  course_title := btrim(coalesce(course_title, ''));
  if char_length(course_title) < 3 or char_length(course_title) > 160 then
    raise exception 'COURSE_TITLE_INVALID';
  end if;
  if course_estimated_hours is not null and course_estimated_hours < 0 then
    raise exception 'COURSE_DURATION_INVALID';
  end if;

  select c.organization_id, c.program_id
  into target_org, target_program
  from public.scolaria_classes c
  where c.id = course_class_id;

  if target_org is null
     or not private.scolaria_user_in_org(target_org)
     or not private.scolaria_has_permission(target_org, 'courses.manage') then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  if private.scolaria_role_key(target_org) = 'teacher' then
    course_teacher_id := actor_id;
  end if;

  if not private.scolaria_teacher_in_org(target_org, course_teacher_id) then
    raise exception 'COURSE_TEACHER_INVALID';
  end if;
  if not exists (
    select 1
    from public.scolaria_subjects s
    where s.id = course_subject_id
      and s.organization_id = target_org
      and s.is_active
  ) then
    raise exception 'COURSE_SUBJECT_INVALID';
  end if;
  if not exists (
    select 1
    from public.scolaria_class_subjects cs
    where cs.organization_id = target_org
      and cs.class_id = course_class_id
      and cs.subject_id = course_subject_id
  ) then
    raise exception 'COURSE_CLASS_SUBJECT_INVALID';
  end if;
  if course_academic_period_id is not null and not exists (
    select 1
    from public.scolaria_academic_periods ap
    where ap.id = course_academic_period_id
      and ap.organization_id = target_org
  ) then
    raise exception 'COURSE_PERIOD_INVALID';
  end if;
  if exists (
    select 1
    from unnest(coalesce(competency_ids, array[]::uuid[])) selected(id)
    left join public.scolaria_competencies cp
      on cp.id = selected.id
     and cp.organization_id = target_org
     and cp.is_active
     and (cp.program_id is null or cp.program_id = target_program)
     and (cp.subject_id is null or cp.subject_id = course_subject_id)
    where cp.id is null
  ) then
    raise exception 'COURSE_COMPETENCY_INVALID';
  end if;

  insert into public.scolaria_courses (
    organization_id,
    class_id,
    subject_id,
    academic_period_id,
    teacher_id,
    title,
    description,
    objectives,
    estimated_hours,
    status,
    created_by
  )
  values (
    target_org,
    course_class_id,
    course_subject_id,
    course_academic_period_id,
    course_teacher_id,
    course_title,
    nullif(btrim(coalesce(course_description, '')), ''),
    nullif(btrim(coalesce(course_objectives, '')), ''),
    course_estimated_hours,
    'draft',
    actor_id
  )
  returning id into new_course_id;

  insert into public.scolaria_course_competencies (
    organization_id,
    course_id,
    competency_id,
    created_by
  )
  select target_org, new_course_id, selected.id, actor_id
  from (
    select distinct id
    from unnest(coalesce(competency_ids, array[]::uuid[])) selected(id)
  ) selected;

  return new_course_id;
end;
$$;

create or replace function public.scolaria_update_course(
  target_course_id uuid,
  course_title text,
  course_class_id uuid,
  course_subject_id uuid,
  course_description text default null,
  course_academic_period_id uuid default null,
  course_teacher_id uuid default null,
  course_objectives text default null,
  course_estimated_hours numeric default null,
  course_status text default 'draft',
  competency_ids uuid[] default array[]::uuid[]
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_org uuid;
  target_program uuid;
  actor_id uuid := (select auth.uid());
begin
  if actor_id is null then
    raise exception 'AUTHENTICATION_REQUIRED';
  end if;
  if not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  select c.organization_id
  into target_org
  from public.scolaria_courses c
  where c.id = target_course_id
  for update;

  course_title := btrim(coalesce(course_title, ''));
  if char_length(course_title) < 3 or char_length(course_title) > 160 then
    raise exception 'COURSE_TITLE_INVALID';
  end if;
  if course_estimated_hours is not null and course_estimated_hours < 0 then
    raise exception 'COURSE_DURATION_INVALID';
  end if;
  if course_status not in ('draft', 'published', 'archived') then
    raise exception 'COURSE_STATUS_INVALID';
  end if;
  if private.scolaria_role_key(target_org) = 'teacher' then
    course_teacher_id := actor_id;
  end if;
  if not private.scolaria_teacher_in_org(target_org, course_teacher_id) then
    raise exception 'COURSE_TEACHER_INVALID';
  end if;
  select c.program_id
  into target_program
  from public.scolaria_classes c
  where c.id = course_class_id
    and c.organization_id = target_org;

  if target_program is null then
    raise exception 'COURSE_CLASS_INVALID';
  end if;
  if not exists (
    select 1 from public.scolaria_subjects s
    where s.id = course_subject_id
      and s.organization_id = target_org
      and s.is_active
  ) then
    raise exception 'COURSE_SUBJECT_INVALID';
  end if;
  if not exists (
    select 1 from public.scolaria_class_subjects cs
    where cs.organization_id = target_org
      and cs.class_id = course_class_id
      and cs.subject_id = course_subject_id
  ) then
    raise exception 'COURSE_CLASS_SUBJECT_INVALID';
  end if;
  if course_academic_period_id is not null and not exists (
    select 1 from public.scolaria_academic_periods ap
    where ap.id = course_academic_period_id
      and ap.organization_id = target_org
  ) then
    raise exception 'COURSE_PERIOD_INVALID';
  end if;
  if exists (
    select 1
    from unnest(coalesce(competency_ids, array[]::uuid[])) selected(id)
    left join public.scolaria_competencies cp
      on cp.id = selected.id
     and cp.organization_id = target_org
     and (cp.program_id is null or cp.program_id = target_program)
     and (cp.subject_id is null or cp.subject_id = course_subject_id)
    where cp.id is null
       or (
         not cp.is_active
         and not exists (
           select 1
           from public.scolaria_course_competencies existing
           where existing.course_id = target_course_id
             and existing.competency_id = selected.id
             and existing.organization_id = target_org
         )
       )
  ) then
    raise exception 'COURSE_COMPETENCY_INVALID';
  end if;

  update public.scolaria_courses
  set class_id = course_class_id,
      subject_id = course_subject_id,
      academic_period_id = course_academic_period_id,
      teacher_id = course_teacher_id,
      title = course_title,
      description = nullif(btrim(coalesce(course_description, '')), ''),
      objectives = nullif(btrim(coalesce(course_objectives, '')), ''),
      estimated_hours = course_estimated_hours,
      status = course_status,
      published_at = case
        when course_status = 'published' then coalesce(published_at, now())
        when course_status = 'draft' then null
        else published_at
      end
  where id = target_course_id;

  delete from public.scolaria_course_competencies
  where course_id = target_course_id;

  insert into public.scolaria_course_competencies (
    organization_id,
    course_id,
    competency_id,
    created_by
  )
  select target_org, target_course_id, selected.id, actor_id
  from (
    select distinct id
    from unnest(coalesce(competency_ids, array[]::uuid[])) selected(id)
  ) selected;

  return target_course_id;
end;
$$;

create or replace function public.scolaria_create_chapter(
  target_course_id uuid,
  chapter_title text,
  chapter_description text default null,
  chapter_objectives text default null,
  chapter_estimated_minutes integer default null,
  chapter_structured_zones_enabled boolean default true,
  chapter_scheduled_at timestamptz default null,
  chapter_status text default 'draft'
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_org uuid;
  next_ordinal integer;
  new_chapter_id uuid;
  actor_id uuid := (select auth.uid());
begin
  if actor_id is null or not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;
  chapter_title := btrim(coalesce(chapter_title, ''));
  if char_length(chapter_title) < 2 or char_length(chapter_title) > 160 then
    raise exception 'CHAPTER_TITLE_INVALID';
  end if;
  if chapter_estimated_minutes is not null and chapter_estimated_minutes < 0 then
    raise exception 'CHAPTER_DURATION_INVALID';
  end if;
  if chapter_status not in ('draft', 'scheduled', 'published', 'archived') then
    raise exception 'CHAPTER_STATUS_INVALID';
  end if;
  if chapter_status = 'scheduled' and chapter_scheduled_at is null then
    raise exception 'CHAPTER_SCHEDULE_INVALID';
  end if;
  if chapter_status <> 'scheduled' then
    chapter_scheduled_at := null;
  end if;

  select c.organization_id
  into target_org
  from public.scolaria_courses c
  where c.id = target_course_id
  for update;

  select coalesce(max(ch.ordinal), 0) + 1
  into next_ordinal
  from public.scolaria_chapters ch
  where ch.course_id = target_course_id;

  insert into public.scolaria_chapters (
    organization_id,
    course_id,
    title,
    description,
    objectives,
    ordinal,
    estimated_minutes,
    structured_zones_enabled,
    status,
    scheduled_at,
    published_at,
    created_by
  )
  values (
    target_org,
    target_course_id,
    chapter_title,
    nullif(btrim(coalesce(chapter_description, '')), ''),
    nullif(btrim(coalesce(chapter_objectives, '')), ''),
    next_ordinal,
    chapter_estimated_minutes,
    chapter_structured_zones_enabled,
    chapter_status,
    chapter_scheduled_at,
    case when chapter_status = 'published' then now() else null end,
    actor_id
  )
  returning id into new_chapter_id;

  return new_chapter_id;
end;
$$;

create or replace function public.scolaria_move_chapter(
  target_chapter_id uuid,
  move_direction text
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_course_id uuid;
  current_ordinal integer;
  neighbor_id uuid;
  neighbor_ordinal integer;
  temporary_ordinal integer;
begin
  if move_direction not in ('up', 'down') then
    raise exception 'CHAPTER_DIRECTION_INVALID';
  end if;

  select ch.course_id
  into target_course_id
  from public.scolaria_chapters ch
  where ch.id = target_chapter_id;

  if target_course_id is null
     or not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  perform 1
  from public.scolaria_courses c
  where c.id = target_course_id
  for update;

  if not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  perform 1
  from public.scolaria_chapters ch
  where ch.course_id = target_course_id
  for update;

  select ch.ordinal
  into current_ordinal
  from public.scolaria_chapters ch
  where ch.id = target_chapter_id
    and ch.course_id = target_course_id;

  if current_ordinal is null then
    raise exception 'CHAPTER_NOT_FOUND';
  end if;

  if move_direction = 'up' then
    select ch.id, ch.ordinal
    into neighbor_id, neighbor_ordinal
    from public.scolaria_chapters ch
    where ch.course_id = target_course_id
      and ch.ordinal < current_ordinal
    order by ch.ordinal desc
    limit 1;
  else
    select ch.id, ch.ordinal
    into neighbor_id, neighbor_ordinal
    from public.scolaria_chapters ch
    where ch.course_id = target_course_id
      and ch.ordinal > current_ordinal
    order by ch.ordinal asc
    limit 1;
  end if;

  if neighbor_id is null then
    return false;
  end if;

  select coalesce(max(ch.ordinal), 0) + 1
  into temporary_ordinal
  from public.scolaria_chapters ch
  where ch.course_id = target_course_id;

  update public.scolaria_chapters
  set ordinal = temporary_ordinal
  where id = target_chapter_id;

  update public.scolaria_chapters
  set ordinal = current_ordinal
  where id = neighbor_id;

  update public.scolaria_chapters
  set ordinal = neighbor_ordinal
  where id = target_chapter_id;

  return true;
end;
$$;

create or replace function public.scolaria_delete_chapter(target_chapter_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_course_id uuid;
  deleted_resources integer;
  temporary_offset integer;
begin
  select ch.course_id
  into target_course_id
  from public.scolaria_chapters ch
  where ch.id = target_chapter_id;

  if target_course_id is null
     or not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  perform 1
  from public.scolaria_courses c
  where c.id = target_course_id
  for update;

  if not private.scolaria_can_manage_course(target_course_id) then
    raise exception 'COURSE_ACCESS_DENIED';
  end if;

  perform 1
  from public.scolaria_chapters ch
  where ch.course_id = target_course_id
  for update;

  select count(*)::integer
  into deleted_resources
  from public.scolaria_resources r
  where r.chapter_id = target_chapter_id
    and r.course_id = target_course_id;

  delete from public.scolaria_chapters ch
  where ch.id = target_chapter_id
    and ch.course_id = target_course_id;

  if not found then
    raise exception 'CHAPTER_NOT_FOUND';
  end if;

  select coalesce(max(ch.ordinal), 0) + count(*)::integer + 1
  into temporary_offset
  from public.scolaria_chapters ch
  where ch.course_id = target_course_id;

  update public.scolaria_chapters ch
  set ordinal = ch.ordinal + temporary_offset
  where ch.course_id = target_course_id;

  with ranked as (
    select ch.id, row_number() over (order by ch.ordinal, ch.id)::integer as new_ordinal
    from public.scolaria_chapters ch
    where ch.course_id = target_course_id
  )
  update public.scolaria_chapters ch
  set ordinal = ranked.new_ordinal
  from ranked
  where ch.id = ranked.id;

  return deleted_resources;
end;
$$;

drop policy if exists scolarys_resources_storage_select on storage.objects;
drop policy if exists scolarys_resources_storage_insert on storage.objects;
drop policy if exists scolarys_resources_storage_update on storage.objects;
drop policy if exists scolarys_resources_storage_delete on storage.objects;

create policy scolarys_resources_storage_select
on storage.objects for select to authenticated
using (
  bucket_id = 'scolarys-resources'
  and (
    private.scolaria_can_upload_resource_path(name)
    or private.scolaria_can_read_resource_path(name)
  )
);

create policy scolarys_resources_storage_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'scolarys-resources'
  and private.scolaria_can_upload_resource_path(name)
);

create policy scolarys_resources_storage_update
on storage.objects for update to authenticated
using (
  bucket_id = 'scolarys-resources'
  and owner_id = (select auth.uid())::text
  and private.scolaria_can_upload_resource_path(name)
)
with check (
  bucket_id = 'scolarys-resources'
  and owner_id = (select auth.uid())::text
  and private.scolaria_can_upload_resource_path(name)
  and exists (
    select 1
    from public.scolaria_files f
    where f.bucket_id = objects.bucket_id
      and f.storage_path = objects.name
      and f.owner_id = (select auth.uid())
      and private.scolaria_user_in_org(f.organization_id)
  )
);

create policy scolarys_resources_storage_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'scolarys-resources'
  and owner_id = (select auth.uid())::text
  and private.scolaria_can_upload_resource_path(name)
);

revoke all on function public.scolaria_create_course(text, uuid, uuid, text, uuid, uuid, text, numeric, uuid[]) from public, anon;
revoke all on function public.scolaria_update_course(uuid, text, uuid, uuid, text, uuid, uuid, text, numeric, text, uuid[]) from public, anon;
revoke all on function public.scolaria_create_chapter(uuid, text, text, text, integer, boolean, timestamptz, text) from public, anon;
revoke all on function public.scolaria_move_chapter(uuid, text) from public, anon;
revoke all on function public.scolaria_delete_chapter(uuid) from public, anon;
revoke all on function private.scolaria_can_read_resource_path(text) from public;
revoke all on function private.scolaria_can_upload_resource_path(text) from public;
revoke all on function private.scolaria_reject_lms_audit_change() from public;
revoke all on function private.scolaria_reject_file_location_change() from public;

grant execute on function public.scolaria_create_course(text, uuid, uuid, text, uuid, uuid, text, numeric, uuid[]) to authenticated;
grant execute on function public.scolaria_update_course(uuid, text, uuid, uuid, text, uuid, uuid, text, numeric, text, uuid[]) to authenticated;
grant execute on function public.scolaria_create_chapter(uuid, text, text, text, integer, boolean, timestamptz, text) to authenticated;
grant execute on function public.scolaria_move_chapter(uuid, text) to authenticated;
grant execute on function public.scolaria_delete_chapter(uuid) to authenticated;
grant execute on function private.scolaria_can_read_resource_path(text) to authenticated;
grant execute on function private.scolaria_can_upload_resource_path(text) to authenticated;
