
create schema if not exists private;

create or replace function public.scolaria_set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.scolaria_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text,
  last_name text,
  display_name text,
  email text,
  phone text,
  avatar_url text,
  platform_role text check (platform_role in ('super_admin')),
  locale text not null default 'fr',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  legal_name text,
  logo_url text,
  address_line1 text,
  address_line2 text,
  postal_code text,
  city text,
  country_code char(2) not null default 'FR',
  phone text,
  email text,
  website text,
  status text not null default 'active' check (status in ('trial','active','suspended','archived')),
  plan_key text not null default 'essential' check (plan_key in ('essential','pro','enterprise')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_organization_settings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique references public.scolaria_organizations(id) on delete cascade,
  primary_color text,
  secondary_color text,
  favicon_url text,
  email_signature text,
  timezone text not null default 'Europe/Paris',
  date_format text not null default 'DD/MM/YYYY',
  academic_structure jsonb not null default '{"use_units":false,"use_subunits":false}'::jsonb,
  retention_policy jsonb not null default '{}'::jsonb,
  feature_flags jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  category text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  key text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, key)
);

create table if not exists public.scolaria_role_permissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  role_id uuid not null references public.scolaria_roles(id) on delete cascade,
  permission_id uuid not null references public.scolaria_permissions(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (role_id, permission_id)
);

create table if not exists public.scolaria_organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_id uuid not null references public.scolaria_roles(id) on delete restrict,
  status text not null default 'invited' check (status in ('invited','pending','active','suspended','archived')),
  joined_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table if not exists public.scolaria_campuses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  name text not null,
  code text,
  address_line1 text,
  address_line2 text,
  postal_code text,
  city text,
  country_code char(2) not null default 'FR',
  phone text,
  email text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.scolaria_academic_years (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  name text not null,
  starts_on date not null,
  ends_on date not null,
  is_current boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on > starts_on),
  unique (organization_id, name)
);

create unique index if not exists scolaria_one_current_year_per_org
on public.scolaria_academic_years(organization_id)
where is_current = true;

create table if not exists public.scolaria_academic_periods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  academic_year_id uuid not null references public.scolaria_academic_years(id) on delete cascade,
  name text not null,
  period_type text not null default 'semester' check (period_type in ('semester','trimester','quarter','custom')),
  ordinal smallint not null default 1 check (ordinal > 0),
  starts_on date not null,
  ends_on date not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (academic_year_id, name)
);

create table if not exists public.scolaria_programs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  campus_id uuid references public.scolaria_campuses(id) on delete set null,
  code text,
  name text not null,
  level text,
  description text,
  duration_months integer check (duration_months is null or duration_months > 0),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.scolaria_promotions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  program_id uuid not null references public.scolaria_programs(id) on delete cascade,
  academic_year_id uuid not null references public.scolaria_academic_years(id) on delete restrict,
  name text not null,
  starts_on date,
  ends_on date,
  status text not null default 'active' check (status in ('planned','active','closed','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, program_id, academic_year_id, name)
);

create table if not exists public.scolaria_classes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  campus_id uuid references public.scolaria_campuses(id) on delete set null,
  program_id uuid not null references public.scolaria_programs(id) on delete restrict,
  promotion_id uuid references public.scolaria_promotions(id) on delete set null,
  name text not null,
  code text,
  capacity integer check (capacity is null or capacity > 0),
  status text not null default 'active' check (status in ('planned','active','closed','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists public.scolaria_groups (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  class_id uuid not null references public.scolaria_classes(id) on delete cascade,
  name text not null,
  description text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, name)
);

create table if not exists public.scolaria_class_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  class_id uuid not null references public.scolaria_classes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  group_id uuid references public.scolaria_groups(id) on delete set null,
  membership_type text not null check (membership_type in ('student','teacher','manager')),
  matricule text,
  status text not null default 'active' check (status in ('active','suspended','archived')),
  enrolled_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, user_id, membership_type)
);

create unique index if not exists scolaria_unique_matricule_per_org
on public.scolaria_class_memberships(organization_id, matricule)
where matricule is not null;

create table if not exists public.scolaria_units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  program_id uuid not null references public.scolaria_programs(id) on delete cascade,
  code text,
  name text not null,
  ordinal integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (program_id, name)
);

create table if not exists public.scolaria_subunits (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  unit_id uuid not null references public.scolaria_units(id) on delete cascade,
  code text,
  name text not null,
  ordinal integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (unit_id, name)
);

create table if not exists public.scolaria_subjects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  program_id uuid not null references public.scolaria_programs(id) on delete cascade,
  unit_id uuid references public.scolaria_units(id) on delete set null,
  subunit_id uuid references public.scolaria_subunits(id) on delete set null,
  code text,
  name text not null,
  description text,
  credits numeric(6,2),
  coefficient numeric(8,3),
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (program_id, name)
);

create table if not exists public.scolaria_class_subjects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  class_id uuid not null references public.scolaria_classes(id) on delete cascade,
  subject_id uuid not null references public.scolaria_subjects(id) on delete cascade,
  academic_period_id uuid references public.scolaria_academic_periods(id) on delete set null,
  primary_teacher_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, subject_id, academic_period_id)
);

create table if not exists public.scolaria_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  email text not null,
  role_id uuid not null references public.scolaria_roles(id) on delete restrict,
  class_id uuid references public.scolaria_classes(id) on delete set null,
  invitation_type text not null default 'member' check (invitation_type in ('member','student','teacher','jury')),
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz,
  invited_by uuid references auth.users(id) on delete set null,
  accepted_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists scolaria_unique_pending_invite
on public.scolaria_invitations(organization_id, lower(email), invitation_type)
where status = 'pending';

create table if not exists public.scolaria_student_imports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  class_id uuid references public.scolaria_classes(id) on delete set null,
  filename text,
  source_type text not null check (source_type in ('csv','xlsx','paste','integration')),
  status text not null default 'uploaded' check (status in ('uploaded','mapped','validated','importing','completed','failed','cancelled')),
  mapping jsonb not null default '{}'::jsonb,
  summary jsonb not null default '{}'::jsonb,
  error_message text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.scolaria_student_import_rows (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  import_id uuid not null references public.scolaria_student_imports(id) on delete cascade,
  row_number integer not null,
  raw_data jsonb not null default '{}'::jsonb,
  normalized_data jsonb not null default '{}'::jsonb,
  validation_status text not null default 'pending' check (validation_status in ('pending','valid','duplicate','error','ignored','imported')),
  validation_errors jsonb not null default '[]'::jsonb,
  existing_user_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (import_id, row_number)
);

create table if not exists public.scolaria_audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.scolaria_organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  entity_table text not null,
  entity_id uuid,
  action text not null,
  old_values jsonb,
  new_values jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists scolaria_org_members_user_idx on public.scolaria_organization_members(user_id, organization_id);
create index if not exists scolaria_role_permissions_role_idx on public.scolaria_role_permissions(role_id, permission_id);
create index if not exists scolaria_campuses_org_idx on public.scolaria_campuses(organization_id);
create index if not exists scolaria_programs_org_idx on public.scolaria_programs(organization_id);
create index if not exists scolaria_classes_org_idx on public.scolaria_classes(organization_id, program_id);
create index if not exists scolaria_class_memberships_user_idx on public.scolaria_class_memberships(user_id, organization_id);
create index if not exists scolaria_subjects_org_idx on public.scolaria_subjects(organization_id, program_id);
create index if not exists scolaria_import_rows_import_idx on public.scolaria_student_import_rows(import_id, validation_status);
create index if not exists scolaria_audit_logs_org_created_idx on public.scolaria_audit_logs(organization_id, created_at desc);

create or replace function private.scolaria_is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.scolaria_profiles p
    where p.id = (select auth.uid())
      and p.platform_role = 'super_admin'
  );
$$;

create or replace function private.scolaria_user_in_org(target_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_organization_members m
    where m.organization_id = target_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function private.scolaria_has_permission(target_org uuid, permission_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_organization_members m
    join public.scolaria_role_permissions rp
      on rp.organization_id = m.organization_id
     and rp.role_id = m.role_id
    join public.scolaria_permissions p
      on p.id = rp.permission_id
    where m.organization_id = target_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and p.code = permission_code
  );
$$;

create or replace function private.scolaria_shares_org(other_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.scolaria_is_super_admin()
  or exists (
    select 1
    from public.scolaria_organization_members mine
    join public.scolaria_organization_members theirs
      on theirs.organization_id = mine.organization_id
    where mine.user_id = (select auth.uid())
      and mine.status = 'active'
      and theirs.user_id = other_user
      and theirs.status in ('active','pending','invited')
  );
$$;

revoke all on function private.scolaria_is_super_admin() from public;
revoke all on function private.scolaria_user_in_org(uuid) from public;
revoke all on function private.scolaria_has_permission(uuid,text) from public;
revoke all on function private.scolaria_shares_org(uuid) from public;
grant execute on function private.scolaria_is_super_admin() to authenticated;
grant execute on function private.scolaria_user_in_org(uuid) to authenticated;
grant execute on function private.scolaria_has_permission(uuid,text) to authenticated;
grant execute on function private.scolaria_shares_org(uuid) to authenticated;

insert into public.scolaria_permissions(code,label,category,description) values
('organization.view','Voir l’établissement','Établissement','Consulter les informations établissement'),
('organization.manage','Gérer l’établissement','Établissement','Modifier les informations et paramètres établissement'),
('users.view','Voir les utilisateurs','Utilisateurs','Consulter les membres de l’établissement'),
('users.manage','Gérer les utilisateurs','Utilisateurs','Inviter, modifier, suspendre et archiver des utilisateurs'),
('roles.manage','Gérer les rôles','Sécurité','Configurer les rôles et permissions'),
('campuses.manage','Gérer les campus','Structure','Créer et modifier les campus'),
('academic.manage','Gérer les années académiques','Structure','Configurer années et périodes académiques'),
('programs.manage','Gérer les formations','Pédagogie','Créer et modifier formations, promotions et classes'),
('students.view','Voir les étudiants','Étudiants','Consulter les étudiants'),
('students.manage','Gérer les étudiants','Étudiants','Importer, inscrire, déplacer et archiver des étudiants'),
('teachers.view','Voir les enseignants','Enseignants','Consulter les enseignants'),
('teachers.manage','Gérer les enseignants','Enseignants','Affecter et administrer les enseignants'),
('subjects.manage','Gérer les matières','Pédagogie','Créer et affecter UE, UV et matières'),
('courses.manage','Gérer les cours','LMS','Créer, modifier et publier des cours'),
('assessments.manage','Gérer les évaluations','Évaluations','Créer et publier quiz, devoirs, CC et examens'),
('grades.manage','Gérer les notes','Académique','Saisir et modifier les notes'),
('attendance.manage','Gérer les présences','Académique','Créer les appels et modifier les présences'),
('competencies.manage','Gérer les compétences','Académique','Évaluer les compétences'),
('report_cards.manage','Gérer les bulletins','Académique','Préparer, valider et publier les bulletins'),
('analytics.view','Voir les analytics','Pilotage','Consulter les indicateurs et statistiques'),
('communications.manage','Gérer la communication','Communication','Créer annonces et messages'),
('integrations.manage','Gérer les intégrations','Intégrations','Configurer les connexions externes')
on conflict (code) do update set
  label = excluded.label,
  category = excluded.category,
  description = excluded.description,
  updated_at = now();

create or replace function private.scolaria_seed_org_roles()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  r_admin uuid;
  r_direction uuid;
  r_manager uuid;
  r_teacher uuid;
  r_jury uuid;
  r_student uuid;
begin
  insert into public.scolaria_roles(organization_id,key,name,description,is_system,created_by)
  values
    (new.id,'school_admin','Administrateur école','Administration complète de l’établissement',true,new.created_by),
    (new.id,'pedagogical_direction','Direction pédagogique','Pilotage pédagogique, notes, bulletins et statistiques',true,new.created_by),
    (new.id,'training_manager','Responsable de formation','Gestion des formations attribuées',true,new.created_by),
    (new.id,'teacher','Enseignant','Gestion des cours, évaluations, présences et notes',true,new.created_by),
    (new.id,'jury','Jury / correcteur','Accès aux évaluations et soutenances attribuées',true,new.created_by),
    (new.id,'student','Étudiant','Accès aux éléments pédagogiques qui lui sont attribués',true,new.created_by);

  select id into r_admin from public.scolaria_roles where organization_id=new.id and key='school_admin';
  select id into r_direction from public.scolaria_roles where organization_id=new.id and key='pedagogical_direction';
  select id into r_manager from public.scolaria_roles where organization_id=new.id and key='training_manager';
  select id into r_teacher from public.scolaria_roles where organization_id=new.id and key='teacher';
  select id into r_jury from public.scolaria_roles where organization_id=new.id and key='jury';
  select id into r_student from public.scolaria_roles where organization_id=new.id and key='student';

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_admin, p.id, new.created_by from public.scolaria_permissions p;

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_direction, p.id, new.created_by
  from public.scolaria_permissions p
  where p.code in (
    'organization.view','users.view','campuses.manage','academic.manage','programs.manage',
    'students.view','teachers.view','subjects.manage','courses.manage','assessments.manage',
    'grades.manage','attendance.manage','competencies.manage','report_cards.manage',
    'analytics.view','communications.manage'
  );

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_manager, p.id, new.created_by
  from public.scolaria_permissions p
  where p.code in (
    'organization.view','users.view','programs.manage','students.view','teachers.view',
    'subjects.manage','courses.manage','assessments.manage','grades.manage',
    'attendance.manage','competencies.manage','analytics.view','communications.manage'
  );

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_teacher, p.id, new.created_by
  from public.scolaria_permissions p
  where p.code in (
    'organization.view','students.view','courses.manage','assessments.manage',
    'grades.manage','attendance.manage','competencies.manage','communications.manage'
  );

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_jury, p.id, new.created_by
  from public.scolaria_permissions p
  where p.code in ('organization.view','students.view','assessments.manage','grades.manage');

  insert into public.scolaria_role_permissions(organization_id,role_id,permission_id,created_by)
  select new.id, r_student, p.id, new.created_by
  from public.scolaria_permissions p
  where p.code in ('organization.view');

  insert into public.scolaria_organization_settings(organization_id, created_by)
  values (new.id, new.created_by)
  on conflict (organization_id) do nothing;

  return new;
end;
$$;

revoke all on function private.scolaria_seed_org_roles() from public;

drop trigger if exists scolaria_seed_org_roles_after_insert on public.scolaria_organizations;
create trigger scolaria_seed_org_roles_after_insert
after insert on public.scolaria_organizations
for each row execute function private.scolaria_seed_org_roles();

create or replace function private.scolaria_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.scolaria_profiles(id,first_name,last_name,display_name,email)
  values (
    new.id,
    nullif(new.raw_user_meta_data->>'first_name',''),
    nullif(new.raw_user_meta_data->>'last_name',''),
    coalesce(nullif(new.raw_user_meta_data->>'display_name',''), nullif(new.raw_user_meta_data->>'full_name',''), split_part(new.email,'@',1)),
    new.email
  )
  on conflict (id) do update set
    email = excluded.email,
    updated_at = now();
  return new;
end;
$$;

revoke all on function private.scolaria_handle_new_user() from public;

drop trigger if exists scolaria_auth_user_created on auth.users;
create trigger scolaria_auth_user_created
after insert on auth.users
for each row execute function private.scolaria_handle_new_user();

insert into public.scolaria_profiles(id,display_name,email)
select u.id,
       coalesce(nullif(u.raw_user_meta_data->>'display_name',''), nullif(u.raw_user_meta_data->>'full_name',''), split_part(u.email,'@',1)),
       u.email
from auth.users u
on conflict (id) do nothing;

create or replace function private.scolaria_audit_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  org uuid;
  row_id uuid;
begin
  org := coalesce(
    case when tg_op = 'DELETE' then (to_jsonb(old)->>'organization_id')::uuid else (to_jsonb(new)->>'organization_id')::uuid end,
    null
  );
  row_id := coalesce(
    case when tg_op = 'DELETE' then (to_jsonb(old)->>'id')::uuid else (to_jsonb(new)->>'id')::uuid end,
    null
  );

  insert into public.scolaria_audit_logs(organization_id,actor_id,entity_table,entity_id,action,old_values,new_values)
  values (
    org,
    (select auth.uid()),
    tg_table_name,
    row_id,
    lower(tg_op),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );

  return coalesce(new, old);
end;
$$;

revoke all on function private.scolaria_audit_change() from public;

do $$
declare
  t text;
begin
  foreach t in array array[
    'scolaria_organization_members',
    'scolaria_roles',
    'scolaria_role_permissions',
    'scolaria_class_memberships',
    'scolaria_invitations'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_audit', t);
    execute format(
      'create trigger %I after insert or update or delete on public.%I for each row execute function private.scolaria_audit_change()',
      t || '_audit', t
    );
  end loop;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'scolaria_profiles','scolaria_organizations','scolaria_organization_settings','scolaria_permissions',
    'scolaria_roles','scolaria_role_permissions','scolaria_organization_members','scolaria_campuses',
    'scolaria_academic_years','scolaria_academic_periods','scolaria_programs','scolaria_promotions',
    'scolaria_classes','scolaria_groups','scolaria_class_memberships','scolaria_units','scolaria_subunits',
    'scolaria_subjects','scolaria_class_subjects','scolaria_invitations','scolaria_student_imports',
    'scolaria_student_import_rows'
  ]
  loop
    execute format('drop trigger if exists %I on public.%I', t || '_updated_at', t);
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.scolaria_set_updated_at()',
      t || '_updated_at', t
    );
  end loop;
end $$;

alter table public.scolaria_profiles enable row level security;
alter table public.scolaria_organizations enable row level security;
alter table public.scolaria_organization_settings enable row level security;
alter table public.scolaria_permissions enable row level security;
alter table public.scolaria_roles enable row level security;
alter table public.scolaria_role_permissions enable row level security;
alter table public.scolaria_organization_members enable row level security;
alter table public.scolaria_campuses enable row level security;
alter table public.scolaria_academic_years enable row level security;
alter table public.scolaria_academic_periods enable row level security;
alter table public.scolaria_programs enable row level security;
alter table public.scolaria_promotions enable row level security;
alter table public.scolaria_classes enable row level security;
alter table public.scolaria_groups enable row level security;
alter table public.scolaria_class_memberships enable row level security;
alter table public.scolaria_units enable row level security;
alter table public.scolaria_subunits enable row level security;
alter table public.scolaria_subjects enable row level security;
alter table public.scolaria_class_subjects enable row level security;
alter table public.scolaria_invitations enable row level security;
alter table public.scolaria_student_imports enable row level security;
alter table public.scolaria_student_import_rows enable row level security;
alter table public.scolaria_audit_logs enable row level security;

revoke all on all tables in schema public from anon;
grant select, update on public.scolaria_profiles to authenticated;
grant select on public.scolaria_permissions to authenticated;
grant select, insert, update, delete on
  public.scolaria_organizations,
  public.scolaria_organization_settings,
  public.scolaria_roles,
  public.scolaria_role_permissions,
  public.scolaria_organization_members,
  public.scolaria_campuses,
  public.scolaria_academic_years,
  public.scolaria_academic_periods,
  public.scolaria_programs,
  public.scolaria_promotions,
  public.scolaria_classes,
  public.scolaria_groups,
  public.scolaria_class_memberships,
  public.scolaria_units,
  public.scolaria_subunits,
  public.scolaria_subjects,
  public.scolaria_class_subjects,
  public.scolaria_invitations,
  public.scolaria_student_imports,
  public.scolaria_student_import_rows
to authenticated;
grant select on public.scolaria_audit_logs to authenticated;

create policy scolaria_profiles_select
on public.scolaria_profiles for select
to authenticated
using ((select auth.uid()) = id or private.scolaria_shares_org(id));

create policy scolaria_profiles_update_self
on public.scolaria_profiles for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy scolaria_permissions_select
on public.scolaria_permissions for select
to authenticated
using (true);

create policy scolaria_organizations_select
on public.scolaria_organizations for select
to authenticated
using (private.scolaria_user_in_org(id));

create policy scolaria_organizations_update
on public.scolaria_organizations for update
to authenticated
using (private.scolaria_has_permission(id,'organization.manage'))
with check (private.scolaria_has_permission(id,'organization.manage'));

create policy scolaria_org_settings_select
on public.scolaria_organization_settings for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_org_settings_write
on public.scolaria_organization_settings for all
to authenticated
using (private.scolaria_has_permission(organization_id,'organization.manage'))
with check (private.scolaria_has_permission(organization_id,'organization.manage'));

create policy scolaria_roles_select
on public.scolaria_roles for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_roles_write
on public.scolaria_roles for all
to authenticated
using (private.scolaria_has_permission(organization_id,'roles.manage'))
with check (private.scolaria_has_permission(organization_id,'roles.manage'));

create policy scolaria_role_permissions_select
on public.scolaria_role_permissions for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_role_permissions_write
on public.scolaria_role_permissions for all
to authenticated
using (private.scolaria_has_permission(organization_id,'roles.manage'))
with check (private.scolaria_has_permission(organization_id,'roles.manage'));

create policy scolaria_members_select
on public.scolaria_organization_members for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.scolaria_has_permission(organization_id,'users.view')
);

create policy scolaria_members_write
on public.scolaria_organization_members for all
to authenticated
using (private.scolaria_has_permission(organization_id,'users.manage'))
with check (private.scolaria_has_permission(organization_id,'users.manage'));

create policy scolaria_campuses_select
on public.scolaria_campuses for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_campuses_write
on public.scolaria_campuses for all
to authenticated
using (private.scolaria_has_permission(organization_id,'campuses.manage'))
with check (private.scolaria_has_permission(organization_id,'campuses.manage'));

create policy scolaria_academic_years_select
on public.scolaria_academic_years for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_academic_years_write
on public.scolaria_academic_years for all
to authenticated
using (private.scolaria_has_permission(organization_id,'academic.manage'))
with check (private.scolaria_has_permission(organization_id,'academic.manage'));

create policy scolaria_academic_periods_select
on public.scolaria_academic_periods for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_academic_periods_write
on public.scolaria_academic_periods for all
to authenticated
using (private.scolaria_has_permission(organization_id,'academic.manage'))
with check (private.scolaria_has_permission(organization_id,'academic.manage'));

create policy scolaria_programs_select
on public.scolaria_programs for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_programs_write
on public.scolaria_programs for all
to authenticated
using (private.scolaria_has_permission(organization_id,'programs.manage'))
with check (private.scolaria_has_permission(organization_id,'programs.manage'));

create policy scolaria_promotions_select
on public.scolaria_promotions for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_promotions_write
on public.scolaria_promotions for all
to authenticated
using (private.scolaria_has_permission(organization_id,'programs.manage'))
with check (private.scolaria_has_permission(organization_id,'programs.manage'));

create policy scolaria_classes_select
on public.scolaria_classes for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_classes_write
on public.scolaria_classes for all
to authenticated
using (private.scolaria_has_permission(organization_id,'programs.manage'))
with check (private.scolaria_has_permission(organization_id,'programs.manage'));

create policy scolaria_groups_select
on public.scolaria_groups for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_groups_write
on public.scolaria_groups for all
to authenticated
using (
  private.scolaria_has_permission(organization_id,'students.manage')
  or private.scolaria_has_permission(organization_id,'courses.manage')
)
with check (
  private.scolaria_has_permission(organization_id,'students.manage')
  or private.scolaria_has_permission(organization_id,'courses.manage')
);

create policy scolaria_class_memberships_select
on public.scolaria_class_memberships for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.scolaria_has_permission(organization_id,'students.view')
  or private.scolaria_has_permission(organization_id,'teachers.view')
);

create policy scolaria_class_memberships_write
on public.scolaria_class_memberships for all
to authenticated
using (
  private.scolaria_has_permission(organization_id,'students.manage')
  or private.scolaria_has_permission(organization_id,'teachers.manage')
)
with check (
  private.scolaria_has_permission(organization_id,'students.manage')
  or private.scolaria_has_permission(organization_id,'teachers.manage')
);

create policy scolaria_units_select
on public.scolaria_units for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_units_write
on public.scolaria_units for all
to authenticated
using (private.scolaria_has_permission(organization_id,'subjects.manage'))
with check (private.scolaria_has_permission(organization_id,'subjects.manage'));

create policy scolaria_subunits_select
on public.scolaria_subunits for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_subunits_write
on public.scolaria_subunits for all
to authenticated
using (private.scolaria_has_permission(organization_id,'subjects.manage'))
with check (private.scolaria_has_permission(organization_id,'subjects.manage'));

create policy scolaria_subjects_select
on public.scolaria_subjects for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_subjects_write
on public.scolaria_subjects for all
to authenticated
using (private.scolaria_has_permission(organization_id,'subjects.manage'))
with check (private.scolaria_has_permission(organization_id,'subjects.manage'));

create policy scolaria_class_subjects_select
on public.scolaria_class_subjects for select
to authenticated
using (private.scolaria_user_in_org(organization_id));

create policy scolaria_class_subjects_write
on public.scolaria_class_subjects for all
to authenticated
using (private.scolaria_has_permission(organization_id,'subjects.manage'))
with check (private.scolaria_has_permission(organization_id,'subjects.manage'));

create policy scolaria_invitations_select
on public.scolaria_invitations for select
to authenticated
using (private.scolaria_has_permission(organization_id,'users.view'));

create policy scolaria_invitations_write
on public.scolaria_invitations for all
to authenticated
using (private.scolaria_has_permission(organization_id,'users.manage'))
with check (private.scolaria_has_permission(organization_id,'users.manage'));

create policy scolaria_imports_select
on public.scolaria_student_imports for select
to authenticated
using (private.scolaria_has_permission(organization_id,'students.view'));

create policy scolaria_imports_write
on public.scolaria_student_imports for all
to authenticated
using (private.scolaria_has_permission(organization_id,'students.manage'))
with check (private.scolaria_has_permission(organization_id,'students.manage'));

create policy scolaria_import_rows_select
on public.scolaria_student_import_rows for select
to authenticated
using (private.scolaria_has_permission(organization_id,'students.view'));

create policy scolaria_import_rows_write
on public.scolaria_student_import_rows for all
to authenticated
using (private.scolaria_has_permission(organization_id,'students.manage'))
with check (private.scolaria_has_permission(organization_id,'students.manage'));

create policy scolaria_audit_logs_select
on public.scolaria_audit_logs for select
to authenticated
using (
  organization_id is not null
  and (
    private.scolaria_is_super_admin()
    or private.scolaria_has_permission(organization_id,'organization.manage')
    or private.scolaria_has_permission(organization_id,'report_cards.manage')
  )
);
