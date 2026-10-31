-- JHAVÈ STORE: schema iniziale
-- Prima di eseguire: sostituisci INSERISCI-QUI-UUID-UTENTE con l'UUID del tuo utente
-- Supabase Dashboard > Authentication > Users > clic sul tuo utente > User UID.

create table if not exists public.jhave_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

insert into public.jhave_admins (user_id)
values ('INSERISCI-QUI-UUID-UTENTE')
on conflict (user_id) do nothing;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  category text not null check (category in ('trousers','shirts')),
  description text not null default '',
  price numeric(10,2),
  sizes text[] not null default '{}',
  image_url text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.jhave_admins enable row level security;
alter table public.products enable row level security;

drop policy if exists "JHAVE admins can read admin list" on public.jhave_admins;
create policy "JHAVE admins can read admin list"
on public.jhave_admins for select to authenticated
using (exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()));

drop policy if exists "Public can read active JHAVE products" on public.products;
create policy "Public can read active JHAVE products"
on public.products for select to anon, authenticated
using (active = true or exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()));

drop policy if exists "JHAVE admins can insert products" on public.products;
create policy "JHAVE admins can insert products"
on public.products for insert to authenticated
with check (exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()));

drop policy if exists "JHAVE admins can update products" on public.products;
create policy "JHAVE admins can update products"
on public.products for update to authenticated
using (exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()));

drop policy if exists "JHAVE admins can delete products" on public.products;
create policy "JHAVE admins can delete products"
on public.products for delete to authenticated
using (exists (select 1 from public.jhave_admins a where a.user_id = auth.uid()));

-- Archivio immagini prodotto: lettura pubblica, caricamento/modifica solo admin.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('jhave-products', 'jhave-products', true, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Public can view JHAVE product images" on storage.objects;
create policy "Public can view JHAVE product images"
on storage.objects for select to anon, authenticated
using (bucket_id = 'jhave-products');

drop policy if exists "JHAVE admins can upload product images" on storage.objects;
create policy "JHAVE admins can upload product images"
on storage.objects for insert to authenticated
with check (bucket_id = 'jhave-products' and exists (
  select 1 from public.jhave_admins a where a.user_id = auth.uid()
));

drop policy if exists "JHAVE admins can update product images" on storage.objects;
create policy "JHAVE admins can update product images"
on storage.objects for update to authenticated
using (bucket_id = 'jhave-products' and exists (
  select 1 from public.jhave_admins a where a.user_id = auth.uid()
))
with check (bucket_id = 'jhave-products' and exists (
  select 1 from public.jhave_admins a where a.user_id = auth.uid()
));

drop policy if exists "JHAVE admins can delete product images" on storage.objects;
create policy "JHAVE admins can delete product images"
on storage.objects for delete to authenticated
using (bucket_id = 'jhave-products' and exists (
  select 1 from public.jhave_admins a where a.user_id = auth.uid()
));
