-- ═══════════════════════════════════════════════════════════════
-- PROMPT 028 — Migration SQL complémentaire (terrain)
-- VERALUZ OS — Correction colonnes manquantes veraluz_food_orders
-- Date : 2026-06-28
-- IMPORTANT : Exécuter dans Supabase SQL Editor
-- Ces colonnes sont requises pour le bon fonctionnement du workflow
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Colonnes livraison (ajout sécurisé — IF NOT EXISTS) ──────
ALTER TABLE veraluz_food_orders
  ADD COLUMN IF NOT EXISTS delivery_status    text DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS assigned_at        timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_at        timestamptz,
  ADD COLUMN IF NOT EXISTS picked_up_at       timestamptz,
  ADD COLUMN IF NOT EXISTS out_for_delivery_at timestamptz,
  ADD COLUMN IF NOT EXISTS arrived_at         timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at       timestamptz,
  ADD COLUMN IF NOT EXISTS livreur_id         text,
  ADD COLUMN IF NOT EXISTS assigned_to        text,
  ADD COLUMN IF NOT EXISTS driver_photo_url   text,
  ADD COLUMN IF NOT EXISTS proof_photo_url    text;

-- ── 2. Tables journal livraison (créées si absentes) ────────────
CREATE TABLE IF NOT EXISTS veraluz_delivery_messages (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text DEFAULT 'veraluz-001',
  order_id    text,
  sender_type text CHECK (sender_type IN ('restaurant','driver','admin','system')),
  sender_id   text,
  sender_name text,
  message     text NOT NULL,
  message_type text DEFAULT 'text',
  created_at  timestamptz DEFAULT now(),
  read_at     timestamptz
);

CREATE TABLE IF NOT EXISTS veraluz_delivery_events (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text DEFAULT 'veraluz-001',
  order_id    text NOT NULL,
  delivery_id text,
  event_type  text NOT NULL,
  actor_type  text CHECK (actor_type IN ('restaurant','driver','admin','system','client')),
  actor_id    text,
  actor_name  text,
  note        text,
  metadata    jsonb,
  created_at  timestamptz DEFAULT now()
);

-- ── 3. Index pour performance ────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_food_orders_livreur   ON veraluz_food_orders(livreur_id);
CREATE INDEX IF NOT EXISTS idx_food_orders_del_status ON veraluz_food_orders(delivery_status);
CREATE INDEX IF NOT EXISTS idx_food_orders_status     ON veraluz_food_orders(status);
CREATE INDEX IF NOT EXISTS idx_del_msg_order          ON veraluz_delivery_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_del_evt_order          ON veraluz_delivery_events(order_id);

-- ── 4. Vue livreurs actifs ───────────────────────────────────────
CREATE OR REPLACE VIEW veraluz_drivers_active AS
  SELECT id, full_name, role, status, phone,
    photo_url, public_display_name, identity_verified, team_id
  FROM veraluz_employees
  WHERE role = 'livreur' AND status = 'actif';

-- ══════════════════════════════════════════════════════════════
-- NE PAS activer service_role dans le frontend
-- NE PAS ajouter de trigger automatique de paiement/WhatsApp
-- NE PAS ajouter de trigger d'envoi email automatique
-- Aucune migration destructive — aucun DROP TABLE
-- ══════════════════════════════════════════════════════════════
