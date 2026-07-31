-- SAMARA CARE V17: CLINICAL ALERTS AND NOTIFICATION QUEUE
begin;

alter table public.patients add column if not exists notification_mobile text;
alter table public.patients add column if not exists whatsapp_opt_in boolean default true;
alter table public.patients add column if not exists sms_opt_in boolean default false;

create table if not exists public.clinical_alerts(
 id uuid primary key default gen_random_uuid(),
 patient_id uuid not null references public.patients(id) on delete cascade,
 vital_sign_id uuid references public.vital_signs(id) on delete set null,
 parameter text not null, value text not null, unit text,
 severity text not null check(severity in ('Warning','Critical')),
 status text not null default 'New' check(status in ('New','Acknowledged','Under Observation','Doctor Informed','Hospital Transfer','Resolved','Closed')),
 repeat_value text, action_taken text, doctor_informed boolean default false,
 family_informed boolean default false, acknowledged_by uuid references public.profiles(id),
 acknowledged_at timestamptz, closed_by uuid references public.profiles(id), closed_at timestamptz,
 closing_remarks text, created_by uuid references public.profiles(id), created_at timestamptz default now()
);

create table if not exists public.notification_queue(
 id uuid primary key default gen_random_uuid(), event_type text not null,
 patient_id uuid references public.patients(id) on delete cascade,
 channel text not null check(channel in ('WhatsApp','SMS','Email')),
 recipient text not null, title text, message text not null,
 status text not null default 'Pending' check(status in ('Pending','Processing','Sent','Failed','Cancelled')),
 provider_message_id text, error_message text, attempts integer default 0,
 scheduled_at timestamptz default now(), sent_at timestamptz,
 created_by uuid references public.profiles(id), created_at timestamptz default now()
);

alter table public.clinical_alerts enable row level security;
alter table public.notification_queue enable row level security;

do $$ declare p record; begin
 for p in select policyname from pg_policies where schemaname='public' and tablename in ('clinical_alerts','notification_queue') loop
  execute format('drop policy if exists %I on public.%I',p.policyname,case when p.tablename='clinical_alerts' then 'clinical_alerts' else 'notification_queue' end);
 end loop;
end $$;

create policy alerts_read on public.clinical_alerts for select to authenticated using(true);
create policy alerts_insert on public.clinical_alerts for insert to authenticated with check(created_by=auth.uid());
create policy alerts_update on public.clinical_alerts for update to authenticated using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.active and p.role in ('Admin','Manager','Nurse')));
create policy notifications_read on public.notification_queue for select to authenticated using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.active and p.role in ('Admin','Manager','Accounts','Nurse')));
create policy notifications_insert on public.notification_queue for insert to authenticated with check(created_by=auth.uid());
create policy notifications_update on public.notification_queue for update to authenticated using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.active and p.role in ('Admin','Manager','Accounts')));

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='clinical_alerts') then alter publication supabase_realtime add table public.clinical_alerts; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='notification_queue') then alter publication supabase_realtime add table public.notification_queue; end if;
end $$;

commit;
select 'SAMARA CARE V17 ALERTS AND NOTIFICATIONS COMPLETED SUCCESSFULLY' as result;
