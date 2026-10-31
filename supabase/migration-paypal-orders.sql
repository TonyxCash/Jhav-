-- JHAVÈ Official: archivio ordini PayPal
-- Eseguire una sola volta nel Supabase SQL Editor.

create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  paypal_order_id text not null unique,
  amount numeric(10,2) not null check (amount > 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  items jsonb not null,
  status text not null default 'pending' check (status in ('pending','paid','failed')),
  payment_capture_id text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

alter table public.store_orders enable row level security;

-- Nessuna policy per anon/authenticated: solo Edge Functions con service_role possono leggere/scrivere.
revoke all on public.store_orders from anon, authenticated;
grant all on public.store_orders to service_role;
