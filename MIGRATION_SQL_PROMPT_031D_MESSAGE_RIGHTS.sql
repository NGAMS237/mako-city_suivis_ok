-- ══════════════════════════════════════════════════════════════════════
-- MIGRATION SQL PROMPT 031D — VERALUZ OS — Droits messagerie ciblée
-- Date : 2026-06-28 | Non destructif : CREATE IF NOT EXISTS uniquement
-- EXÉCUTÉ via MCP Supabase (migration prompt_031d_message_rights)
-- ══════════════════════════════════════════════════════════════════════

-- ── veraluz_internal_messages : colonnes droits/ciblage ──────────────
ALTER TABLE veraluz_internal_messages
  ADD COLUMN IF NOT EXISTS tenant_id        text DEFAULT 'veraluz-001',
  ADD COLUMN IF NOT EXISTS sender_type      text,
  ADD COLUMN IF NOT EXISTS sender_id        text,
  ADD COLUMN IF NOT EXISTS sender_name      text,
  ADD COLUMN IF NOT EXISTS recipient_type   text,
  ADD COLUMN IF NOT EXISTS recipient_id     text,
  ADD COLUMN IF NOT EXISTS recipient_name   text,
  ADD COLUMN IF NOT EXISTS department       text,
  ADD COLUMN IF NOT EXISTS context_type     text,
  ADD COLUMN IF NOT EXISTS context_id       text,
  ADD COLUMN IF NOT EXISTS message          text,
  ADD COLUMN IF NOT EXISTS message_type     text DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS priority         text DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS status           text DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS is_internal      boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS requires_action  boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS action_status    text,
  ADD COLUMN IF NOT EXISTS source_type      text,
  ADD COLUMN IF NOT EXISTS source_id        text,
  ADD COLUMN IF NOT EXISTS thread_ref       text,
  ADD COLUMN IF NOT EXISTS created_at       timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS read_at          timestamptz,
  ADD COLUMN IF NOT EXISTS archived_at      timestamptz,
  ADD COLUMN IF NOT EXISTS acknowledged_at  timestamptz,
  ADD COLUMN IF NOT EXISTS acknowledged_by  text;

-- ── veraluz_delivery_messages : colonnes destinataire ────────────────
ALTER TABLE veraluz_delivery_messages
  ADD COLUMN IF NOT EXISTS recipient_type   text,
  ADD COLUMN IF NOT EXISTS recipient_id     text,
  ADD COLUMN IF NOT EXISTS recipient_name   text,
  ADD COLUMN IF NOT EXISTS priority         text DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS status           text DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS department       text DEFAULT 'delivery';

-- ── Index pour filtrage par acteur ────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_vlz_int_msg_recipient_id
  ON veraluz_internal_messages(tenant_id, recipient_id, status);
CREATE INDEX IF NOT EXISTS idx_vlz_int_msg_recipient_type
  ON veraluz_internal_messages(tenant_id, recipient_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vlz_int_msg_requires_action
  ON veraluz_internal_messages(tenant_id, requires_action, status)
  WHERE requires_action = true;
CREATE INDEX IF NOT EXISTS idx_vlz_deliv_msg_recipient
  ON veraluz_delivery_messages(tenant_id, recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vlz_deliv_msg_livreur
  ON veraluz_delivery_messages(tenant_id, livreur_id, created_at DESC);

-- ══════════════════════════════════════════════════════════════════════
-- AUCUN DROP TABLE. AUCUNE MIGRATION DESTRUCTIVE.
-- ══════════════════════════════════════════════════════════════════════
