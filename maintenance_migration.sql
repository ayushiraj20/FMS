-- =============================================
-- MAINTENANCE MIGRATION — Run in Supabase SQL Editor
-- Adds part_orders + work_order_parts tables
-- Safe to re-run: all statements use IF NOT EXISTS / IF EXISTS guards.
-- =============================================

-- =========================
-- PART ORDER STATUS ENUM
-- =========================
do $$ begin
  create type part_order_status as enum ('Processing', 'In Transit', 'Delivered', 'Cancelled');
exception when duplicate_object then null;
end $$;

-- =========================
-- PART ORDERS
-- Tracks orders placed for shortage / low-stock spare parts
-- =========================
create table if not exists part_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  spare_part_id uuid null references spare_parts(id) on delete set null,
  part_name text not null,
  part_number text not null,
  ordered_quantity integer not null default 1 check (ordered_quantity > 0),
  order_date timestamptz not null default now(),
  status part_order_status not null default 'Processing',
  estimated_delivery timestamptz null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_part_orders_organization_id on part_orders(organization_id);
create index if not exists idx_part_orders_spare_part_id on part_orders(spare_part_id);

drop trigger if exists trg_part_orders_updated_at on part_orders;
create trigger trg_part_orders_updated_at
before update on part_orders
for each row execute function set_updated_at();

alter table part_orders enable row level security;

drop policy if exists "Allow authenticated read part_orders" on part_orders;
create policy "Allow authenticated read part_orders"
  on part_orders for select to authenticated using (true);

drop policy if exists "Allow authenticated write part_orders" on part_orders;
create policy "Allow authenticated write part_orders"
  on part_orders for all to authenticated using (true) with check (true);

-- =========================
-- WORK ORDER PARTS (junction table)
-- Tracks which spare parts were used on which work order
-- =========================
create table if not exists work_order_parts (
  id uuid primary key default gen_random_uuid(),
  work_order_id uuid not null references work_orders(id) on delete cascade,
  spare_part_id uuid not null references spare_parts(id) on delete cascade,
  part_name text not null,
  part_number text not null,
  quantity_used integer not null default 1 check (quantity_used > 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_work_order_parts_work_order_id on work_order_parts(work_order_id);
create index if not exists idx_work_order_parts_spare_part_id on work_order_parts(spare_part_id);

alter table work_order_parts enable row level security;

drop policy if exists "Allow authenticated read work_order_parts" on work_order_parts;
create policy "Allow authenticated read work_order_parts"
  on work_order_parts for select to authenticated using (true);

drop policy if exists "Allow authenticated write work_order_parts" on work_order_parts;
create policy "Allow authenticated write work_order_parts"
  on work_order_parts for all to authenticated using (true) with check (true);
