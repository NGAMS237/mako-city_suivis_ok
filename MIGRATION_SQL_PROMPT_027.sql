-- ═══════════════════════════════════════════════════════════════
-- PROMPT 027 — Migrations SQL
-- VERALUZ OS — Workflow Food Lounge → Restaurant → Livreur → Client
-- Date : 2026-06-28
-- ═══════════════════════════════════════════════════════════════

-- ── 1. veraluz_delivery_messages ────────────────────────────────
-- Messages internes restaurant ↔ livreur (jamais automatiques)
CREATE TABLE IF NOT EXISTS veraluz_delivery_messages (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text DEFAULT 'veraluz-001',
  order_id    text,
  sender_type text CHECK (sender_type IN ('restaurant','driver','admin','system')),
  sender_id   text,
  sender_name text,
  message     text NOT NULL,
  message_type text DEFAULT 'text' CHECK (message_type IN ('text','status','incident','system')),
  created_at  timestamptz DEFAULT now(),
  read_at     timestamptz
);
CREATE INDEX IF NOT EXISTS idx_del_msg_order ON veraluz_delivery_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_del_msg_tenant ON veraluz_delivery_messages(tenant_id);
CREATE INDEX IF NOT EXISTS idx_del_msg_driver ON veraluz_delivery_messages(sender_id, sender_type);

-- ── 2. veraluz_delivery_events ──────────────────────────────────
-- Journal de chaque transition livraison (immuable — ne jamais DELETE)
CREATE TABLE IF NOT EXISTS veraluz_delivery_events (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text DEFAULT 'veraluz-001',
  order_id    text NOT NULL,
  delivery_id text,
  event_type  text NOT NULL,
  -- Valeurs : assigned | accepted_by_driver | picked_up | out_for_delivery
  --           arrived | delivered | failed | reassigned | message_sent | cancelled
  actor_type  text CHECK (actor_type IN ('restaurant','driver','admin','system','client')),
  actor_id    text,
  actor_name  text,
  note        text,
  metadata    jsonb,
  created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_del_evt_order ON veraluz_delivery_events(order_id);
CREATE INDEX IF NOT EXISTS idx_del_evt_tenant ON veraluz_delivery_events(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_del_evt_type ON veraluz_delivery_events(event_type);

-- ── 3. Champs supplémentaires veraluz_food_orders ───────────────
-- Ajout champs de traçabilité livraison (si absents)
ALTER TABLE veraluz_food_orders
  ADD COLUMN IF NOT EXISTS delivery_status text DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS assigned_at     timestamptz,
  ADD COLUMN IF NOT EXISTS accepted_at     timestamptz,  -- livreur a accepté
  ADD COLUMN IF NOT EXISTS picked_up_at    timestamptz,  -- commande récupérée
  ADD COLUMN IF NOT EXISTS out_for_delivery_at timestamptz,
  ADD COLUMN IF NOT EXISTS arrived_at      timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at    timestamptz,
  ADD COLUMN IF NOT EXISTS driver_photo_url text,
  ADD COLUMN IF NOT EXISTS proof_photo_url text;

-- ── 4. Vue publique livreur actif (pour assignation Restaurant) ─
CREATE OR REPLACE VIEW veraluz_drivers_active AS
  SELECT
    id, full_name, role, status, phone,
    photo_url, public_display_name, identity_verified,
    team_id
  FROM veraluz_employees
  WHERE role = 'livreur' AND status = 'actif';

-- ══════════════════════════════════════════════════════════════
-- À exécuter dans Supabase SQL Editor
-- NE PAS activer service_role dans le frontend
-- NE PAS ajouter de trigger automatique de paiement
-- NE PAS ajouter de trigger d'envoi email/WhatsApp
-- ══════════════════════════════════════════════════════════════
