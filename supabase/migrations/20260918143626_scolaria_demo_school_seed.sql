
update public.scolaria_profiles
set platform_role = 'super_admin', updated_at = now()
where id = (select id from auth.users order by created_at asc limit 1);

insert into public.scolaria_organizations
  (name,slug,legal_name,city,country_code,email,status,plan_key,created_by)
select
  'EduLink Demo School',
  'edulink-demo-school',
  'EduLink Demo School',
  'Paris',
  'FR',
  'demo@scolaria.app',
  'active',
  'enterprise',
  u.id
from (select id from auth.users order by created_at asc limit 1) u
where not exists (
  select 1 from public.scolaria_organizations where slug='edulink-demo-school'
);

update public.scolaria_organization_settings s
set
  primary_color = '#0F3D56',
  secondary_color = '#1D7A8C',
  feature_flags = jsonb_build_object('is_demo', true, 'ai_ready', true, 'google_integrations_ready', true),
  academic_structure = jsonb_build_object('use_units', true, 'use_subunits', true),
  updated_at = now()
from public.scolaria_organizations o
where s.organization_id=o.id and o.slug='edulink-demo-school';

insert into public.scolaria_organization_members
  (organization_id,user_id,role_id,status,joined_at,created_by)
select o.id,u.id,r.id,'active',now(),u.id
from public.scolaria_organizations o
cross join lateral (select id from auth.users order by created_at asc limit 1) u
join public.scolaria_roles r
  on r.organization_id=o.id and r.key='school_admin'
where o.slug='edulink-demo-school'
on conflict (organization_id,user_id) do update
set role_id=excluded.role_id,status='active',joined_at=coalesce(public.scolaria_organization_members.joined_at,now()),updated_at=now();

insert into public.scolaria_campuses
  (organization_id,name,code,city,country_code,is_active,created_by)
select o.id,'Paris','PARIS','Paris','FR',true,u.id
from public.scolaria_organizations o
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (organization_id,name) do nothing;

insert into public.scolaria_academic_years
  (organization_id,name,starts_on,ends_on,is_current,created_by)
select o.id,'2026-2027','2026-09-01','2027-08-31',true,u.id
from public.scolaria_organizations o
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (organization_id,name) do update
set starts_on=excluded.starts_on, ends_on=excluded.ends_on, is_current=true, updated_at=now();

insert into public.scolaria_academic_periods
  (organization_id,academic_year_id,name,period_type,ordinal,starts_on,ends_on,created_by)
select o.id,y.id,v.name,'semester',v.ordinal,v.starts_on,v.ends_on,u.id
from public.scolaria_organizations o
join public.scolaria_academic_years y on y.organization_id=o.id and y.name='2026-2027'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
cross join (values
  ('Semestre 1',1,'2026-09-01'::date,'2027-01-31'::date),
  ('Semestre 2',2,'2027-02-01'::date,'2027-08-31'::date)
) v(name,ordinal,starts_on,ends_on)
where o.slug='edulink-demo-school'
on conflict (academic_year_id,name) do nothing;

insert into public.scolaria_programs
  (organization_id,campus_id,code,name,level,description,is_active,created_by)
select o.id,c.id,v.code,v.name,v.level,v.description,true,u.id
from public.scolaria_organizations o
join public.scolaria_campuses c on c.organization_id=o.id and c.name='Paris'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
cross join (values
  ('B3-TC','Bachelor 3 — Tronc Commun','Bachelor 3','Tronc commun Bachelor 3 avec trois matières indépendantes.'),
  ('B3-CDUI','Bachelor 3 — CDUI','Bachelor 3','Concepteur Designer UI.'),
  ('M2-MC','M2 Marketing & Communication','Mastère 2','Programme structuré en UE et UV.')
) v(code,name,level,description)
where o.slug='edulink-demo-school'
on conflict (organization_id,name) do nothing;

insert into public.scolaria_promotions
  (organization_id,program_id,academic_year_id,name,starts_on,ends_on,status,created_by)
select o.id,p.id,y.id,'Promotion 2026-2027','2026-09-01','2027-08-31','active',u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id
join public.scolaria_academic_years y on y.organization_id=o.id and y.name='2026-2027'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (organization_id,program_id,academic_year_id,name) do nothing;

insert into public.scolaria_classes
  (organization_id,campus_id,program_id,promotion_id,name,code,status,created_by)
select o.id,c.id,p.id,pr.id,v.class_name,v.class_code,'active',u.id
from public.scolaria_organizations o
join public.scolaria_campuses c on c.organization_id=o.id and c.name='Paris'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
join (values
  ('Bachelor 3 — Tronc Commun','B3 Tronc Commun','B3-TC'),
  ('Bachelor 3 — CDUI','B3 CDUI','B3-CDUI'),
  ('M2 Marketing & Communication','M2 Marketing & Communication','M2-MC')
) v(program_name,class_name,class_code) on true
join public.scolaria_programs p on p.organization_id=o.id and p.name=v.program_name
join public.scolaria_promotions pr on pr.organization_id=o.id and pr.program_id=p.id and pr.name='Promotion 2026-2027'
where o.slug='edulink-demo-school'
on conflict (organization_id,name) do nothing;

insert into public.scolaria_subjects
  (organization_id,program_id,code,name,description,is_active,created_by)
select o.id,p.id,v.code,v.name,v.description,true,u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id and p.name='Bachelor 3 — Tronc Commun'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
cross join (values
  ('OUTILS-COLLAB','Outils collaboratifs','Outils numériques, collaboration et productivité.'),
  ('GESTION-PROJET','Gestion de projet','Méthodes, outils et pilotage de projet.'),
  ('SOFT-SKILLS','Soft Skills','Communication, posture professionnelle et collaboration.')
) v(code,name,description)
where o.slug='edulink-demo-school'
on conflict (program_id,name) do nothing;

insert into public.scolaria_subjects
  (organization_id,program_id,code,name,description,is_active,created_by)
select o.id,p.id,v.code,v.name,v.description,true,u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id and p.name='Bachelor 3 — CDUI'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
cross join (values
  ('CDUI-UX','UX/UI Design','Recherche utilisateur, wireframes et interfaces.'),
  ('CDUI-FRONT','Développement front-end','Intégration et développement d’interfaces web.'),
  ('CDUI-CMS','CMS & production web','Conception et publication de sites administrables.')
) v(code,name,description)
where o.slug='edulink-demo-school'
on conflict (program_id,name) do nothing;

insert into public.scolaria_units
  (organization_id,program_id,code,name,ordinal,created_by)
select o.id,p.id,v.code,v.name,v.ordinal,u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id and p.name='M2 Marketing & Communication'
cross join lateral (select id from auth.users order by created_at asc limit 1) u
cross join (values
  ('UE1','UE 1 — Stratégie marketing',1),
  ('UE2','UE 2 — Communication & contenus',2),
  ('UE3','UE 3 — Pilotage & performance',3)
) v(code,name,ordinal)
where o.slug='edulink-demo-school'
on conflict (program_id,name) do nothing;

insert into public.scolaria_subunits
  (organization_id,unit_id,code,name,ordinal,created_by)
select o.id,ue.id,v.uv_code,v.uv_name,v.ordinal,u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id and p.name='M2 Marketing & Communication'
join (values
  ('UE1','UV1','UV 1 — Audit & diagnostic marketing',1),
  ('UE1','UV2','UV 2 — Stratégie de marque',2),
  ('UE1','UV3','UV 3 — Plan marketing intégré',3),
  ('UE2','UV1','UV 1 — Communication 360°',1),
  ('UE2','UV2','UV 2 — Content & social media',2),
  ('UE2','UV3','UV 3 — Relations publiques',3),
  ('UE3','UV1','UV 1 — Data & analytics marketing',1),
  ('UE3','UV2','UV 2 — Budget & ROI',2),
  ('UE3','UV3','UV 3 — Management de projet marketing',3)
) v(ue_code,uv_code,uv_name,ordinal) on true
join public.scolaria_units ue on ue.program_id=p.id and ue.code=v.ue_code
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (unit_id,name) do nothing;

insert into public.scolaria_subjects
  (organization_id,program_id,unit_id,subunit_id,code,name,description,is_active,created_by)
select o.id,p.id,ue.id,uv.id,
       concat(ue.code,'-',uv.code),
       regexp_replace(uv.name,'^UV [123] — ',''),
       'Matière rattachée à ' || ue.name || ' / ' || uv.name,
       true,u.id
from public.scolaria_organizations o
join public.scolaria_programs p on p.organization_id=o.id and p.name='M2 Marketing & Communication'
join public.scolaria_units ue on ue.program_id=p.id
join public.scolaria_subunits uv on uv.unit_id=ue.id
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (program_id,name) do nothing;

insert into public.scolaria_class_subjects
  (organization_id,class_id,subject_id,academic_period_id,created_by)
select o.id,c.id,s.id,ap.id,u.id
from public.scolaria_organizations o
join public.scolaria_classes c on c.organization_id=o.id
join public.scolaria_programs p on p.id=c.program_id
join public.scolaria_subjects s on s.program_id=p.id
join public.scolaria_academic_years y on y.organization_id=o.id and y.is_current=true
join public.scolaria_academic_periods ap on ap.academic_year_id=y.id and ap.ordinal=1
cross join lateral (select id from auth.users order by created_at asc limit 1) u
where o.slug='edulink-demo-school'
on conflict (class_id,subject_id,academic_period_id) do nothing;
