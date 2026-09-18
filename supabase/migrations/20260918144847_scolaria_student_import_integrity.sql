
create unique index if not exists scolaria_profiles_email_unique
on public.scolaria_profiles (lower(email))
where email is not null;

create index if not exists scolaria_import_rows_status_idx
on public.scolaria_student_import_rows (import_id, validation_status, row_number);
