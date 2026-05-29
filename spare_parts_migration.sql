-- =============================================
-- SPARE PARTS TABLE - Run this in Supabase SQL Editor
-- =============================================

-- Create the spare_parts table
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

-- Index for fast org-scoped queries
create index if not exists idx_spare_parts_organization_id on spare_parts(organization_id);

-- Auto-update updated_at trigger
drop trigger if exists trg_spare_parts_updated_at on spare_parts;
create trigger trg_spare_parts_updated_at
before update on spare_parts
for each row execute function set_updated_at();

-- Enable RLS
alter table spare_parts enable row level security;

-- RLS Policies
drop policy if exists "Allow authenticated read spare_parts" on spare_parts;
create policy "Allow authenticated read spare_parts"
  on spare_parts for select to authenticated using (true);

drop policy if exists "Allow authenticated write spare_parts" on spare_parts;
create policy "Allow authenticated write spare_parts"
  on spare_parts for all to authenticated using (true) with check (true);

-- =============================================
-- SEED DATA (optional - adds sample parts for your org)
-- Replace 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' with your actual organization ID
-- =============================================

insert into spare_parts (organization_id, name, part_number, category, quantity, minimum_required, icon)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Hydraulic Filter Assembly', '#PN-8821', 'Fluid System', 0, 5, 'shippingbox'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Heavy Duty Brake Pads', '#PN-4402', 'Brakes', 3, 5, 'slider.horizontal.3'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Semi-Synthetic Oil (5L)', '#PN-1029', 'Fluids', 112, 20, 'drop.fill'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Engine Gasket Kit V8', '#PN-9283', 'Engine', 45, 8, 'engine.combustion.fill'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Halogen Headlight Bulbs', '#PN-3115', 'Electrical', 1, 12, 'lightbulb.fill'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Fuel Filter Assembly', '#PN-1205', 'Fluid System', 12, 10, 'line.3.horizontal.decrease'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Windshield Wiper Blades', '#PN-5510', 'Spare Parts', 1, 10, 'car.window.right'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Side Mirror Assembly', '#PN-6678', 'Spare Parts', 6, 4, 'rectangle.portrait.lefthalf.inset.filled')
on conflict do nothing;
