-- ============================================================================
-- Eco-Guide — Migration Supabase : contacts d'urgence
-- À exécuter dans : Supabase Dashboard → SQL Editor → New query → Run
-- ----------------------------------------------------------------------------
-- Ces contacts sont gérés (CRUD) depuis le back-office (section « Contacts
-- d'urgence ») et affichés dans la page SOS de l'application mobile.
-- ============================================================================

create table if not exists public.emergency_contacts (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  subtitle    text,
  phone       text not null,
  "isActive"  boolean not null default true,
  "createdAt" timestamptz not null default now()
);

-- Row Level Security : lecture publique (l'app mobile utilise la clé anon),
-- écriture réservée aux comptes authentifiés (admin du back-office).
alter table public.emergency_contacts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'emergency_contacts' and policyname = 'emergency_contacts_read'
  ) then
    create policy emergency_contacts_read
      on public.emergency_contacts for select
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where tablename = 'emergency_contacts' and policyname = 'emergency_contacts_write'
  ) then
    create policy emergency_contacts_write
      on public.emergency_contacts for all
      to authenticated
      using (true) with check (true);
  end if;
end $$;

-- Quelques contacts par défaut (facultatif — supprimez si vous préférez partir vide).
insert into public.emergency_contacts (name, subtitle, phone) values
  ('Secours Montagne', 'Urgences en montagne', '112'),
  ('Poste des Gardes', 'Parc National Éco-Guide', '112'),
  ('Guide Référent', 'Votre expédition', '112')
on conflict do nothing;
