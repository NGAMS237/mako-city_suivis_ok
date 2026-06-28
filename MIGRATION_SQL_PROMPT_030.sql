-- ============================================================
-- MIGRATION SQL — PROMPT 030 — Messagerie Opérationnelle Veraluz
-- À exécuter dans Supabase SQL Editor (Dashboard > SQL Editor)
-- Aucune migration destructive. Aucun DROP TABLE.
-- ============================================================

-- TABLE 1 : veraluz_message_threads
CREATE TABLE IF NOT EXISTS veraluz_message_threads (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id       text NOT NULL DEFAULT 'veraluz-001',
  title           text,
  context_type    text,
  context_id      text,
  department      text,
  last_message    text,
  last_message_at timestamptz,
  status          text NOT NULL DEFAULT 'open',
  priority        text NOT NULL DEFAULT 'normal',
  created_by      text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- TABLE 2 : veraluz_internal_messages
CREATE TABLE IF NOT EXISTS veraluz_internal_messages (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id       text NOT NULL DEFAULT 'veraluz-001',
  thread_id       text REFERENCES veraluz_message_threads(id) ON DELETE SET NULL,
  context_type    text NOT NULL DEFAULT 'general',
  context_id      text,
  sender_type     text NOT NULL,
  sender_id       text,
  sender_name     text,
  recipient_type  text,
  recipient_id    text,
  recipient_name  text,
  department      text,
  message         text NOT NULL,
  message_type    text NOT NULL DEFAULT 'text',
  priority        text NOT NULL DEFAULT 'normal',
  status          text NOT NULL DEFAULT 'sent',
  is_internal     boolean NOT NULL DEFAULT true,
  requires_action boolean NOT NULL DEFAULT false,
  action_status   text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  read_at         timestamptz,
  archived_at     timestamptz
);

-- TABLE 3 : veraluz_message_reads
CREATE TABLE IF NOT EXISTS veraluz_message_reads (
  id          text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id   text NOT NULL DEFAULT 'veraluz-001',
  message_id  text NOT NULL REFERENCES veraluz_internal_messages(id) ON DELETE CASCADE,
  user_id     text,
  employee_id text,
  reader_name text,
  read_at     timestamptz NOT NULL DEFAULT now()
);

-- TABLE 4 : veraluz_chloe_drafts (CREATE IF NOT EXISTS — sûr si déjà existante)
CREATE TABLE IF NOT EXISTS veraluz_chloe_drafts (
  id             text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tenant_id      text NOT NULL DEFAULT 'veraluz-001',
  draft_type     text NOT NULL DEFAULT 'email',
  recipient_name text,
  recipient_ref  text,
  subject        text,
  body           text NOT NULL,
  context_type   text,
  context_id     text,
  prepared_by    text,
  status         text NOT NULL DEFAULT 'draft',
  sent_at        timestamptz,
  validated_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- INDEX
CREATE INDEX IF NOT EXISTS idx_int_msg_tenant    ON veraluz_internal_messages(tenant_id);
CREATE INDEX IF NOT EXISTS idx_int_msg_thread    ON veraluz_internal_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_int_msg_context   ON veraluz_internal_messages(context_type, context_id);
CREATE INDEX IF NOT EXISTS idx_int_msg_status    ON veraluz_internal_messages(status);
CREATE INDEX IF NOT EXISTS idx_int_msg_priority  ON veraluz_internal_messages(priority);
CREATE INDEX IF NOT EXISTS idx_int_msg_created   ON veraluz_internal_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_int_msg_recipient ON veraluz_internal_messages(recipient_type, recipient_id);
CREATE INDEX IF NOT EXISTS idx_msg_threads_ctx   ON veraluz_message_threads(context_type, context_id);
CREATE INDEX IF NOT EXISTS idx_msg_threads_dept  ON veraluz_message_threads(department);
CREATE INDEX IF NOT EXISTS idx_msg_reads_msg     ON veraluz_message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_chloe_drafts_st   ON veraluz_chloe_drafts(status);

-- ══════════════════════════════════════════════════════════
-- POLITIQUES RLS — À ACTIVER AVANT MISE EN PRODUCTION
-- ══════════════════════════════════════════════════════════
-- ALTER TABLE veraluz_internal_messages ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE veraluz_message_threads   ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE veraluz_message_reads     ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE veraluz_chloe_drafts      ENABLE ROW LEVEL SECURITY;
--
-- Politique livreur : ne voit que ses propres messages
-- CREATE POLICY livreur_own ON veraluz_internal_messages
--   USING (recipient_id = auth.uid()::text OR sender_id = auth.uid()::text);
--
-- Politique admin : voit tout
-- CREATE POLICY admin_all ON veraluz_internal_messages
--   USING (current_setting('request.jwt.claims',true)::json->>'role' IN ('admin','manager'));
