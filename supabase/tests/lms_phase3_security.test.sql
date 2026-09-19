begin;
select plan(36);

select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_competencies'::regclass), 'competencies RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_courses'::regclass), 'courses RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_course_competencies'::regclass), 'course competencies RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_chapters'::regclass), 'chapters RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_chapter_blocks'::regclass), 'chapter blocks RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_files'::regclass), 'files RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_resources'::regclass), 'resources RLS enabled');
select ok((select relrowsecurity from pg_class where oid = 'public.scolaria_lessons'::regclass), 'lessons RLS enabled');

select ok(not has_table_privilege('authenticated', 'public.scolaria_competencies', 'TRUNCATE'), 'authenticated cannot truncate competencies');
select ok(not has_table_privilege('authenticated', 'public.scolaria_courses', 'TRUNCATE'), 'authenticated cannot truncate courses');
select ok(not has_table_privilege('authenticated', 'public.scolaria_course_competencies', 'TRUNCATE'), 'authenticated cannot truncate course competencies');
select ok(not has_table_privilege('authenticated', 'public.scolaria_chapters', 'TRUNCATE'), 'authenticated cannot truncate chapters');
select ok(not has_table_privilege('authenticated', 'public.scolaria_chapter_blocks', 'TRUNCATE'), 'authenticated cannot truncate chapter blocks');
select ok(not has_table_privilege('authenticated', 'public.scolaria_files', 'TRUNCATE'), 'authenticated cannot truncate files');
select ok(not has_table_privilege('authenticated', 'public.scolaria_resources', 'TRUNCATE'), 'authenticated cannot truncate resources');
select ok(not has_table_privilege('authenticated', 'public.scolaria_lessons', 'TRUNCATE'), 'authenticated cannot truncate lessons');

select ok(
  position(
    'scolaria_chapter_blocks.status' in (
      select pg_get_expr(p.polqual, p.polrelid)
      from pg_policy p
      where p.polrelid = 'public.scolaria_chapter_blocks'::regclass
        and p.polname = 'scolaria_chapter_blocks_select'
    )
  ) > 0,
  'block select policy checks the outer block status'
);

select ok(
  position(
    'scolaria_files.id' in (
      select pg_get_expr(p.polqual, p.polrelid)
      from pg_policy p
      where p.polrelid = 'public.scolaria_files'::regclass
        and p.polname = 'scolaria_files_select'
    )
  ) > 0,
  'file select policy correlates resources to the outer file row'
);

select ok(not has_function_privilege('anon', 'public.scolaria_create_course(text,uuid,uuid,text,uuid,uuid,text,numeric,uuid[])', 'EXECUTE'), 'anon cannot create courses');
select ok(not has_function_privilege('anon', 'public.scolaria_update_course(uuid,text,uuid,uuid,text,uuid,uuid,text,numeric,text,uuid[])', 'EXECUTE'), 'anon cannot update courses');
select ok(not has_function_privilege('anon', 'public.scolaria_create_chapter(uuid,text,text,text,integer,boolean,timestamptz,text)', 'EXECUTE'), 'anon cannot create chapters');
select ok(not has_function_privilege('anon', 'public.scolaria_move_chapter(uuid,text)', 'EXECUTE'), 'anon cannot reorder chapters');

select ok(has_function_privilege('authenticated', 'public.scolaria_create_course(text,uuid,uuid,text,uuid,uuid,text,numeric,uuid[])', 'EXECUTE'), 'authenticated can invoke course creation under RLS');
select ok(has_function_privilege('authenticated', 'public.scolaria_update_course(uuid,text,uuid,uuid,text,uuid,uuid,text,numeric,text,uuid[])', 'EXECUTE'), 'authenticated can invoke course update under RLS');
select ok(has_function_privilege('authenticated', 'public.scolaria_create_chapter(uuid,text,text,text,integer,boolean,timestamptz,text)', 'EXECUTE'), 'authenticated can invoke chapter creation under RLS');
select ok(has_function_privilege('authenticated', 'public.scolaria_move_chapter(uuid,text)', 'EXECUTE'), 'authenticated can invoke chapter reorder under RLS');

select ok(has_schema_privilege('authenticated', 'private', 'USAGE'), 'authenticated can resolve approved private helpers');
select ok(not has_schema_privilege('anon', 'private', 'USAGE'), 'anon cannot resolve private helpers');
select ok(not has_table_privilege('authenticated', 'public.scolaria_chapters', 'DELETE'), 'chapters cannot bypass the atomic delete RPC');
select ok(not has_function_privilege('anon', 'public.scolaria_delete_chapter(uuid)', 'EXECUTE'), 'anon cannot delete chapters');
select ok(has_function_privilege('authenticated', 'public.scolaria_delete_chapter(uuid)', 'EXECUTE'), 'authenticated can invoke atomic chapter deletion');

select ok(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname = 'scolaria_touch_parent_course'
  ),
  'parent touch trigger is a narrow security definer'
);

select ok(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'scolaria_delete_chapter'
  ),
  'atomic chapter deletion owns its delete privilege'
);

select ok(
  position(
    'ch.status = ''published''' in pg_get_functiondef(
      'private.scolaria_can_read_resource_path(text)'::regprocedure
    )
  ) > 0,
  'secure downloads require an attached chapter to be published'
);

select ok(
  (
    select position('scolaria_can_upload_resource_path' in pg_get_expr(p.polqual, p.polrelid)) > 0
       and position('scolaria_can_read_resource_path' in pg_get_expr(p.polqual, p.polrelid)) > 0
    from pg_policy p
    where p.polrelid = 'storage.objects'::regclass
      and p.polname = 'scolarys_resources_storage_select'
  ),
  'storage reads support a safe upload handshake and authorized downloads'
);

select is(
  (
    select count(*)::integer
    from pg_constraint c
    where c.conname like 'scolaria\_%\_org\_fk' escape '\'
      and c.convalidated
  ),
  14,
  'all fourteen tenant-consistency foreign keys are validated'
);

select * from finish();
rollback;
