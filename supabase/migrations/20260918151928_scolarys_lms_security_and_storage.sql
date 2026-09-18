
-- SCOLARYS LMS security hardening, tenant immutability and private resource storage.

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
        or c.created_by = (select auth.uid())
      )
  );
$$;

create or replace function private.scolaria_reject_organization_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception 'ORGANIZATION_ID_IMMUTABLE';
  end if;
  return new;
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select distinct c.table_name
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name like 'scolaria_%'
      and c.column_name = 'organization_id'
  loop
    execute format('drop trigger if exists scolaria_reject_org_change on public.%I', r.table_name);
    execute format(
      'create trigger scolaria_reject_org_change before update on public.%I for each row execute function private.scolaria_reject_organization_change()',
      r.table_name
    );
  end loop;
end
$$;

-- Explicit Data API grants for the LMS tables. RLS remains authoritative.
revoke all on table
  public.scolaria_competencies,
  public.scolaria_courses,
  public.scolaria_course_competencies,
  public.scolaria_chapters,
  public.scolaria_chapter_blocks,
  public.scolaria_files,
  public.scolaria_resources,
  public.scolaria_lessons
from anon;

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

-- Competencies
drop policy if exists scolaria_competencies_select on public.scolaria_competencies;
drop policy if exists scolaria_competencies_insert on public.scolaria_competencies;
drop policy if exists scolaria_competencies_update on public.scolaria_competencies;
drop policy if exists scolaria_competencies_delete on public.scolaria_competencies;

create policy scolaria_competencies_select
on public.scolaria_competencies for select to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_competencies_insert
on public.scolaria_competencies for insert to authenticated
with check (
  private.scolaria_has_permission(organization_id, 'competencies.manage')
  and (program_id is null or exists (
    select 1 from public.scolaria_programs p
    where p.id = program_id and p.organization_id = organization_id
  ))
  and (subject_id is null or exists (
    select 1 from public.scolaria_subjects s
    where s.id = subject_id and s.organization_id = organization_id
  ))
);

create policy scolaria_competencies_update
on public.scolaria_competencies for update to authenticated
using (private.scolaria_has_permission(organization_id, 'competencies.manage'))
with check (
  private.scolaria_has_permission(organization_id, 'competencies.manage')
  and (program_id is null or exists (
    select 1 from public.scolaria_programs p
    where p.id = program_id and p.organization_id = organization_id
  ))
  and (subject_id is null or exists (
    select 1 from public.scolaria_subjects s
    where s.id = subject_id and s.organization_id = organization_id
  ))
);

create policy scolaria_competencies_delete
on public.scolaria_competencies for delete to authenticated
using (private.scolaria_has_permission(organization_id, 'competencies.manage'));

-- Courses
drop policy if exists scolaria_courses_select on public.scolaria_courses;
drop policy if exists scolaria_courses_insert on public.scolaria_courses;
drop policy if exists scolaria_courses_update on public.scolaria_courses;
drop policy if exists scolaria_courses_delete on public.scolaria_courses;

create policy scolaria_courses_select
on public.scolaria_courses for select to authenticated
using (private.scolaria_can_view_course(id));

create policy scolaria_courses_insert
on public.scolaria_courses for insert to authenticated
with check (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and private.scolaria_has_permission(organization_id, 'courses.manage')
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or teacher_id = (select auth.uid())
      or created_by = (select auth.uid())
    )
    and exists (
      select 1 from public.scolaria_classes c
      where c.id = class_id and c.organization_id = organization_id
    )
    and exists (
      select 1 from public.scolaria_subjects s
      where s.id = subject_id and s.organization_id = organization_id
    )
    and (
      academic_period_id is null
      or exists (
        select 1 from public.scolaria_academic_periods ap
        where ap.id = academic_period_id and ap.organization_id = organization_id
      )
    )
  )
);

create policy scolaria_courses_update
on public.scolaria_courses for update to authenticated
using (private.scolaria_can_manage_course(id))
with check (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and private.scolaria_has_permission(organization_id, 'courses.manage')
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or teacher_id = (select auth.uid())
      or created_by = (select auth.uid())
    )
    and exists (
      select 1 from public.scolaria_classes c
      where c.id = class_id and c.organization_id = organization_id
    )
    and exists (
      select 1 from public.scolaria_subjects s
      where s.id = subject_id and s.organization_id = organization_id
    )
    and (
      academic_period_id is null
      or exists (
        select 1 from public.scolaria_academic_periods ap
        where ap.id = academic_period_id and ap.organization_id = organization_id
      )
    )
  )
);

create policy scolaria_courses_delete
on public.scolaria_courses for delete to authenticated
using (private.scolaria_can_manage_course(id));

-- Course ↔ competency links
drop policy if exists scolaria_course_competencies_select on public.scolaria_course_competencies;
drop policy if exists scolaria_course_competencies_insert on public.scolaria_course_competencies;
drop policy if exists scolaria_course_competencies_update on public.scolaria_course_competencies;
drop policy if exists scolaria_course_competencies_delete on public.scolaria_course_competencies;

create policy scolaria_course_competencies_select
on public.scolaria_course_competencies for select to authenticated
using (private.scolaria_can_view_course(course_id));

create policy scolaria_course_competencies_insert
on public.scolaria_course_competencies for insert to authenticated
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
  and exists (
    select 1 from public.scolaria_competencies cp
    where cp.id = competency_id and cp.organization_id = organization_id
  )
);

create policy scolaria_course_competencies_update
on public.scolaria_course_competencies for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
  and exists (
    select 1 from public.scolaria_competencies cp
    where cp.id = competency_id and cp.organization_id = organization_id
  )
);

create policy scolaria_course_competencies_delete
on public.scolaria_course_competencies for delete to authenticated
using (private.scolaria_can_manage_course(course_id));

-- Chapters
drop policy if exists scolaria_chapters_select on public.scolaria_chapters;
drop policy if exists scolaria_chapters_insert on public.scolaria_chapters;
drop policy if exists scolaria_chapters_update on public.scolaria_chapters;
drop policy if exists scolaria_chapters_delete on public.scolaria_chapters;

create policy scolaria_chapters_select
on public.scolaria_chapters for select to authenticated
using (
  private.scolaria_can_manage_course(course_id)
  or (status = 'published' and private.scolaria_can_view_course(course_id))
);

create policy scolaria_chapters_insert
on public.scolaria_chapters for insert to authenticated
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
);

create policy scolaria_chapters_update
on public.scolaria_chapters for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
);

create policy scolaria_chapters_delete
on public.scolaria_chapters for delete to authenticated
using (private.scolaria_can_manage_course(course_id));

-- Chapter blocks
drop policy if exists scolaria_chapter_blocks_select on public.scolaria_chapter_blocks;
drop policy if exists scolaria_chapter_blocks_insert on public.scolaria_chapter_blocks;
drop policy if exists scolaria_chapter_blocks_update on public.scolaria_chapter_blocks;
drop policy if exists scolaria_chapter_blocks_delete on public.scolaria_chapter_blocks;

create policy scolaria_chapter_blocks_select
on public.scolaria_chapter_blocks for select to authenticated
using (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = chapter_id
      and ch.organization_id = organization_id
      and (
        private.scolaria_can_manage_course(ch.course_id)
        or (
          status = 'published'
          and ch.status = 'published'
          and private.scolaria_can_view_course(ch.course_id)
        )
      )
  )
);

create policy scolaria_chapter_blocks_insert
on public.scolaria_chapter_blocks for insert to authenticated
with check (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = chapter_id
      and ch.organization_id = organization_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
);

create policy scolaria_chapter_blocks_update
on public.scolaria_chapter_blocks for update to authenticated
using (
  exists (
    select 1 from public.scolaria_chapters ch
    where ch.id = chapter_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
)
with check (
  exists (
    select 1
    from public.scolaria_chapters ch
    where ch.id = chapter_id
      and ch.organization_id = organization_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
);

create policy scolaria_chapter_blocks_delete
on public.scolaria_chapter_blocks for delete to authenticated
using (
  exists (
    select 1 from public.scolaria_chapters ch
    where ch.id = chapter_id
      and private.scolaria_can_manage_course(ch.course_id)
  )
);

-- Files metadata
alter table public.scolaria_files
  alter column bucket_id set default 'scolarys-resources';

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
        where r.file_id = id
          and r.organization_id = organization_id
          and (
            private.scolaria_can_manage_course(r.course_id)
            or (r.status = 'published' and private.scolaria_can_view_course(r.course_id))
          )
      )
    )
  )
);

create policy scolaria_files_insert
on public.scolaria_files for insert to authenticated
with check (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and private.scolaria_has_permission(organization_id, 'courses.manage')
    and bucket_id = 'scolarys-resources'
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or owner_id = (select auth.uid())
      or created_by = (select auth.uid())
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
      or created_by = (select auth.uid())
    )
  )
)
with check (
  private.scolaria_is_super_admin()
  or (
    private.scolaria_user_in_org(organization_id)
    and private.scolaria_has_permission(organization_id, 'courses.manage')
    and bucket_id = 'scolarys-resources'
    and (
      coalesce(private.scolaria_role_key(organization_id), '') <> 'teacher'
      or owner_id = (select auth.uid())
      or created_by = (select auth.uid())
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
      or created_by = (select auth.uid())
    )
  )
);

-- Resources
drop policy if exists scolaria_resources_select on public.scolaria_resources;
drop policy if exists scolaria_resources_insert on public.scolaria_resources;
drop policy if exists scolaria_resources_update on public.scolaria_resources;
drop policy if exists scolaria_resources_delete on public.scolaria_resources;

create policy scolaria_resources_select
on public.scolaria_resources for select to authenticated
using (
  private.scolaria_can_manage_course(course_id)
  or (status = 'published' and private.scolaria_can_view_course(course_id))
);

create policy scolaria_resources_insert
on public.scolaria_resources for insert to authenticated
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
  and (
    chapter_id is null
    or exists (
      select 1 from public.scolaria_chapters ch
      where ch.id = chapter_id
        and ch.course_id = course_id
        and ch.organization_id = organization_id
    )
  )
  and (
    file_id is null
    or exists (
      select 1 from public.scolaria_files f
      where f.id = file_id and f.organization_id = organization_id
    )
  )
);

create policy scolaria_resources_update
on public.scolaria_resources for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  private.scolaria_can_manage_course(course_id)
  and exists (
    select 1 from public.scolaria_courses c
    where c.id = course_id and c.organization_id = organization_id
  )
  and (
    chapter_id is null
    or exists (
      select 1 from public.scolaria_chapters ch
      where ch.id = chapter_id
        and ch.course_id = course_id
        and ch.organization_id = organization_id
    )
  )
  and (
    file_id is null
    or exists (
      select 1 from public.scolaria_files f
      where f.id = file_id and f.organization_id = organization_id
    )
  )
);

create policy scolaria_resources_delete
on public.scolaria_resources for delete to authenticated
using (private.scolaria_can_manage_course(course_id));

-- Lessons / sessions
drop policy if exists scolaria_lessons_select on public.scolaria_lessons;
drop policy if exists scolaria_lessons_insert on public.scolaria_lessons;
drop policy if exists scolaria_lessons_update on public.scolaria_lessons;
drop policy if exists scolaria_lessons_delete on public.scolaria_lessons;

create policy scolaria_lessons_select
on public.scolaria_lessons for select to authenticated
using (
  exists (
    select 1
    from public.scolaria_courses c
    where c.id = course_id
      and c.organization_id = organization_id
      and c.class_id = class_id
      and (
        private.scolaria_can_manage_course(c.id)
        or private.scolaria_can_view_course(c.id)
      )
  )
);

create policy scolaria_lessons_insert
on public.scolaria_lessons for insert to authenticated
with check (
  exists (
    select 1
    from public.scolaria_courses c
    where c.id = course_id
      and c.organization_id = organization_id
      and c.class_id = class_id
      and private.scolaria_can_manage_course(c.id)
  )
  and (
    chapter_id is null
    or exists (
      select 1 from public.scolaria_chapters ch
      where ch.id = chapter_id
        and ch.course_id = course_id
        and ch.organization_id = organization_id
    )
  )
);

create policy scolaria_lessons_update
on public.scolaria_lessons for update to authenticated
using (private.scolaria_can_manage_course(course_id))
with check (
  exists (
    select 1
    from public.scolaria_courses c
    where c.id = course_id
      and c.organization_id = organization_id
      and c.class_id = class_id
      and private.scolaria_can_manage_course(c.id)
  )
  and (
    chapter_id is null
    or exists (
      select 1 from public.scolaria_chapters ch
      where ch.id = chapter_id
        and ch.course_id = course_id
        and ch.organization_id = organization_id
    )
  )
);

create policy scolaria_lessons_delete
on public.scolaria_lessons for delete to authenticated
using (private.scolaria_can_manage_course(course_id));

-- Private Storage bucket.
insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'scolarys-resources',
  'scolarys-resources',
  false,
  104857600,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'image/*',
    'video/*'
  ]::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

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
              or (r.status = 'published' and private.scolaria_can_view_course(r.course_id))
            )
        )
      )
  );
$$;

create or replace function private.scolaria_can_upload_resource_path(resource_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and array_length(storage.foldername(resource_path), 1) >= 2
    and (storage.foldername(resource_path))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    and (storage.foldername(resource_path))[2] = (select auth.uid())::text
    and private.scolaria_user_in_org(
      case
        when (storage.foldername(resource_path))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        then (storage.foldername(resource_path))[1]::uuid
        else null
      end
    )
    and private.scolaria_has_permission(
      case
        when (storage.foldername(resource_path))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
        then (storage.foldername(resource_path))[1]::uuid
        else null
      end,
      'courses.manage'
    );
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
    owner_id = (select auth.uid())::text
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
)
with check (
  bucket_id = 'scolarys-resources'
  and owner_id = (select auth.uid())::text
  and private.scolaria_can_upload_resource_path(name)
);

create policy scolarys_resources_storage_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'scolarys-resources'
  and owner_id = (select auth.uid())::text
);
