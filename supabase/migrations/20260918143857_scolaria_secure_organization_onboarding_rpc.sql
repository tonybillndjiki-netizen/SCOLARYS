
create or replace function public.scolaria_create_organization(
  organization_name text,
  organization_slug text,
  organization_country_code text default 'FR',
  organization_city text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  new_org_id uuid;
  admin_role_id uuid;
  clean_name text := nullif(trim(organization_name), '');
  clean_slug text := lower(trim(organization_slug));
begin
  if uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;

  if clean_name is null then
    raise exception 'ORGANIZATION_NAME_REQUIRED';
  end if;

  if clean_slug is null or clean_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'INVALID_ORGANIZATION_SLUG';
  end if;

  if exists (
    select 1 from public.scolaria_organization_members
    where user_id = uid and status in ('active','pending','invited')
  ) and not private.scolaria_is_super_admin() then
    raise exception 'USER_ALREADY_HAS_ORGANIZATION';
  end if;

  insert into public.scolaria_organizations(
    name, slug, city, country_code, created_by
  )
  values (
    clean_name,
    clean_slug,
    nullif(trim(organization_city), ''),
    upper(coalesce(nullif(trim(organization_country_code), ''), 'FR')),
    uid
  )
  returning id into new_org_id;

  select id into admin_role_id
  from public.scolaria_roles
  where organization_id = new_org_id and key = 'school_admin'
  limit 1;

  if admin_role_id is null then
    raise exception 'ADMIN_ROLE_NOT_CREATED';
  end if;

  insert into public.scolaria_organization_members(
    organization_id, user_id, role_id, status, joined_at, created_by
  )
  values (
    new_org_id, uid, admin_role_id, 'active', now(), uid
  );

  return new_org_id;
end;
$$;

revoke all on function public.scolaria_create_organization(text,text,text,text) from public;
revoke all on function public.scolaria_create_organization(text,text,text,text) from anon;
grant execute on function public.scolaria_create_organization(text,text,text,text) to authenticated;
