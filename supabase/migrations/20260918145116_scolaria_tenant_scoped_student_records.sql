
create table if not exists public.scolaria_student_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.scolaria_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  matricule text not null,
  first_name text not null,
  last_name text not null,
  email text not null,
  phone text,
  birth_date date,
  status text not null default 'active' check (status in ('invited','pending','active','suspended','archived')),
  source text not null default 'manual' check (source in ('manual','import','integration')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id),
  unique (organization_id, matricule)
);

create unique index if not exists scolaria_student_records_email_unique
on public.scolaria_student_records (organization_id, lower(email));

create index if not exists scolaria_student_records_user_idx
on public.scolaria_student_records (user_id, organization_id);

create index if not exists scolaria_student_records_status_idx
on public.scolaria_student_records (organization_id, status);

create index if not exists scolaria_student_records_created_by_idx
on public.scolaria_student_records (created_by);

drop trigger if exists scolaria_student_records_updated_at on public.scolaria_student_records;
create trigger scolaria_student_records_updated_at
before update on public.scolaria_student_records
for each row execute function public.scolaria_set_updated_at();

drop trigger if exists scolaria_student_records_audit on public.scolaria_student_records;
create trigger scolaria_student_records_audit
after insert or update or delete on public.scolaria_student_records
for each row execute function private.scolaria_audit_change();

alter table public.scolaria_student_records enable row level security;
revoke all on public.scolaria_student_records from anon;
grant select, insert, update, delete on public.scolaria_student_records to authenticated;

create policy scolaria_student_records_select
on public.scolaria_student_records for select
to authenticated
using (
  user_id = (select auth.uid())
  or private.scolaria_has_permission(organization_id,'students.view')
);

create policy scolaria_student_records_insert
on public.scolaria_student_records for insert
to authenticated
with check (private.scolaria_has_permission(organization_id,'students.manage'));

create policy scolaria_student_records_update
on public.scolaria_student_records for update
to authenticated
using (private.scolaria_has_permission(organization_id,'students.manage'))
with check (private.scolaria_has_permission(organization_id,'students.manage'));

create policy scolaria_student_records_delete
on public.scolaria_student_records for delete
to authenticated
using (private.scolaria_has_permission(organization_id,'students.manage'));
