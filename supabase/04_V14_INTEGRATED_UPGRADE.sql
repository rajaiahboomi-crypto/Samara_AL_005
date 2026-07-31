begin;

create table if not exists public.rooms_beds (
 id uuid primary key default gen_random_uuid(),
 room_no text not null,
 bed_no text not null,
 room_type text default 'Private',
 daily_rate numeric(12,2) default 0,
 status text default 'Available' check(status in ('Available','Reserved','Maintenance','Inactive')),
 updated_by uuid references public.profiles(id),
 created_at timestamptz default now(),
 updated_at timestamptz default now(),
 unique(room_no,bed_no)
);

alter table public.billing_transactions add column if not exists payment_mode text;
alter table public.billing_transactions add column if not exists reference_no text;
alter table public.billing_transactions add column if not exists receipt_no text;
alter table public.billing_transactions add column if not exists discount_reason text;
alter table public.billing_transactions add column if not exists discount_status text;
alter table public.billing_transactions add column if not exists discount_approved_by uuid references public.profiles(id);
alter table public.billing_transactions add column if not exists discount_approved_at timestamptz;

alter table public.rooms_beds enable row level security;

do $$ declare p record; begin
 for p in select policyname from pg_policies where schemaname='public' and tablename='rooms_beds' loop
  execute format('drop policy if exists %I on public.rooms_beds',p.policyname);
 end loop;
end $$;

create policy rooms_read on public.rooms_beds for select to authenticated using (true);
create policy rooms_admin_manager_insert on public.rooms_beds for insert to authenticated with check (public.samara_is_admin() or exists(select 1 from public.profiles where id=auth.uid() and role='Manager' and active=true));
create policy rooms_admin_manager_update on public.rooms_beds for update to authenticated using (public.samara_is_admin() or exists(select 1 from public.profiles where id=auth.uid() and role='Manager' and active=true)) with check (public.samara_is_admin() or exists(select 1 from public.profiles where id=auth.uid() and role='Manager' and active=true));

-- Seed 25 beds only when room master is empty.
insert into public.rooms_beds(room_no,bed_no,room_type,daily_rate,status)
select (100+ceil(n/2.0))::int::text, case when mod(n,2)=1 then 'A' else 'B' end, 'Twin Sharing',0,'Available'
from generate_series(1,25) n
where not exists(select 1 from public.rooms_beds);

-- Ensure realtime publication.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms_beds') then
  alter publication supabase_realtime add table public.rooms_beds;
 end if;
exception when duplicate_object then null; end $$;

commit;
select 'SAMARA CARE V14 INTEGRATED UPGRADE COMPLETED SUCCESSFULLY' as result;
