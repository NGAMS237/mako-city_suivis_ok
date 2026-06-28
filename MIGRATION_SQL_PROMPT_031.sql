-- ============================================================
-- MIGRATION SQL — PROMPT 031 — Stabilisation journée Veraluz
-- À exécuter dans Supabase SQL Editor (Dashboard > SQL Editor)
-- Aucune migration destructive. Aucun DROP TABLE.
-- Date : 2026-06-28
-- ============================================================

-- ── 1. CORRIGER livreur_id : UUID → TEXT (safe) ─────────────
-- livreur_id est actuellement uuid dans veraluz_food_orders.
-- veraluz_employees.id est TEXT → cast échoue pour les anciens ids.
-- On change livreur_id en TEXT : les valeurs UUID existantes restent valides.
--
-- ÉTAPE 1a : Supprimer la FK UUID → veraluz_rh_employes.id (incompatible avec TEXT)
-- (DROP CONSTRAINT est safe : la FK était redondante après migration vers veraluz_employees)
ALTER TABLE veraluz_food_orders
  DROP CONSTRAINT IF EXISTS veraluz_food_orders_livreur_id_fkey;

-- ÉTAPE 1b : Convertir le type de colonne
ALTER TABLE veraluz_food_orders
  ALTER COLUMN livreur_id TYPE text;

-- ── 2. COLONNES MANQUANTES (migration 028 incomplète) ────────
ALTER TABLE veraluz_food_orders
  ADD COLUMN IF NOT EXISTS delivery_status      text DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS assigned_at          timestamptz,
  ADD COLUMN IF NOT EXISTS out_for_delivery_at  timestamptz;
-- (picked_up_at, accepted_at, arrived_at, proof_photo_url,
--  driver_photo_url, assigned_to, delivered_at existent déjà)

-- ── 3. METTRE À JOUR la vue veraluz_employees_public ─────────
-- La vue existante manque public_display_name et identity_verified
-- que loadLivreurs() demande → PostgREST retourne 400.
CREATE OR REPLACE VIEW veraluz_employees_public AS
SELECT
  e.id,
  e.full_name,
  e.role,
  e.status,
  e.team_id,
  e.phone,
  e.email,
  e.hire_date,
  e.photo_url,
  COALESCE(e.public_display_name, e.full_name) AS public_display_name,
  COALESCE(e.identity_verified, false)          AS identity_verified,
  t.name AS team_name
FROM veraluz_employees e
LEFT JOIN veraluz_teams t ON t.id = e.team_id
WHERE e.status = 'actif';

-- ── 4. CRÉER vue livreurs actifs (fallback Livreur.html) ─────
CREATE OR REPLACE VIEW veraluz_drivers_active AS
SELECT
  e.id,
  e.full_name,
  e.role,
  e.status,
  e.team_id,
  e.phone,
  e.photo_url,
  COALESCE(e.public_display_name, e.full_name) AS public_display_name,
  COALESCE(e.identity_verified, false)          AS identity_verified,
  t.name AS team_name
FROM veraluz_employees e
LEFT JOIN veraluz_teams t ON t.id = e.team_id
WHERE e.role = 'livreur'
  AND e.status = 'actif';

-- ── 5. MODULE MESSAGES activé pour le tenant ─────────────────
INSERT INTO veraluz_tenant_modules (tenant_id, module_key, enabled)
VALUES ('veraluz-001', 'messages', true)
ON CONFLICT (tenant_id, module_key) DO UPDATE SET enabled = true;

-- ── 6. INDEX utiles (IF NOT EXISTS) ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_food_orders_livreur    ON veraluz_food_orders(livreur_id);
CREATE INDEX IF NOT EXISTS idx_food_orders_del_status ON veraluz_food_orders(delivery_status);
CREATE INDEX IF NOT EXISTS idx_food_orders_status     ON veraluz_food_orders(status);
CREATE INDEX IF NOT EXISTS idx_food_orders_created    ON veraluz_food_orders(created_at DESC);

-- ── 7. VÉRIFICATIONS (à lire dans les résultats) ─────────────
SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_name = 'veraluz_food_orders'
  AND column_name IN ('livreur_id','delivery_status','assigned_at','assigned_to','picked_up_at')
ORDER BY column_name;

SELECT viewname FROM pg_views
WHERE schemaname='public'
  AND viewname IN ('veraluz_employees_public','veraluz_drivers_active');

-- ── FIN MIGRATION 031 ─────────────────────────────────────────
