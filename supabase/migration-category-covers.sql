-- JHAVÈ: copertine indipendenti delle categorie
-- Eseguire una sola volta nel Supabase SQL Editor.

create table if not exists public.store_settings (
  setting_key text primary key check (setting_key in ('cover_jeans','cover_trousers','cover_shirts')),
  image_url text,
  updated_at timestamptz not null default now()
);

alter table public.store_settings enable row level security;

grant select on public.store_settings to anon, authenticated;
grant insert, update on public.store_settings to authenticated;

drop policy if exists "Public can read store settings" on public.store_settings;
create policy "Public can read store settings"
  on public.store_settings for select
  using (true);

drop policy if exists "Jhave admins can insert store settings" on public.store_settings;
create policy "Jhave admins can insert store settings"
  on public.store_settings for insert
  to authenticated
  with check (
    exists (
      select 1 from public.jhave_admins
      where user_id = auth.uid()
    )
  );

drop policy if exists "Jhave admins can update store settings" on public.store_settings;
create policy "Jhave admins can update store settings"
  on public.store_settings for update
  to authenticated
  using (
    exists (
      select 1 from public.jhave_admins
      where user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.jhave_admins
      where user_id = auth.uid()
    )
  );
