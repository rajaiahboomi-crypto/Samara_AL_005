-- SAMARA CARE V15: CLINICAL, INCIDENTS, DOCUMENTS AND HOSPITAL DETAILS
begin;

alter table public.patients add column if not exists height_cm numeric(6,2);
alter table public.patients add column if not exists weight_kg numeric(6,2);
alter table public.patients add column if not exists hospital_name text;
alter table public.patients add column if not exists treating_doctor text;
alter table public.patients add column if not exists doctor_contact text;
alter table public.patients add column if not exists hospital_mr_no text;
alter table public.patients add column if not exists hospital_admission_date date;
alter table public.patients add column if not exists hospital_discharge_date date;
alter table public.patients add column if not exists hospital_notes text;

alter table public.vital_signs add column if not exists pulse integer;
alter table public.vital_signs add column if not exists respiration integer;
alter table public.vital_signs add column if not exists temperature_unit text default '°F';
alter table public.vital_signs add column if not exists blood_sugar_type text;
alter table public.vital_signs add column if not exists blood_sugar_value numeric(8,2);
alter table public.vital_signs add column if not exists remarks text;

create table if not exists public.incidents(
 id uuid primary key default gen_random_uuid(), incident_no text unique not null,
 patient_id uuid not null references public.patients(id) on delete cascade,
 incident_type text not null, incident_at timestamptz not null default now(), location text,
 description text not null, immediate_action text, injury_details text, witnesses text,
 doctor_informed boolean default false, family_informed boolean default false,
 hospital_transfer boolean default false, corrective_action text,
 status text not null default 'Open', reported_by uuid references public.profiles(id),
 reviewed_by uuid references public.profiles(id), closed_by uuid references public.profiles(id),
 closed_at timestamptz, created_at timestamptz default now()
);

create table if not exists public.patient_documents(
 id uuid primary key default gen_random_uuid(), patient_id uuid not null references public.patients(id) on delete cascade,
 category text not null, title text not null, document_date date, storage_path text unique not null,
 file_name text, mime_type text, file_size bigint, remarks text,
 uploaded_by uuid references public.profiles(id), uploaded_at timestamptz default now(), archived boolean default false
);

alter table public.incidents enable row level security;
alter table public.patient_documents enable row level security;

drop policy if exists incidents_read on public.incidents;
drop policy if exists incidents_insert on public.incidents;
drop policy if exists incidents_update on public.incidents;
drop policy if exists documents_read on public.patient_documents;
drop policy if exists documents_insert on public.patient_documents;
drop policy if exists documents_update on public.patient_documents;

create policy incidents_read on public.incidents for select to authenticated using(true);
create policy incidents_insert on public.incidents for insert to authenticated with check(reported_by=auth.uid());
create policy incidents_update on public.incidents for update to authenticated using(public.samara_is_admin() or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role in ('Manager','Nurse') and p.active=true));
create policy documents_read on public.patient_documents for select to authenticated using(true);
create policy documents_insert on public.patient_documents for insert to authenticated with check(uploaded_by=auth.uid());
create policy documents_update on public.patient_documents for update to authenticated using(public.samara_is_admin() or uploaded_by=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('patient-documents','patient-documents',false,15728640,array['application/pdf','image/jpeg','image/png','image/webp','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict(id) do update set public=false,file_size_limit=15728640;

drop policy if exists "Samara staff read patient documents" on storage.objects;
drop policy if exists "Samara clinical upload patient documents" on storage.objects;
drop policy if exists "Samara admin delete patient documents" on storage.objects;
create policy "Samara staff read patient documents" on storage.objects for select to authenticated using(bucket_id='patient-documents');
create policy "Samara clinical upload patient documents" on storage.objects for insert to authenticated with check(bucket_id='patient-documents' and exists(select 1 from public.profiles p where p.id=auth.uid() and p.active=true and p.role in ('Admin','Manager','Nurse')));
create policy "Samara admin delete patient documents" on storage.objects for delete to authenticated using(bucket_id='patient-documents' and public.samara_is_admin());

do $$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='incidents') then
  alter publication supabase_realtime add table public.incidents;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='patient_documents') then
  alter publication supabase_realtime add table public.patient_documents;
 end if;
end $$;

commit;
select 'SAMARA CARE V15 CLINICAL, INCIDENT AND DOCUMENT UPGRADE COMPLETED SUCCESSFULLY' as result;
