-- Recommended extensions
create extension if not exists "pgcrypto";

-- =========================
-- ENUMS
-- =========================
do $$ begin
  create type user_role as enum ('Fleet Manager', 'Driver', 'Maintenance Personnel');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type vehicle_status as enum ('Active', 'In Service', 'Idle', 'Out of Service');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type document_type as enum ('RC', 'Insurance', 'PUC', 'Permit');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type trip_status as enum ('Scheduled', 'In Progress', 'Completed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type work_order_status as enum ('Open', 'In Progress', 'Waiting Parts', 'Completed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type work_order_priority as enum ('Low', 'Medium', 'High', 'Critical');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type inspection_type as enum ('Pre-Trip', 'Post-Trip');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type maintenance_schedule_status as enum ('Upcoming', 'Overdue', 'Completed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type defect_status as enum ('Pending', 'Approved', 'In Repair', 'Completed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type notification_category as enum ('Info', 'Warning', 'Critical', 'Success', 'Maintenance');
exception when duplicate_object then null;
end $$;

-- Add Maintenance value to existing databases that already have the enum
do $$ begin
  alter type notification_category add value if not exists 'Maintenance';
exception when others then null;
end $$;


-- =========================
-- TIMESTAMP HELPER
-- =========================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =========================
-- ORGANIZATIONS
-- =========================
create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  industry text not null,
  fleet_size integer not null default 0 check (fleet_size >= 0),
  compliance_score integer not null default 0 check (compliance_score between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- USERS / PROFILES
-- Use auth.users.id as the primary key when integrating auth
-- =========================
create table if not exists profiles (
  id uuid primary key,
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  role user_role not null,
  email text not null unique,
  phone text not null,
  title text not null,
  assigned_vehicle_id uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- VEHICLES
-- =========================
create table if not exists vehicles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  display_name text not null,
  plate_number text not null unique,
  model text not null,
  status vehicle_status not null,
  fuel_level integer not null default 0 check (fuel_level between 0 and 100),
  odometer integer not null default 0 check (odometer >= 0),
  assigned_driver_id uuid null references profiles(id) on delete set null,
  next_service_date timestamptz not null,
  utilization integer not null default 0 check (utilization between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles 
  drop constraint if exists profiles_assigned_vehicle_id_fkey;

alter table profiles
  add constraint profiles_assigned_vehicle_id_fkey
  foreign key (assigned_vehicle_id)
  references vehicles(id)
  on delete set null;

-- =========================
-- VEHICLE DOCUMENTS
-- =========================
create table if not exists vehicle_documents (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  type document_type not null,
  document_number text not null,
  expiry_date timestamptz not null,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- TRIPS
-- =========================
create table if not exists trips (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references profiles(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  origin text not null,
  destination text not null,
  start_date timestamptz not null,
  end_date timestamptz null,
  distance_km numeric(10,2) not null default 0 check (distance_km >= 0),
  status trip_status not null,
  safety_score integer null,
  route_details text null,
  notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- INSPECTION RECORDS
-- =========================
create table if not exists inspection_records (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references profiles(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  type inspection_type not null,
  date timestamptz not null,
  notes text not null default '',
  passed boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists inspection_items (
  id uuid primary key default gen_random_uuid(),
  inspection_record_id uuid not null references inspection_records(id) on delete cascade,
  title text not null,
  is_checked boolean not null default false,
  created_at timestamptz not null default now()
);

-- =========================
-- DEFECT REPORTS
-- =========================
create table if not exists defect_reports (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references profiles(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  severity work_order_priority not null,
  description text not null,
  reported_date timestamptz not null,
  is_resolved boolean not null default false,
  title text null,
  images text[] null,
  status defect_status not null default 'Pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- WORK ORDERS
-- =========================
create table if not exists work_orders (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  assigned_maintenance_id uuid null references profiles(id) on delete set null,
  title text not null,
  details text not null,
  priority work_order_priority not null,
  status work_order_status not null,
  scheduled_date timestamptz not null,
  completed_date timestamptz null,
  estimated_cost numeric(12,2) not null default 0 check (estimated_cost >= 0),
  repair_summary text not null default '',
  overdue_alert_fired boolean not null default false,
  defect_report_id uuid null references defect_reports(id) on delete set null,
  images text[] null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- MAINTENANCE SCHEDULES
-- =========================
create table if not exists maintenance_schedules (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  service_type text not null,
  due_date timestamptz not null,
  status maintenance_schedule_status not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- NOTIFICATIONS
-- =========================
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid null references profiles(id) on delete cascade,
  role_target user_role null,
  title text not null,
  message text not null,
  date timestamptz not null,
  is_read boolean not null default false,
  category notification_category not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================
-- CHAT MESSAGES
-- =========================
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid null references profiles(id) on delete cascade,
  work_order_id uuid null references work_orders(id) on delete cascade,
  message text not null,
  timestamp timestamptz not null default now(),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_chat_messages_work_order_id on chat_messages(work_order_id);

-- =========================
-- BROADCAST MESSAGES
-- =========================
create table if not exists broadcast_messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_broadcast_messages_organization_id on broadcast_messages(organization_id);

-- =========================
-- FUEL TRANSACTIONS
-- =========================
create table if not exists "fuelTransactions" (
  "transactionID" uuid primary key default gen_random_uuid(),
  "vehicleID" uuid references vehicles(id) on delete set null,
  "driverID" uuid references profiles(id) on delete set null,
  "tripID" uuid references trips(id) on delete set null,
  "manualAmount" numeric(12,2) null,
  "odometerReading" integer null,
  "receiptImageUrl" text null,
  "timestamp" timestamptz not null default now(),
  "verificationStatus" text not null default 'Pending',
  "rejectionReason" text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_fuel_transactions_vehicle_id on "fuelTransactions"("vehicleID");
create index if not exists idx_fuel_transactions_driver_id on "fuelTransactions"("driverID");

-- =========================
-- =========================
-- SOS ALERTS
-- =========================
create table if not exists sos_alerts (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references profiles(id) on delete cascade,
  driver_name text not null,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  vehicle_number text not null,
  emergency_type text not null,
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  description text null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now()
);

create index if not exists idx_sos_alerts_driver_id on sos_alerts(driver_id);
create index if not exists idx_sos_alerts_vehicle_id on sos_alerts(vehicle_id);

-- =========================
-- INDEXES
-- =========================
create index if not exists idx_profiles_organization_id on profiles(organization_id);
create index if not exists idx_profiles_role on profiles(role);
create index if not exists idx_vehicles_organization_id on vehicles(organization_id);
create index if not exists idx_vehicles_assigned_driver_id on vehicles(assigned_driver_id);
create index if not exists idx_vehicle_documents_vehicle_id on vehicle_documents(vehicle_id);
create index if not exists idx_trips_driver_id on trips(driver_id);
create index if not exists idx_trips_vehicle_id on trips(vehicle_id);
create index if not exists idx_inspection_records_driver_id on inspection_records(driver_id);
create index if not exists idx_inspection_records_vehicle_id on inspection_records(vehicle_id);
create index if not exists idx_inspection_items_record_id on inspection_items(inspection_record_id);
create index if not exists idx_defect_reports_driver_id on defect_reports(driver_id);
create index if not exists idx_defect_reports_vehicle_id on defect_reports(vehicle_id);
create index if not exists idx_work_orders_vehicle_id on work_orders(vehicle_id);
create index if not exists idx_work_orders_assigned_maintenance_id on work_orders(assigned_maintenance_id);
create index if not exists idx_maintenance_schedules_vehicle_id on maintenance_schedules(vehicle_id);
create index if not exists idx_notifications_user_id on notifications(user_id);
create index if not exists idx_notifications_role_target on notifications(role_target);

-- =========================
-- UPDATED_AT TRIGGERS
-- =========================
drop trigger if exists trg_organizations_updated_at on organizations;
create trigger trg_organizations_updated_at
before update on organizations
for each row execute function set_updated_at();

drop trigger if exists trg_profiles_updated_at on profiles;
create trigger trg_profiles_updated_at
before update on profiles
for each row execute function set_updated_at();

drop trigger if exists trg_vehicles_updated_at on vehicles;
create trigger trg_vehicles_updated_at
before update on vehicles
for each row execute function set_updated_at();

drop trigger if exists trg_vehicle_documents_updated_at on vehicle_documents;
create trigger trg_vehicle_documents_updated_at
before update on vehicle_documents
for each row execute function set_updated_at();

drop trigger if exists trg_trips_updated_at on trips;
create trigger trg_trips_updated_at
before update on trips
for each row execute function set_updated_at();

drop trigger if exists trg_inspection_records_updated_at on inspection_records;
create trigger trg_inspection_records_updated_at
before update on inspection_records
for each row execute function set_updated_at();

drop trigger if exists trg_defect_reports_updated_at on defect_reports;
create trigger trg_defect_reports_updated_at
before update on defect_reports
for each row execute function set_updated_at();

drop trigger if exists trg_work_orders_updated_at on work_orders;
create trigger trg_work_orders_updated_at
before update on work_orders
for each row execute function set_updated_at();

drop trigger if exists trg_maintenance_schedules_updated_at on maintenance_schedules;
create trigger trg_maintenance_schedules_updated_at
before update on maintenance_schedules
for each row execute function set_updated_at();

drop trigger if exists trg_notifications_updated_at on notifications;
create trigger trg_notifications_updated_at
before update on notifications
for each row execute function set_updated_at();

-- =========================================================================
-- SECURE USER PROVISIONING STORED PROCEDURE
-- =========================================================================
create or replace function create_user_admin(
  p_email text,
  p_password text,
  p_name text,
  p_role user_role,
  p_phone text,
  p_title text,
  p_organization_id uuid
)
returns uuid
language plpgsql
security definer -- executes with postgres administrative privileges
set search_path = public, auth
as $$
declare
  new_user_id uuid;
  encrypted_pw text;
begin
  -- 1. Authorization check: Only logged-in users with Fleet Manager profile role
  if not exists (
    select 1 from public.profiles 
    where id = auth.uid() and role = 'Fleet Manager'
  ) then
    raise exception 'Access denied: Only Fleet Managers can create user accounts';
  end if;

  -- 2. Check if email already registered
  select id into new_user_id from auth.users where email = p_email;
  if new_user_id is not null then
    raise exception 'A user with this email address already exists';
  end if;

  -- 3. Prepare credentials
  new_user_id := gen_random_uuid();
  encrypted_pw := crypt(p_password, gen_salt('bf', 10));

  -- 4. Create auth record in Supabase Auth
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  values (
    '00000000-0000-0000-0000-000000000000',
    new_user_id,
    'authenticated',
    'authenticated',
    p_email,
    encrypted_pw,
    now(), -- confirmed immediately so no email verification required
    '{"provider": "email", "providers": ["email"]}'::jsonb,
    jsonb_build_object('name', p_name, 'role', p_role),
    now(),
    now()
  );

  -- 5. Register corresponding public profiles record
  insert into public.profiles (
    id,
    organization_id,
    name,
    role,
    email,
    phone,
    title,
    assigned_vehicle_id,
    created_at,
    updated_at
  )
  values (
    new_user_id,
    p_organization_id,
    p_name,
    p_role,
    p_email,
    p_phone,
    p_title,
    null,
    now(),
    now()
  );

  return new_user_id;
end;
$$;

-- =========================
-- MIGRATIONS
-- Run these against any existing database that was created before these columns/values were added.
-- Safe to re-run: all statements use IF NOT EXISTS / IF EXISTS guards.
-- =========================

-- Migration 1: Add 'Maintenance' to notification_category enum (if not already present)
do $$ begin
  alter type notification_category add value if not exists 'Maintenance';
exception when others then null;
end $$;

-- Migration 2: Add overdue_alert_fired column to work_orders (if not already present)
alter table work_orders
  add column if not exists overdue_alert_fired boolean not null default false;

-- Migration 3: Add defect_status enum and status column to defect_reports
do $$ begin
  create type defect_status as enum ('Pending', 'Approved', 'In Repair', 'Completed');
exception when duplicate_object then null;
end $$;

alter table defect_reports
  add column if not exists status defect_status not null default 'Pending';

-- Migration 4: Add safety_score column to trips table (if not already present)
alter table trips
  add column if not exists safety_score integer null;

-- Migration 5: Create broadcast_messages and fuelTransactions tables (if not already present)
create table if not exists broadcast_messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  message text not null,
  sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_broadcast_messages_organization_id on broadcast_messages(organization_id);

create table if not exists "fuelTransactions" (
  "transactionID" uuid primary key default gen_random_uuid(),
  "vehicleID" uuid references vehicles(id) on delete set null,
  "driverID" uuid references profiles(id) on delete set null,
  "tripID" uuid references trips(id) on delete set null,
  "manualAmount" numeric(12,2) null,
  "odometerReading" integer null,
  "receiptImageUrl" text null,
  "timestamp" timestamptz not null default now(),
  "verificationStatus" text not null default 'Pending',
  "rejectionReason" text null,
  created_at timestamptz not null default now()
);

create index if not exists idx_fuel_transactions_vehicle_id on "fuelTransactions"("vehicleID");
create index if not exists idx_fuel_transactions_driver_id on "fuelTransactions"("driverID");

-- Migration 6: Add title and images columns to defect_reports table (if not already present)
alter table defect_reports
  add column if not exists title text null,
  add column if not exists images text[] null;

-- Migration 7: Add sos_alerts table and indexes (if not already present)
create table if not exists sos_alerts (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.profiles(id) on delete cascade,
  driver_name text not null,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  vehicle_number text not null,
  emergency_type text not null,
  latitude numeric(9,6) not null,
  longitude numeric(9,6) not null,
  description text null,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now()
);

create index if not exists idx_sos_alerts_driver_id on sos_alerts(driver_id);
create index if not exists idx_sos_alerts_vehicle_id on sos_alerts(vehicle_id);

alter table sos_alerts enable row level security;

-- =========================
-- ROW LEVEL SECURITY (RLS)
-- CRITICAL: Without these policies the app cannot read/write any table.
-- Run this entire section in Supabase SQL Editor.
-- Safe to re-run: DROP POLICY IF EXISTS guards every statement.
-- =========================

-- Enable RLS on every table
alter table organizations      enable row level security;
alter table profiles           enable row level security;
alter table vehicles           enable row level security;
alter table vehicle_documents  enable row level security;
alter table trips              enable row level security;
alter table inspection_records enable row level security;
alter table inspection_items   enable row level security;
alter table defect_reports     enable row level security;
alter table work_orders        enable row level security;
alter table maintenance_schedules enable row level security;
alter table notifications      enable row level security;
alter table chat_messages      enable row level security;
alter table broadcast_messages enable row level security;
alter table "fuelTransactions" enable row level security;
alter table sos_alerts         enable row level security;

-- ── ORGANIZATIONS ──────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read organizations" on organizations;
create policy "Allow authenticated read organizations"
  on organizations for select to authenticated using (true);

drop policy if exists "Allow fleet manager insert organization" on organizations;
create policy "Allow fleet manager insert organization"
  on organizations for insert to authenticated with check (true);

-- ── PROFILES ────────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read profiles" on profiles;
create policy "Allow authenticated read profiles"
  on profiles for select to authenticated using (true);

drop policy if exists "Allow user update own profile" on profiles;
create policy "Allow user update own profile"
  on profiles for update to authenticated using (auth.uid() = id);

drop policy if exists "Allow service role insert profile" on profiles;
create policy "Allow service role insert profile"
  on profiles for insert to authenticated with check (true);

drop policy if exists "Allow authenticated delete profiles" on profiles;
create policy "Allow authenticated delete profiles"
  on profiles for delete to authenticated using (true);

-- ── VEHICLES ────────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read vehicles" on vehicles;
create policy "Allow authenticated read vehicles"
  on vehicles for select to authenticated using (true);

drop policy if exists "Allow authenticated write vehicles" on vehicles;
create policy "Allow authenticated write vehicles"
  on vehicles for all to authenticated using (true) with check (true);

-- ── VEHICLE DOCUMENTS ───────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read vehicle_documents" on vehicle_documents;
create policy "Allow authenticated read vehicle_documents"
  on vehicle_documents for select to authenticated using (true);

drop policy if exists "Allow authenticated write vehicle_documents" on vehicle_documents;
create policy "Allow authenticated write vehicle_documents"
  on vehicle_documents for all to authenticated using (true) with check (true);

-- ── TRIPS ────────────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read trips" on trips;
create policy "Allow authenticated read trips"
  on trips for select to authenticated using (true);

drop policy if exists "Allow authenticated write trips" on trips;
create policy "Allow authenticated write trips"
  on trips for all to authenticated using (true) with check (true);

-- ── INSPECTION RECORDS ───────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read inspection_records" on inspection_records;
create policy "Allow authenticated read inspection_records"
  on inspection_records for select to authenticated using (true);

drop policy if exists "Allow authenticated write inspection_records" on inspection_records;
create policy "Allow authenticated write inspection_records"
  on inspection_records for all to authenticated using (true) with check (true);

drop policy if exists "Allow authenticated read inspection_items" on inspection_items;
create policy "Allow authenticated read inspection_items"
  on inspection_items for select to authenticated using (true);

drop policy if exists "Allow authenticated write inspection_items" on inspection_items;
create policy "Allow authenticated write inspection_items"
  on inspection_items for all to authenticated using (true) with check (true);

-- ── DEFECT REPORTS ───────────────────────────────────────────────────────────
-- ALL authenticated users (drivers, fleet managers, maintenance) can read ALL defect reports
-- Drivers insert their own; Fleet managers can update (approve/reject); Maintenance can read
drop policy if exists "Allow authenticated read defect_reports" on defect_reports;
create policy "Allow authenticated read defect_reports"
  on defect_reports for select to authenticated using (true);

drop policy if exists "Allow driver insert defect_reports" on defect_reports;
create policy "Allow driver insert defect_reports"
  on defect_reports for insert to authenticated with check (true);

drop policy if exists "Allow authenticated update defect_reports" on defect_reports;
create policy "Allow authenticated update defect_reports"
  on defect_reports for update to authenticated using (true) with check (true);

-- ── WORK ORDERS ──────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read work_orders" on work_orders;
create policy "Allow authenticated read work_orders"
  on work_orders for select to authenticated using (true);

drop policy if exists "Allow authenticated write work_orders" on work_orders;
create policy "Allow authenticated write work_orders"
  on work_orders for all to authenticated using (true) with check (true);

-- ── MAINTENANCE SCHEDULES ────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read maintenance_schedules" on maintenance_schedules;
create policy "Allow authenticated read maintenance_schedules"
  on maintenance_schedules for select to authenticated using (true);

drop policy if exists "Allow authenticated write maintenance_schedules" on maintenance_schedules;
create policy "Allow authenticated write maintenance_schedules"
  on maintenance_schedules for all to authenticated using (true) with check (true);

-- ── NOTIFICATIONS ────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read notifications" on notifications;
create policy "Allow authenticated read notifications"
  on notifications for select to authenticated using (true);

drop policy if exists "Allow authenticated write notifications" on notifications;
create policy "Allow authenticated write notifications"
  on notifications for all to authenticated using (true) with check (true);

-- ── CHAT MESSAGES ────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read chat_messages" on chat_messages;
create policy "Allow authenticated read chat_messages"
  on chat_messages for select to authenticated using (true);

drop policy if exists "Allow authenticated write chat_messages" on chat_messages;
create policy "Allow authenticated write chat_messages"
  on chat_messages for all to authenticated using (true) with check (true);

-- ── BROADCAST MESSAGES ───────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read broadcast_messages" on broadcast_messages;
create policy "Allow authenticated read broadcast_messages"
  on broadcast_messages for select to authenticated using (true);

drop policy if exists "Allow authenticated write broadcast_messages" on broadcast_messages;
create policy "Allow authenticated write broadcast_messages"
  on broadcast_messages for all to authenticated using (true) with check (true);

-- ── FUEL TRANSACTIONS ────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read fuelTransactions" on "fuelTransactions";
create policy "Allow authenticated read fuelTransactions"
  on "fuelTransactions" for select to authenticated using (true);

drop policy if exists "Allow authenticated write fuelTransactions" on "fuelTransactions";
create policy "Allow authenticated write fuelTransactions"
  on "fuelTransactions" for all to authenticated using (true) with check (true);

-- ── SOS ALERTS ───────────────────────────────────────────────────────────────
drop policy if exists "Allow authenticated read sos_alerts" on sos_alerts;
create policy "Allow authenticated read sos_alerts"
  on sos_alerts for select to authenticated using (true);

drop policy if exists "Allow authenticated write sos_alerts" on sos_alerts;
create policy "Allow authenticated write sos_alerts"
  on sos_alerts for all to authenticated using (true) with check (true);

-- ── MIGRATION: COORDINATES FOR MAP ROUTING ───────────────────────────────────
alter table trips
  add column if not exists origin_lat double precision,
  add column if not exists origin_lng double precision,
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision;


-- =========================
-- SPARE PARTS INVENTORY
-- =========================
create table if not exists spare_parts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  part_number text not null,
  category text not null,
  quantity integer not null default 0 check (quantity >= 0),
  minimum_required integer not null default 2 check (minimum_required >= 0),
  icon text not null default 'shippingbox',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_spare_parts_organization_id on spare_parts(organization_id);

drop trigger if exists trg_spare_parts_updated_at on spare_parts;
create trigger trg_spare_parts_updated_at
before update on spare_parts
for each row execute function set_updated_at();

alter table spare_parts enable row level security;

drop policy if exists "Allow authenticated read spare_parts" on spare_parts;
create policy "Allow authenticated read spare_parts"
  on spare_parts for select to authenticated using (true);

drop policy if exists "Allow authenticated write spare_parts" on spare_parts;
create policy "Allow authenticated write spare_parts"
  on spare_parts for all to authenticated using (true) with check (true);

-- Migration 8: Add spare_parts table (safe to re-run)
create table if not exists spare_parts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  part_number text not null,
  category text not null,
  quantity integer not null default 0 check (quantity >= 0),
  minimum_required integer not null default 2 check (minimum_required >= 0),
  icon text not null default 'shippingbox',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
