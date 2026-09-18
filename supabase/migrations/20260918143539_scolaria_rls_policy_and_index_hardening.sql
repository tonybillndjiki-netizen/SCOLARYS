
drop policy if exists scolaria_org_settings_write on public.scolaria_organization_settings;
create policy scolaria_org_settings_insert on public.scolaria_organization_settings
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'organization.manage'));
create policy scolaria_org_settings_update on public.scolaria_organization_settings
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'organization.manage'))
  with check (private.scolaria_has_permission(organization_id,'organization.manage'));
create policy scolaria_org_settings_delete on public.scolaria_organization_settings
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'organization.manage'));

drop policy if exists scolaria_roles_write on public.scolaria_roles;
create policy scolaria_roles_insert on public.scolaria_roles
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'roles.manage'));
create policy scolaria_roles_update on public.scolaria_roles
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'roles.manage'))
  with check (private.scolaria_has_permission(organization_id,'roles.manage'));
create policy scolaria_roles_delete on public.scolaria_roles
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'roles.manage'));

drop policy if exists scolaria_role_permissions_write on public.scolaria_role_permissions;
create policy scolaria_role_permissions_insert on public.scolaria_role_permissions
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'roles.manage'));
create policy scolaria_role_permissions_update on public.scolaria_role_permissions
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'roles.manage'))
  with check (private.scolaria_has_permission(organization_id,'roles.manage'));
create policy scolaria_role_permissions_delete on public.scolaria_role_permissions
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'roles.manage'));

drop policy if exists scolaria_members_write on public.scolaria_organization_members;
create policy scolaria_members_insert on public.scolaria_organization_members
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'users.manage'));
create policy scolaria_members_update on public.scolaria_organization_members
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'users.manage'))
  with check (private.scolaria_has_permission(organization_id,'users.manage'));
create policy scolaria_members_delete on public.scolaria_organization_members
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'users.manage'));

drop policy if exists scolaria_campuses_write on public.scolaria_campuses;
create policy scolaria_campuses_insert on public.scolaria_campuses
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'campuses.manage'));
create policy scolaria_campuses_update on public.scolaria_campuses
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'campuses.manage'))
  with check (private.scolaria_has_permission(organization_id,'campuses.manage'));
create policy scolaria_campuses_delete on public.scolaria_campuses
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'campuses.manage'));

drop policy if exists scolaria_academic_years_write on public.scolaria_academic_years;
create policy scolaria_academic_years_insert on public.scolaria_academic_years
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'academic.manage'));
create policy scolaria_academic_years_update on public.scolaria_academic_years
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'academic.manage'))
  with check (private.scolaria_has_permission(organization_id,'academic.manage'));
create policy scolaria_academic_years_delete on public.scolaria_academic_years
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'academic.manage'));

drop policy if exists scolaria_academic_periods_write on public.scolaria_academic_periods;
create policy scolaria_academic_periods_insert on public.scolaria_academic_periods
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'academic.manage'));
create policy scolaria_academic_periods_update on public.scolaria_academic_periods
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'academic.manage'))
  with check (private.scolaria_has_permission(organization_id,'academic.manage'));
create policy scolaria_academic_periods_delete on public.scolaria_academic_periods
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'academic.manage'));

drop policy if exists scolaria_programs_write on public.scolaria_programs;
create policy scolaria_programs_insert on public.scolaria_programs
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_programs_update on public.scolaria_programs
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'))
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_programs_delete on public.scolaria_programs
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'));

drop policy if exists scolaria_promotions_write on public.scolaria_promotions;
create policy scolaria_promotions_insert on public.scolaria_promotions
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_promotions_update on public.scolaria_promotions
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'))
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_promotions_delete on public.scolaria_promotions
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'));

drop policy if exists scolaria_classes_write on public.scolaria_classes;
create policy scolaria_classes_insert on public.scolaria_classes
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_classes_update on public.scolaria_classes
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'))
  with check (private.scolaria_has_permission(organization_id,'programs.manage'));
create policy scolaria_classes_delete on public.scolaria_classes
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'programs.manage'));

drop policy if exists scolaria_groups_write on public.scolaria_groups;
create policy scolaria_groups_insert on public.scolaria_groups
  for insert to authenticated
  with check ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'courses.manage')));
create policy scolaria_groups_update on public.scolaria_groups
  for update to authenticated
  using ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'courses.manage')))
  with check ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'courses.manage')));
create policy scolaria_groups_delete on public.scolaria_groups
  for delete to authenticated
  using ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'courses.manage')));

drop policy if exists scolaria_class_memberships_write on public.scolaria_class_memberships;
create policy scolaria_class_memberships_insert on public.scolaria_class_memberships
  for insert to authenticated
  with check ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'teachers.manage')));
create policy scolaria_class_memberships_update on public.scolaria_class_memberships
  for update to authenticated
  using ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'teachers.manage')))
  with check ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'teachers.manage')));
create policy scolaria_class_memberships_delete on public.scolaria_class_memberships
  for delete to authenticated
  using ((private.scolaria_has_permission(organization_id,'students.manage') or private.scolaria_has_permission(organization_id,'teachers.manage')));

drop policy if exists scolaria_units_write on public.scolaria_units;
create policy scolaria_units_insert on public.scolaria_units
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_units_update on public.scolaria_units
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'))
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_units_delete on public.scolaria_units
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'));

drop policy if exists scolaria_subunits_write on public.scolaria_subunits;
create policy scolaria_subunits_insert on public.scolaria_subunits
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_subunits_update on public.scolaria_subunits
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'))
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_subunits_delete on public.scolaria_subunits
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'));

drop policy if exists scolaria_subjects_write on public.scolaria_subjects;
create policy scolaria_subjects_insert on public.scolaria_subjects
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_subjects_update on public.scolaria_subjects
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'))
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_subjects_delete on public.scolaria_subjects
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'));

drop policy if exists scolaria_class_subjects_write on public.scolaria_class_subjects;
create policy scolaria_class_subjects_insert on public.scolaria_class_subjects
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_class_subjects_update on public.scolaria_class_subjects
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'))
  with check (private.scolaria_has_permission(organization_id,'subjects.manage'));
create policy scolaria_class_subjects_delete on public.scolaria_class_subjects
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'subjects.manage'));

drop policy if exists scolaria_invitations_write on public.scolaria_invitations;
create policy scolaria_invitations_insert on public.scolaria_invitations
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'users.manage'));
create policy scolaria_invitations_update on public.scolaria_invitations
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'users.manage'))
  with check (private.scolaria_has_permission(organization_id,'users.manage'));
create policy scolaria_invitations_delete on public.scolaria_invitations
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'users.manage'));

drop policy if exists scolaria_imports_write on public.scolaria_student_imports;
create policy scolaria_imports_insert on public.scolaria_student_imports
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'students.manage'));
create policy scolaria_imports_update on public.scolaria_student_imports
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'students.manage'))
  with check (private.scolaria_has_permission(organization_id,'students.manage'));
create policy scolaria_imports_delete on public.scolaria_student_imports
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'students.manage'));

drop policy if exists scolaria_import_rows_write on public.scolaria_student_import_rows;
create policy scolaria_import_rows_insert on public.scolaria_student_import_rows
  for insert to authenticated
  with check (private.scolaria_has_permission(organization_id,'students.manage'));
create policy scolaria_import_rows_update on public.scolaria_student_import_rows
  for update to authenticated
  using (private.scolaria_has_permission(organization_id,'students.manage'))
  with check (private.scolaria_has_permission(organization_id,'students.manage'));
create policy scolaria_import_rows_delete on public.scolaria_student_import_rows
  for delete to authenticated
  using (private.scolaria_has_permission(organization_id,'students.manage'));

create index if not exists scolaria_org_settings_created_by_idx on public.scolaria_organization_settings(created_by);
create index if not exists scolaria_orgs_created_by_idx on public.scolaria_organizations(created_by);
create index if not exists scolaria_roles_created_by_idx on public.scolaria_roles(created_by);
create index if not exists scolaria_role_permissions_org_idx on public.scolaria_role_permissions(organization_id);
create index if not exists scolaria_role_permissions_permission_idx on public.scolaria_role_permissions(permission_id);
create index if not exists scolaria_role_permissions_created_by_idx on public.scolaria_role_permissions(created_by);
create index if not exists scolaria_org_members_role_idx on public.scolaria_organization_members(role_id);
create index if not exists scolaria_org_members_created_by_idx on public.scolaria_organization_members(created_by);
create index if not exists scolaria_campuses_created_by_idx on public.scolaria_campuses(created_by);
create index if not exists scolaria_years_created_by_idx on public.scolaria_academic_years(created_by);
create index if not exists scolaria_periods_org_idx on public.scolaria_academic_periods(organization_id);
create index if not exists scolaria_periods_created_by_idx on public.scolaria_academic_periods(created_by);
create index if not exists scolaria_programs_campus_idx on public.scolaria_programs(campus_id);
create index if not exists scolaria_programs_created_by_idx on public.scolaria_programs(created_by);
create index if not exists scolaria_promotions_program_idx on public.scolaria_promotions(program_id);
create index if not exists scolaria_promotions_year_idx on public.scolaria_promotions(academic_year_id);
create index if not exists scolaria_promotions_created_by_idx on public.scolaria_promotions(created_by);
create index if not exists scolaria_classes_campus_idx on public.scolaria_classes(campus_id);
create index if not exists scolaria_classes_program_idx on public.scolaria_classes(program_id);
create index if not exists scolaria_classes_promotion_idx on public.scolaria_classes(promotion_id);
create index if not exists scolaria_classes_created_by_idx on public.scolaria_classes(created_by);
create index if not exists scolaria_groups_org_idx on public.scolaria_groups(organization_id);
create index if not exists scolaria_groups_created_by_idx on public.scolaria_groups(created_by);
create index if not exists scolaria_class_memberships_group_idx on public.scolaria_class_memberships(group_id);
create index if not exists scolaria_class_memberships_created_by_idx on public.scolaria_class_memberships(created_by);
create index if not exists scolaria_units_org_idx on public.scolaria_units(organization_id);
create index if not exists scolaria_units_created_by_idx on public.scolaria_units(created_by);
create index if not exists scolaria_subunits_org_idx on public.scolaria_subunits(organization_id);
create index if not exists scolaria_subunits_created_by_idx on public.scolaria_subunits(created_by);
create index if not exists scolaria_subjects_unit_idx on public.scolaria_subjects(unit_id);
create index if not exists scolaria_subjects_subunit_idx on public.scolaria_subjects(subunit_id);
create index if not exists scolaria_subjects_created_by_idx on public.scolaria_subjects(created_by);
create index if not exists scolaria_class_subjects_org_idx on public.scolaria_class_subjects(organization_id);
create index if not exists scolaria_class_subjects_subject_idx on public.scolaria_class_subjects(subject_id);
create index if not exists scolaria_class_subjects_period_idx on public.scolaria_class_subjects(academic_period_id);
create index if not exists scolaria_class_subjects_teacher_idx on public.scolaria_class_subjects(primary_teacher_id);
create index if not exists scolaria_class_subjects_created_by_idx on public.scolaria_class_subjects(created_by);
create index if not exists scolaria_invitations_role_idx on public.scolaria_invitations(role_id);
create index if not exists scolaria_invitations_class_idx on public.scolaria_invitations(class_id);
create index if not exists scolaria_invitations_invited_by_idx on public.scolaria_invitations(invited_by);
create index if not exists scolaria_invitations_accepted_by_idx on public.scolaria_invitations(accepted_by);
create index if not exists scolaria_invitations_created_by_idx on public.scolaria_invitations(created_by);
create index if not exists scolaria_imports_org_idx on public.scolaria_student_imports(organization_id);
create index if not exists scolaria_imports_class_idx on public.scolaria_student_imports(class_id);
create index if not exists scolaria_imports_created_by_idx on public.scolaria_student_imports(created_by);
create index if not exists scolaria_import_rows_org_idx on public.scolaria_student_import_rows(organization_id);
create index if not exists scolaria_import_rows_existing_user_idx on public.scolaria_student_import_rows(existing_user_id);
create index if not exists scolaria_import_rows_created_by_idx on public.scolaria_student_import_rows(created_by);
create index if not exists scolaria_audit_actor_idx on public.scolaria_audit_logs(actor_id);
