-- Tables
create table if not exists public.products (
  id uuid primary key,
  company_id text not null,
  location_id text null,
  code text not null,
  name text not null,
  price numeric not null default 0,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key,
  company_id text not null,
  location_id text not null,
  txn_date timestamptz not null,
  total numeric not null default 0,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

-- updated_at trigger
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end; $$;

create trigger trg_products_updated_at before update on public.products for each row execute procedure public.set_updated_at();
create trigger trg_sales_updated_at before update on public.sales for each row execute procedure public.set_updated_at();

-- Enable RLS
alter table public.products enable row level security;
alter table public.sales enable row level security;

-- Example RLS: scope by company_id (and optional location)
create policy products_select on public.products for select using (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);
create policy products_insert on public.products for insert with check (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);
create policy products_update on public.products for update using (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);

create policy sales_select on public.sales for select using (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);
create policy sales_insert on public.sales for insert with check (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);
create policy sales_update on public.sales for update using (
  company_id = coalesce(current_setting('request.jwt.claims', true)::jsonb->>'cmp','')
);