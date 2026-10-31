-- JHAVÈ: controlli di inquadratura delle copertine
-- Eseguire una sola volta nel Supabase SQL Editor dopo la migrazione delle copertine.

alter table public.store_settings
  add column if not exists image_position text not null default '50% 50%',
  add column if not exists image_zoom numeric not null default 1;

alter table public.store_settings
  drop constraint if exists store_settings_image_zoom_check;

alter table public.store_settings
  add constraint store_settings_image_zoom_check
  check (image_zoom >= 0.5 and image_zoom <= 2.5);
