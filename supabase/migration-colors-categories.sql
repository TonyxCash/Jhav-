-- JHAVÈ: categorie definitive e collegamento varianti colore
-- Esegui questo script UNA SOLA VOLTA nel Supabase SQL Editor.

alter table public.products
  add column if not exists color_name text not null default '',
  add column if not exists variant_group text;

-- Aggiorna il vincolo categorie per accettare Jeans, Pantaloni e T-shirt.
do $$
declare c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.products'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%category%'
  loop
    execute format('alter table public.products drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.products
  add constraint products_category_allowed
  check (category in ('jeans','trousers','shirts'));

-- Il prodotto jeans già presente passa nella categoria corretta.
update public.products
set category = 'jeans', updated_at = now()
where slug = 'jeans-sartoriale' and category <> 'jeans';
