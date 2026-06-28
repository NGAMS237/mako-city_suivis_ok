-- ══════════════════════════════════════════════════════════════════════
-- GUIDE RLS PRODUCTION — VERALUZ OS Messages
-- IMPORTANT : NE PAS EXÉCUTER en mode dev (clé anon + PIN interne).
-- À activer uniquement quand Supabase Auth JWT est en production.
-- ══════════════════════════════════════════════════════════════════════

-- ── Prérequis ─────────────────────────────────────────────────────────
-- 1. Chaque utilisateur doit être authentifié avec un JWT Supabase (auth.uid())
-- 2. La table veraluz_employees doit avoir une colonne user_id (UUID Supabase Auth)
-- 3. Le rôle (role, department) doit être stocké dans JWT custom claims

-- ── Activer RLS sur les tables messages ──────────────────────────────
-- ALTER TABLE veraluz_internal_messages ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE veraluz_delivery_messages ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE veraluz_message_threads ENABLE ROW LEVEL SECURITY;

-- ── Politique admin / superadmin / direction ──────────────────────────
-- CREATE POLICY "admin_voir_tout" ON veraluz_internal_messages
--   FOR SELECT USING (
--     tenant_id = 'veraluz-001'
--     AND (
--       (auth.jwt() ->> 'role') IN ('superadmin','admin','manager','direction')
--     )
--   );

-- ── Politique employé : voit seulement ses messages ───────────────────
-- CREATE POLICY "employe_ses_messages" ON veraluz_internal_messages
--   FOR SELECT USING (
--     tenant_id = 'veraluz-001'
--     AND (
--       recipient_id = (SELECT id::text FROM veraluz_employees WHERE user_id = auth.uid() LIMIT 1)
--       OR sender_id = auth.uid()::text
--       OR recipient_type = (auth.jwt() ->> 'role')
--     )
--   );

-- ── Politique département ─────────────────────────────────────────────
-- CREATE POLICY "dept_ses_messages" ON veraluz_internal_messages
--   FOR SELECT USING (
--     tenant_id = 'veraluz-001'
--     AND department = (auth.jwt() ->> 'department')
--   );

-- ── Politique livreur ─────────────────────────────────────────────────
-- CREATE POLICY "livreur_ses_messages" ON veraluz_delivery_messages
--   FOR SELECT USING (
--     tenant_id = 'veraluz-001'
--     AND (
--       livreur_id = (SELECT id::text FROM veraluz_employees WHERE user_id = auth.uid() LIMIT 1)
--       OR recipient_id = (SELECT id::text FROM veraluz_employees WHERE user_id = auth.uid() LIMIT 1)
--     )
--   );

-- ── Politique lecture (marquer lu / archiver) ─────────────────────────
-- CREATE POLICY "update_ses_messages" ON veraluz_internal_messages
--   FOR UPDATE USING (
--     recipient_id = (SELECT id::text FROM veraluz_employees WHERE user_id = auth.uid() LIMIT 1)
--     OR (auth.jwt() ->> 'role') IN ('admin','superadmin')
--   )
--   WITH CHECK (true);

-- ── Politique insert : selon rôle ─────────────────────────────────────
-- CREATE POLICY "insert_messages_autorises" ON veraluz_internal_messages
--   FOR INSERT WITH CHECK (
--     tenant_id = 'veraluz-001'
--     AND sender_id = auth.uid()::text
--   );

-- ══════════════════════════════════════════════════════════════════════
-- LIMITES ACTUELLES (mode dev PIN interne)
-- - La clé anon n'a pas de JWT custom claims
-- - auth.uid() retourne NULL pour les sessions PIN-based
-- - RLS strict casserait toutes les requêtes actuelles
-- RECOMMANDATION : Activer RLS progressivement après migration vers
--   Supabase Auth (email/magic link ou OAuth)
-- ══════════════════════════════════════════════════════════════════════
