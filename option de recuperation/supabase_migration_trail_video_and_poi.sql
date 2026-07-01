-- ============================================================================
-- Eco-Guide — Migration Supabase
-- À exécuter dans : Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================================
-- Contexte : le backend est Supabase (PostgREST) directement, il n'y a pas de
-- couche NestJS. Le code (backoffice + app mobile) écrit/lit ces colonnes
-- directement. Seule cette migration doit être lancée manuellement.
-- ============================================================================

-- 1) VIDÉO DE SENTIER ---------------------------------------------------------
-- Nouvelle colonne pour stocker l'URL d'UNE vidéo MP4 par sentier
-- (uploadée vers Supabase Storage bucket "images", ≤ 100 Mo).
ALTER TABLE public.trails
  ADD COLUMN IF NOT EXISTS "videoUrl" text;

-- 2) LIEN POI ↔ SENTIER (un POI = au plus UN sentier) -------------------------
-- La colonne "trailId" existe déjà dans la plupart des installations.
-- On l'ajoute par sécurité si elle manque, avec la contrainte de clé étrangère.
ALTER TABLE public.pois
  ADD COLUMN IF NOT EXISTS "trailId" uuid;

-- Clé étrangère pois.trailId -> trails.id (ON DELETE SET NULL : si on supprime
-- un sentier, ses POI deviennent simplement "non rattachés", on ne les perd pas).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'pois_trailId_fkey'
      AND table_name = 'pois'
  ) THEN
    ALTER TABLE public.pois
      ADD CONSTRAINT "pois_trailId_fkey"
      FOREIGN KEY ("trailId") REFERENCES public.trails(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Index pour accélérer "tous les POI d'un sentier".
CREATE INDEX IF NOT EXISTS pois_trailid_idx ON public.pois ("trailId");

-- ============================================================================
-- NOTE STORAGE : les vidéos sont envoyées dans le bucket public "images"
-- (déjà utilisé pour les photos) — aucun nouveau bucket à créer. Si vous
-- préférez un bucket dédié "videos", créez-le en "Public" puis remplacez
-- 'images' par 'videos' dans uploadVideo() de
-- app_backoffice/lib/core/services/supabase_storage_service.dart.
-- ============================================================================
