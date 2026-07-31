begin;

alter table public.vital_signs add column if not exists systolic_bp numeric;
alter table public.vital_signs add column if not exists diastolic_bp numeric;
alter table public.vital_signs add column if not exists pain_score numeric;

alter table public.patients add column if not exists height_cm numeric;
alter table public.patients add column if not exists weight_kg numeric;

commit;

select 'SAMARA CARE V21 CLINICAL AND DOCUMENT CAMERA UPGRADE COMPLETED SUCCESSFULLY' as result;
