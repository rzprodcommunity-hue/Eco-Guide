-- ============================================================================
-- Eco-Guide — Migration Supabase : contacts d'urgence
-- À exécuter dans : Supabase Dashboard → SQL Editor → New query → Run
-- ----------------------------------------------------------------------------
-- Ces contacts sont gérés (CRUD) depuis le back-office (section « Contacts
-- d'urgence ») et affichés dans la page SOS de l'application mobile.
--
-- IMPORTANT : ce script est IDEMPOTENT et peut être ré-exécuté sans risque.
-- Si vous l'aviez déjà lancé avec l'ancienne version, RELANCEZ-LE : il corrige
-- la policy d'écriture et rend la colonne `phone` optionnelle.
-- ============================================================================

create table if not exists public.emergency_contacts (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  subtitle    text,
  phone       text,
  "isActive"  boolean not null default true,
  "createdAt" timestamptz not null default now()
);

-- Si la table existait déjà avec phone NOT NULL, on lève la contrainte
-- (le téléphone est optionnel dans le formulaire du back-office).
alter table public.emergency_contacts alter column phone drop not null;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------
-- Le back-office se connecte avec des identifiants STATIQUES (il n'ouvre pas
-- de session Supabase Auth), donc il opère avec le rôle `anon`. La policy
-- d'écriture doit donc autoriser `anon` — sinon tous les create/update/delete
-- sont rejetés par RLS et le CRUD paraît « inactif ».
alter table public.emergency_contacts enable row level security;

-- On (re)crée les policies à neuf pour que ré-exécuter ce script corrige
-- une éventuelle ancienne policy trop restrictive.
drop policy if exists emergency_contacts_read   on public.emergency_contacts;
drop policy if exists emergency_contacts_write  on public.emergency_contacts;

-- Lecture publique (l'app mobile + le back-office lisent avec la clé anon).
create policy emergency_contacts_read
  on public.emergency_contacts for select
  using (true);

-- Écriture autorisée pour anon ET authenticated (le back-office est protégé
-- au niveau applicatif par le login admin).
create policy emergency_contacts_write
  on public.emergency_contacts for all
  to anon, authenticated
  using (true) with check (true);

-- Quelques contacts par défaut (facultatif — supprimez si vous préférez partir vide).
insert into public.emergency_contacts (name, subtitle, phone) values
  ('Secours Montagne', 'Urgences en montagne', '112'),
  ('Poste des Gardes', 'Parc National Éco-Guide', '112'),
  ('Guide Référent', 'Votre expédition', '112')
on conflict do nothing;
