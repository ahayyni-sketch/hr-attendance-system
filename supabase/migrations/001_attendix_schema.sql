
-- ATTENDIX • Supabase schema
-- Jalankan seluruh file ini di Supabase Dashboard > SQL Editor.
-- Setelah berhasil, ubah kode undangan perusahaan pada bagian INSERT/UPDATE di bawah.

create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  office_lat double precision,
  office_lng double precision,
  geofence_radius_m integer not null default 150,
  created_at timestamptz not null default now()
);

create table if not exists public.employee_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete restrict,
  full_name text not null,
  nip text not null,
  email text not null,
  department text,
  position text,
  employee_type text not null default 'PKWTT',
  phone text,
  address text,
  emergency_contact_name text,
  emergency_contact_phone text,
  work_schedule text default '08:00 - 17:00',
  leave_quota integer not null default 12,
  leave_balance integer not null default 12,
  avatar_url text,
  joined_at date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(company_id, nip),
  unique(company_id, email)
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  employee_id uuid not null references public.employee_profiles(id) on delete cascade,
  attendance_date date not null,
  check_in_at timestamptz,
  check_out_at timestamptz,
  latitude double precision,
  longitude double precision,
  address text,
  photo_path text,
  photo_url text,
  checkout_photo_path text,
  checkout_photo_url text,
  notes text,
  status text not null default 'Hadir' check (status in ('Hadir','Terlambat','Izin','Sakit','Alpha')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(employee_id, attendance_date)
);

create index if not exists attendance_company_date_idx
  on public.attendance_records(company_id, attendance_date desc);
create index if not exists attendance_employee_date_idx
  on public.attendance_records(employee_id, attendance_date desc);

-- Otomatis membuat profil ketika akun Supabase Auth berhasil dibuat.
-- Pendaftaran hanya diterima jika kode perusahaan valid.
create or replace function public.handle_new_attendix_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company_id uuid;
  v_code text;
  v_name text;
  v_nip text;
begin
  v_code := upper(trim(coalesce(new.raw_user_meta_data->>'company_code','')));
  v_name := trim(coalesce(new.raw_user_meta_data->>'full_name',''));
  v_nip := trim(coalesce(new.raw_user_meta_data->>'nip',''));

  select id into v_company_id
  from public.companies
  where upper(join_code) = v_code;

  if v_company_id is null then
    raise exception 'Kode perusahaan tidak valid. Hubungi administrator perusahaan.';
  end if;
  if v_name = '' or v_nip = '' then
    raise exception 'Nama lengkap dan NIP wajib diisi.';
  end if;

  insert into public.employee_profiles
    (id, company_id, full_name, nip, email, department, position, employee_type)
  values
    (new.id, v_company_id, v_name, v_nip, new.email,
     new.raw_user_meta_data->>'department',
     new.raw_user_meta_data->>'position',
     coalesce(new.raw_user_meta_data->>'employee_type','PKWTT'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_attendix on auth.users;
create trigger on_auth_user_created_attendix
  after insert on auth.users
  for each row execute procedure public.handle_new_attendix_user();

alter table public.companies enable row level security;
alter table public.employee_profiles enable row level security;
alter table public.attendance_records enable row level security;

drop policy if exists "employees read own company" on public.companies;
create policy "employees read own company"
on public.companies for select to authenticated
using (id in (select company_id from public.employee_profiles where id = auth.uid()));

drop policy if exists "employees read own profile" on public.employee_profiles;
create policy "employees read own profile"
on public.employee_profiles for select to authenticated
using (id = auth.uid());

drop policy if exists "employees read own attendance" on public.attendance_records;
create policy "employees read own attendance"
on public.attendance_records for select to authenticated
using (employee_id = auth.uid());

drop policy if exists "employees insert own attendance" on public.attendance_records;
create policy "employees insert own attendance"
on public.attendance_records for insert to authenticated
with check (
  employee_id = auth.uid()
  and company_id = (select company_id from public.employee_profiles where id = auth.uid())
);

drop policy if exists "employees update own attendance" on public.attendance_records;
create policy "employees update own attendance"
on public.attendance_records for update to authenticated
using (employee_id = auth.uid())
with check (
  employee_id = auth.uid()
  and company_id = (select company_id from public.employee_profiles where id = auth.uid())
);

-- Private bucket. Foto tidak dapat diakses publik.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attendance-photos','attendance-photos',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false;

drop policy if exists "employee upload own attendance photo" on storage.objects;
create policy "employee upload own attendance photo"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'attendance-photos'
  and (storage.foldername(name))[1] in
    (select company_id::text from public.employee_profiles where id = auth.uid())
  and (storage.foldername(name))[2] = auth.uid()::text
);

drop policy if exists "employee read own attendance photo" on storage.objects;
create policy "employee read own attendance photo"
on storage.objects for select to authenticated
using (
  bucket_id = 'attendance-photos'
  and (storage.foldername(name))[1] in
    (select company_id::text from public.employee_profiles where id = auth.uid())
  and (storage.foldername(name))[2] = auth.uid()::text
);

-- Contoh perusahaan awal. Ganti nama dan join_code sesuai perusahaan.
-- Karyawan baru wajib mengetahui kode undangan ini.
insert into public.companies (name, join_code, geofence_radius_m)
values ('Perusahaan Anda', 'ATTENDIX-DAFTAR-001', 150)
on conflict (join_code) do nothing;

-- Pastikan hak akses tabel untuk peran aplikasi.
grant select on public.companies to authenticated;
grant select on public.employee_profiles to authenticated;
grant select, insert, update on public.attendance_records to authenticated;
