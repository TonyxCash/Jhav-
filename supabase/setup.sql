-- JHAVÈ STORE — schema, admin e archivio immagini
-- Questo file è pronto per il tuo account. Eseguilo nel Supabase SQL Editor.

create table if not exists public.jhave_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Il tuo account è l'unico amministratore iniziale.
insert into public.jhave_admins (user_id)
values ('029dbf78-0425-4286-8eb8-16144da5626b')
on conflict (user_id) do nothing;

create or replace function public.is_jhave_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.jhave_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_jhave_admin() from public;
grant execute on function public.is_jhave_admin() to authenticated;

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

grant select on public.jhave_admins to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;

drop policy if exists "JHAVE admin reads own record" on public.jhave_admins;
create policy "JHAVE admin reads own record"
on public.jhave_admins for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Public reads active JHAVE products" on public.products;
create policy "Public reads active JHAVE products"
on public.products for select to anon, authenticated
using (active = true or (select public.is_jhave_admin()));

drop policy if exists "JHAVE admin inserts products" on public.products;
create policy "JHAVE admin inserts products"
on public.products for insert to authenticated
with check ((select public.is_jhave_admin()));

drop policy if exists "JHAVE admin updates products" on public.products;
create policy "JHAVE admin updates products"
on public.products for update to authenticated
using ((select public.is_jhave_admin()))
with check ((select public.is_jhave_admin()));

drop policy if exists "JHAVE admin deletes products" on public.products;
create policy "JHAVE admin deletes products"
on public.products for delete to authenticated
using ((select public.is_jhave_admin()));

-- Tre prodotti iniziali del catalogo: prezzi e fotografie da completare nel pannello.
insert into public.products (slug,name,category,description,price,sizes,sort_order)
values
('jeans-sartoriale','Jeans sartoriale JHAVÈ','trousers','Denim uomo · vestibilità slim · dettagli curati',null,array['46','48','50','52','54','56'],1),
('pantalone-sartoriale','Pantalone sartoriale JHAVÈ','trousers','Cotone 97% · elastan 3% · pince e dettagli sartoriali',null,array['46','48','50','52','54','56'],2),
('tshirt-filo-scozia','T-shirt filo di Scozia','shirts','100% cotone · filo di Scozia · morbidezza e comfort',null,array['S','M','L','XL','2XL','3XL','4XL'],3)
on conflict (slug) do nothing;

-- Archivio immagini pubblico in lettura; solo l'amministratore può modificarlo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('jhave-products','jhave-products',true,10485760,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "Public views JHAVE product images" on storage.objects;
create policy "Public views JHAVE product images"
on storage.objects for select to anon, authenticated
using (bucket_id = 'jhave-products');

drop policy if exists "JHAVE admin uploads product images" on storage.objects;
create policy "JHAVE admin uploads product images"
on storage.objects for insert to authenticated
with check (bucket_id = 'jhave-products' and (select public.is_jhave_admin()));

drop policy if exists "JHAVE admin updates product images" on storage.objects;
create policy "JHAVE admin updates product images"
on storage.objects for update to authenticated
using (bucket_id = 'jhave-products' and (select public.is_jhave_admin()))
with check (bucket_id = 'jhave-products' and (select public.is_jhave_admin()));

drop policy if exists "JHAVE admin deletes product images" on storage.objects;
create policy "JHAVE admin deletes product images"
on storage.objects for delete to authenticated
using (bucket_id = 'jhave-products' and (select public.is_jhave_admin()));
