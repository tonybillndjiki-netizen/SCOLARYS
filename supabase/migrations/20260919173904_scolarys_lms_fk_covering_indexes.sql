-- Cover every LMS foreign key with an index whose leading columns match the
-- constraint order. This keeps tenant-integrity checks and cascades efficient.

create index if not exists scolaria_blocks_chapter_org_idx
  on public.scolaria_chapter_blocks (chapter_id, organization_id);
create index if not exists scolaria_blocks_created_by_idx
  on public.scolaria_chapter_blocks (created_by);
create index if not exists scolaria_blocks_org_idx
  on public.scolaria_chapter_blocks (organization_id);

create index if not exists scolaria_chapters_course_org_idx
  on public.scolaria_chapters (course_id, organization_id);
create index if not exists scolaria_chapters_created_by_idx
  on public.scolaria_chapters (created_by);
create index if not exists scolaria_chapters_org_idx
  on public.scolaria_chapters (organization_id);

create index if not exists scolaria_competencies_created_by_idx
  on public.scolaria_competencies (created_by);
create index if not exists scolaria_competencies_program_org_idx
  on public.scolaria_competencies (program_id, organization_id);
create index if not exists scolaria_competencies_subject_org_idx
  on public.scolaria_competencies (subject_id, organization_id);

create index if not exists scolaria_course_comp_competency_org_idx
  on public.scolaria_course_competencies (competency_id, organization_id);
create index if not exists scolaria_course_comp_course_org_idx
  on public.scolaria_course_competencies (course_id, organization_id);
create index if not exists scolaria_course_comp_created_by_idx
  on public.scolaria_course_competencies (created_by);
create index if not exists scolaria_course_comp_org_idx
  on public.scolaria_course_competencies (organization_id);

create index if not exists scolaria_courses_class_org_idx
  on public.scolaria_courses (class_id, organization_id);
create index if not exists scolaria_courses_created_by_idx
  on public.scolaria_courses (created_by);
create index if not exists scolaria_courses_period_org_idx
  on public.scolaria_courses (academic_period_id, organization_id);
create index if not exists scolaria_courses_subject_org_idx
  on public.scolaria_courses (subject_id, organization_id);

create index if not exists scolaria_files_created_by_idx
  on public.scolaria_files (created_by);
create index if not exists scolaria_files_owner_idx
  on public.scolaria_files (owner_id);

create index if not exists scolaria_lessons_chapter_course_org_idx
  on public.scolaria_lessons (chapter_id, course_id, organization_id);
create index if not exists scolaria_lessons_course_class_org_idx
  on public.scolaria_lessons (course_id, class_id, organization_id);
create index if not exists scolaria_lessons_created_by_idx
  on public.scolaria_lessons (created_by);
create index if not exists scolaria_lessons_org_idx
  on public.scolaria_lessons (organization_id);

create index if not exists scolaria_resources_chapter_course_org_idx
  on public.scolaria_resources (chapter_id, course_id, organization_id);
create index if not exists scolaria_resources_course_org_idx
  on public.scolaria_resources (course_id, organization_id);
create index if not exists scolaria_resources_created_by_idx
  on public.scolaria_resources (created_by);
create index if not exists scolaria_resources_file_org_idx
  on public.scolaria_resources (file_id, organization_id);
create index if not exists scolaria_resources_org_idx
  on public.scolaria_resources (organization_id);

-- This pre-existing core FK surfaced in the same post-migration advisor pass.
create index if not exists scolaria_class_memberships_org_idx
  on public.scolaria_class_memberships (organization_id);
