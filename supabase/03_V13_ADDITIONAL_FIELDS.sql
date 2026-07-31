begin;

alter table public.profiles
add column if not exists address text;

alter table public.patients
add column if not exists referred_by text;

alter table public.patients
add column if not exists reference_contact text;

commit;

select 'SAMARA CARE V13 ADDITIONAL FIELDS COMPLETED SUCCESSFULLY' as result;
