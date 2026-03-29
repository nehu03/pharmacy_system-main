-- Med it Easy — PostgreSQL schema for Supabase
-- Run in: Supabase Dashboard → SQL Editor (or: supabase db push)
-- After: Auth → URL config, disable "Confirm email" for local dev if desired

-- ── Extensions ───────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ── Enums ─────────────────────────────────────────────────────────────────
do $$ begin
  create type public.user_role as enum ('admin', 'cashier', 'staff', 'customer');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.user_status as enum ('active', 'inactive');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.staff_status as enum ('active', 'day_off', 'on_leave');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.product_status as enum ('in_stock', 'low_stock', 'out_of_stock');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.purchase_payment_status as enum ('pending', 'partial', 'paid');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.purchase_status as enum ('pending', 'received', 'completed', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.order_type as enum ('online', 'in_store');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.order_status as enum ('new', 'processing', 'shipped', 'delivered', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.payment_method as enum ('cash', 'card', 'upi', 'bank_transfer', 'cheque');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.payment_record_status as enum ('pending', 'completed', 'failed', 'refunded');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.stock_movement_type as enum ('in', 'out', 'adjustment', 'count');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.stock_reference_type as enum ('purchase', 'order', 'manual');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.activity_status as enum ('success', 'failure');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.service_category as enum (
    'health_fitness', 'home_care', 'online_pharmacy', 'pet_care',
    'personal_care', 'mother_baby', 'self_care', 'ortho_support'
  );
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.service_status as enum ('active', 'inactive');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.booking_status as enum ('pending', 'confirmed', 'completed', 'cancelled');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.gender as enum ('male', 'female', 'other');
exception when duplicate_object then null;
end $$;

-- ── Profiles (linked to auth.users) ────────────────────────────────────────
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  username text unique,
  phone text,
  role public.user_role not null default 'customer',
  status public.user_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_profiles_role on public.profiles (role);
create index if not exists idx_profiles_username on public.profiles (username);

-- New auth user → profile row
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, username, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    nullif(trim(new.raw_user_meta_data->>'username'), ''),
    nullif(trim(new.raw_user_meta_data->>'phone'), ''),
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists medit_on_auth_user_created on auth.users;
create trigger medit_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admin registration: must match secret used in login.html (change in production)
create or replace function public.claim_admin_role(secret text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if secret is distinct from 'meditadmin2024' then
    raise exception 'invalid secret';
  end if;
  update public.profiles
  set role = 'admin', updated_at = now()
  where id = auth.uid();
end;
$$;

grant execute on function public.claim_admin_role(text) to authenticated;

-- ── Core business tables ─────────────────────────────────────────────────
create table if not exists public.categories (
  id bigint generated always as identity primary key,
  name text not null unique,
  description text,
  icon text,
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id bigint generated always as identity primary key,
  product_id text not null unique,
  name text not null,
  category_id bigint references public.categories (id) on delete set null,
  description text,
  price numeric(12,2) not null,
  cost_price numeric(12,2),
  stock_quantity integer not null default 0,
  reorder_level integer not null default 10,
  unit text,
  manufacturer text,
  expiry_date date,
  batch_number text,
  status public.product_status not null default 'in_stock',
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_products_category on public.products (category_id);
create index if not exists idx_products_product_id on public.products (product_id);

create table if not exists public.suppliers (
  id bigint generated always as identity primary key,
  name text not null unique,
  contact_person text,
  phone text,
  email text,
  address text,
  city text,
  bank_details text,
  payment_terms text,
  status public.user_status not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.staff (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  name text not null,
  position text not null,
  phone text,
  email text,
  hire_date date,
  status public.staff_status not null default 'active',
  salary numeric(12,2),
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  name text not null,
  email text,
  phone text,
  address text,
  city text,
  postal_code text,
  date_of_birth date,
  gender public.gender,
  loyalty_points integer not null default 0,
  total_purchases numeric(14,2) not null default 0,
  status public.user_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchases (
  id bigint generated always as identity primary key,
  purchase_id text not null unique,
  supplier_id bigint references public.suppliers (id) on delete set null,
  supplier text,
  purchase_date date not null,
  expected_delivery date,
  total_amount numeric(14,2),
  paid numeric(14,2),
  residual numeric(14,2),
  payment_status public.purchase_payment_status not null default 'pending',
  status public.purchase_status not null default 'pending',
  note text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchase_items (
  id bigint generated always as identity primary key,
  purchase_id bigint not null references public.purchases (id) on delete cascade,
  product_id bigint not null references public.products (id) on delete restrict,
  quantity integer not null,
  unit_cost numeric(12,2) not null,
  total_cost numeric(14,2)
);

create table if not exists public.orders (
  id bigint generated always as identity primary key,
  order_id text not null unique,
  customer_id bigint references public.customers (id) on delete set null,
  customer_name text,
  customer_phone text,
  customer_email text,
  order_date timestamptz not null,
  delivery_date date,
  order_type public.order_type not null default 'online',
  total_amount numeric(14,2),
  discount numeric(12,2) not null default 0,
  tax numeric(12,2) not null default 0,
  final_amount numeric(14,2),
  status public.order_status not null default 'new',
  shipping_address text,
  payment_method text,
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders (id) on delete cascade,
  product_id bigint not null references public.products (id) on delete restrict,
  product_name text,
  quantity integer not null,
  unit_price numeric(12,2) not null,
  total_price numeric(14,2)
);

create table if not exists public.payments (
  id bigint generated always as identity primary key,
  payment_id text not null unique,
  order_id bigint references public.orders (id) on delete set null,
  purchase_id bigint references public.purchases (id) on delete set null,
  customer_id bigint references public.customers (id) on delete set null,
  amount numeric(14,2) not null,
  payment_method public.payment_method not null default 'cash',
  transaction_id text,
  payment_date timestamptz not null,
  status public.payment_record_status not null default 'pending',
  reference_number text,
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.stock (
  id bigint generated always as identity primary key,
  product_id bigint not null unique references public.products (id) on delete cascade,
  quantity_on_hand integer not null default 0,
  quantity_reserved integer not null default 0,
  quantity_available integer not null default 0,
  last_counted date,
  reorder_quantity integer not null default 50,
  reorder_level integer not null default 10,
  warehouse_location text,
  last_updated timestamptz not null default now()
);

create table if not exists public.stock_movements (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products (id) on delete cascade,
  movement_type public.stock_movement_type not null default 'out',
  quantity integer not null,
  reference_type public.stock_reference_type not null default 'manual',
  reference_id text,
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_product on public.stock_movements (product_id);
create index if not exists idx_stock_movements_created on public.stock_movements (created_at);

create table if not exists public.activity_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users (id) on delete set null,
  action text,
  module text,
  reference_id text,
  old_value text,
  new_value text,
  ip_address text,
  status public.activity_status not null default 'success',
  created_at timestamptz not null default now()
);

create index if not exists idx_activity_user on public.activity_logs (user_id);
create index if not exists idx_activity_created on public.activity_logs (created_at);

create table if not exists public.services (
  id bigint generated always as identity primary key,
  service_id text not null unique,
  name text not null,
  description text,
  category public.service_category not null default 'online_pharmacy',
  price numeric(12,2),
  duration_minutes integer,
  status public.service_status not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.service_bookings (
  id bigint generated always as identity primary key,
  booking_id text not null unique,
  service_id bigint not null references public.services (id) on delete cascade,
  customer_id bigint references public.customers (id) on delete set null,
  booking_date date not null,
  booking_time time not null,
  staff_assigned bigint references public.staff (id) on delete set null,
  status public.booking_status not null default 'pending',
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_bookings_date on public.service_bookings (booking_date);

create table if not exists public.qr_codes (
  id bigint generated always as identity primary key,
  product_id bigint not null references public.products (id) on delete cascade,
  qr_code_data text not null unique,
  qr_code_image bytea,
  scans_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- ── updated_at triggers ────────────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists tr_profiles_updated on public.profiles;
create trigger tr_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists tr_products_updated on public.products;
create trigger tr_products_updated before update on public.products
  for each row execute function public.set_updated_at();

drop trigger if exists tr_customers_updated on public.customers;
create trigger tr_customers_updated before update on public.customers
  for each row execute function public.set_updated_at();

drop trigger if exists tr_orders_updated on public.orders;
create trigger tr_orders_updated before update on public.orders
  for each row execute function public.set_updated_at();

drop trigger if exists tr_purchases_updated on public.purchases;
create trigger tr_purchases_updated before update on public.purchases
  for each row execute function public.set_updated_at();

-- ── Seed: categories ───────────────────────────────────────────────────────
insert into public.categories (name, description, icon)
values
  ('Health & Fitness', 'Health and fitness products', '💪'),
  ('Home Care', 'Home care and cleaning products', '🏠'),
  ('Online Pharmacy', 'Pharmaceutical products', '💊'),
  ('Pet Care', 'Pet health and care products', '🐾'),
  ('Personal Care', 'Personal hygiene products', '🧴'),
  ('Mother & Baby', 'Mother and baby care products', '👶'),
  ('Self Care', 'Self-care and wellness', '🧘'),
  ('Ortho & Support', 'Orthopedic support products', '🦴')
on conflict (name) do nothing;

-- Optional: Paper & Wipes (use if you want a dedicated category id)
insert into public.categories (name, description, icon)
values ('Paper & Wipes', 'Paper and wipes', '🧻')
on conflict (name) do nothing;

-- ── Seed: suppliers ────────────────────────────────────────────────────────
insert into public.suppliers (name, contact_person, phone, email, city, status)
values
  ('Pharma Plus Distribution', 'John Smith', '9999000001', 'contact@pharmaplus.com', 'Delhi', 'active'),
  ('Global Pharma Supply', 'Sarah Johnson', '9999000002', 'info@globalpharm.com', 'Mumbai', 'active'),
  ('Medicine House', 'Raj Kumar', '9999000003', 'sales@medicinehouse.com', 'Bangalore', 'active')
on conflict (name) do nothing;

-- ── Seed: products (category_id maps to categories order; Online Pharmacy = 3) ──
insert into public.products (product_id, name, category_id, price, cost_price, stock_quantity, manufacturer, status)
select v.product_id, v.name, c.id, v.price, v.cost_price, v.stock, v.manufacturer, v.pstat::public.product_status
from (
  values
    ('PROD-001', 'Aspirin 500mg', 'Online Pharmacy', 45.00, 25.00, 100, 'Bayer Healthcare', 'in_stock'),
    ('PROD-002', 'Vitamin C 1000mg', 'Health & Fitness', 150.00, 80.00, 50, 'Healthkart', 'in_stock'),
    ('PROD-003', 'Hand Sanitizer 500ml', 'Personal Care', 80.00, 40.00, 75, 'Dettol', 'in_stock'),
    ('PROD-004', 'Dog Shampoo 200ml', 'Pet Care', 120.00, 60.00, 30, 'Pawsitively Happy', 'in_stock'),
    ('PROD-005', 'Baby Wipes 100 pcs', 'Mother & Baby', 200.00, 100.00, 40, 'Johnson & Johnson', 'low_stock'),
    ('PROD-006', 'Knee Support Belt', 'Ortho & Support', 350.00, 180.00, 20, 'Elastic Gear', 'in_stock'),
    ('PROD-007', 'Yoga Mat Premium', 'Health & Fitness', 999.00, 500.00, 15, 'FitLife', 'in_stock'),
    ('PROD-008', 'Face Wash 100ml', 'Personal Care', 180.00, 90.00, 60, 'Cetaphil', 'in_stock')
) as v(product_id, name, cat, price, cost_price, stock, manufacturer, pstat)
join public.categories c on c.name = v.cat
on conflict (product_id) do nothing;

insert into public.products (product_id, name, category_id, price, cost_price, stock_quantity, manufacturer, status)
select 'PROD-PW-001', 'Premium Kitchen Roll 4-Pack', c.id, 129.00, 70.00, 80, 'CleanHome', 'in_stock'::public.product_status
from public.categories c where c.name = 'Paper & Wipes' limit 1
on conflict (product_id) do nothing;

-- ── Seed: services ─────────────────────────────────────────────────────────
insert into public.services (service_id, name, category, price, duration_minutes, status)
values
  ('SVC-001', 'Gym Membership', 'health_fitness', 500.00, 0, 'active'),
  ('SVC-002', 'Home Cleaning', 'home_care', 800.00, 180, 'active'),
  ('SVC-003', 'Online Consultation', 'online_pharmacy', 300.00, 30, 'active'),
  ('SVC-004', 'Pet Grooming', 'pet_care', 600.00, 120, 'active'),
  ('SVC-005', 'Massage Session', 'self_care', 1000.00, 60, 'active')
on conflict (service_id) do nothing;

-- ── RLS ────────────────────────────────────────────────────────────────────
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.suppliers enable row level security;
alter table public.staff enable row level security;
alter table public.customers enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.stock enable row level security;
alter table public.stock_movements enable row level security;
alter table public.activity_logs enable row level security;
alter table public.services enable row level security;
alter table public.service_bookings enable row level security;
alter table public.qr_codes enable row level security;

-- Profiles
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles
  for select using (
    auth.uid() = id
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff')
    )
  );

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id)
  with check (auth.uid() = id);
-- Role changes only via public.claim_admin_role (SECURITY DEFINER); see grants below.

-- Categories: public read, staff write
drop policy if exists "categories_read" on public.categories;
create policy "categories_read" on public.categories for select using (true);

drop policy if exists "categories_write" on public.categories;
create policy "categories_write" on public.categories for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Products: public read, staff write
drop policy if exists "products_read" on public.products;
create policy "products_read" on public.products for select using (true);

drop policy if exists "products_write" on public.products;
create policy "products_write" on public.products for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Suppliers
drop policy if exists "suppliers_read" on public.suppliers;
create policy "suppliers_read" on public.suppliers for select using (true);

drop policy if exists "suppliers_write" on public.suppliers;
create policy "suppliers_write" on public.suppliers for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Staff
drop policy if exists "staff_read" on public.staff;
create policy "staff_read" on public.staff for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
);

drop policy if exists "staff_write" on public.staff;
create policy "staff_write" on public.staff for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Customers: own row or staff
drop policy if exists "customers_select" on public.customers;
create policy "customers_select" on public.customers for select using (
  user_id = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
);

drop policy if exists "customers_insert" on public.customers;
create policy "customers_insert" on public.customers for insert with check (
  user_id is null or user_id = auth.uid()
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
);

drop policy if exists "customers_update" on public.customers;
create policy "customers_update" on public.customers for update
  using (
    user_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    user_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Purchases & items
drop policy if exists "purchases_all" on public.purchases;
create policy "purchases_all" on public.purchases for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

drop policy if exists "purchase_items_all" on public.purchase_items;
create policy "purchase_items_all" on public.purchase_items for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Orders & items: customers see own orders (by email match later); staff see all
drop policy if exists "orders_select" on public.orders;
create policy "orders_select" on public.orders for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  or exists (
    select 1 from public.customers c
    where c.id = orders.customer_id and c.user_id = auth.uid()
  )
);

drop policy if exists "orders_write" on public.orders;
create policy "orders_write" on public.orders for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  );

drop policy if exists "order_items_all" on public.order_items;
create policy "order_items_all" on public.order_items for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  );

-- Payments
drop policy if exists "payments_all" on public.payments;
create policy "payments_all" on public.payments for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier', 'staff'))
  );

-- Stock
drop policy if exists "stock_read" on public.stock;
create policy "stock_read" on public.stock for select using (true);

drop policy if exists "stock_write" on public.stock;
create policy "stock_write" on public.stock for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

drop policy if exists "stock_movements_all" on public.stock_movements;
create policy "stock_movements_all" on public.stock_movements for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Activity logs
drop policy if exists "activity_logs_all" on public.activity_logs;
create policy "activity_logs_all" on public.activity_logs for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Services: public read
drop policy if exists "services_read" on public.services;
create policy "services_read" on public.services for select using (true);

drop policy if exists "services_write" on public.services;
create policy "services_write" on public.services for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Bookings
drop policy if exists "bookings_select" on public.service_bookings;
create policy "bookings_select" on public.service_bookings for select using (
  exists (select 1 from public.profiles p where p.id = auth.uid())
);

drop policy if exists "bookings_write" on public.service_bookings;
create policy "bookings_write" on public.service_bookings for all
  using (auth.uid() is not null)
  with check (auth.uid() is not null);

-- QR codes
drop policy if exists "qr_read" on public.qr_codes;
create policy "qr_read" on public.qr_codes for select using (true);

drop policy if exists "qr_write" on public.qr_codes;
create policy "qr_write" on public.qr_codes for all
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin', 'cashier'))
  );

-- Authenticated users cannot UPDATE role/status directly; claim_admin_role (SECURITY DEFINER) can.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name, username, phone) on public.profiles to authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.categories, public.products, public.suppliers, public.services, public.stock, public.qr_codes to anon, authenticated;
