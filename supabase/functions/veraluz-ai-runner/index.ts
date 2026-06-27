/**
 * veraluz-ai-runner — Edge Function VERALUZ IA
 * PROMPT 014 — Structure préparée pour connexion IA réelle future
 *
 * ═══════════════════════════════════════════════════════════════
 * SÉCURITÉ ABSOLUE — NE JAMAIS MODIFIER CES RÈGLES :
 *  ✗ Aucune clé IA (OpenAI, Claude, Anthropic…) dans ce fichier
 *  ✗ Aucun secret dans le code source
 *  ✓ Les clés IA seront injectées via Supabase Secrets uniquement
 *    (Supabase Dashboard → Settings → Secrets)
 *  ✓ Accéder via : Deno.env.get('ANTHROPIC_API_KEY')
 *  ✓ Ne jamais retourner la clé dans la réponse HTTP
 * ═══════════════════════════════════════════════════════════════
 *
 * ENTRÉE ATTENDUE (JSON POST) :
 * {
 *   "agent_key":    "daily_director",   // clé de l'agent
 *   "run_type":     "daily_report",     // type d'exécution
 *   "snapshot":     {},                 // données analytics optionnelles
 *   "requested_by": "admin"            // utilisateur déclencheur
 * }
 *
 * RÉPONSE PLACEHOLDER :
 * {
 *   "ok": false,
 *   "mode": "placeholder",
 *   "message": "AI runner not configured yet. Add server-side AI secret before activation."
 * }
 *
 * ARCHITECTURE FUTURE (PROMPT 015+) :
 * ┌─────────────────────────────────────────────────────────┐
 * │ AI_CENTER_EMBEDDED.html                                 │
 * │   POST /functions/v1/veraluz-ai-runner                 │
 * │     { agent_key, run_type, snapshot, requested_by }    │
 * └────────────────────┬────────────────────────────────────┘
 *                      │
 * ┌────────────────────▼────────────────────────────────────┐
 * │ Edge Function veraluz-ai-runner                         │
 * │  1. Valider agent_key contre veraluz_ai_agents         │
 * │  2. Vérifier approval_required + risk_level            │
 * │  3. Charger system_prompt + data_sources depuis DB     │
 * │  4. Charger données autorisées (PAS pin_code/salaires) │
 * │  5. Appeler API IA via Deno.env.get('AI_SECRET')       │
 * │  6. Parser réponse + générer recommandations           │
 * │  7. Sauvegarder run dans veraluz_ai_agent_runs        │
 * │  8. Sauvegarder recs dans veraluz_ai_recommendations  │
 * │  9. Retourner rapport structuré                        │
 * └─────────────────────────────────────────────────────────┘
 *
 * FUTURES SÉCURITÉS À IMPLÉMENTER :
 *  - Rate limiting : max 10 runs/heure par agent
 *  - Validation rôle : superadmin/manager uniquement
 *  - Timeout IA : max 30s avant abort
 *  - Estimation coût IA avant exécution
 *  - Log complet dans veraluz_ai_agent_runs
 *  - Interdiction actions sur paiements/salaires/prix/accès
 *  - Sanitisation sortie IA avant retour frontend
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

/** Types d'entrée attendus */
interface AiRunnerRequest {
  agent_key:    string;
  run_type?:    string;
  snapshot?:    Record<string, unknown>;
  requested_by?: string;
}

/** Format de réponse normalisé */
interface AiRunnerResponse {
  ok:       boolean;
  mode:     "placeholder" | "mock" | "edge";
  message?: string;
  agent_key?: string;
  run_type?:  string;
  timestamp?: string;
  // Champs présents uniquement quand ok=true (mode edge réel) :
  report?:          unknown;
  recommendations?: unknown[];
  run_id?:          string;
}

const CORS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: AiRunnerResponse, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

serve(async (req: Request): Promise<Response> => {
  // ── CORS preflight ─────────────────────────────────────────
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }

  if (req.method !== "POST") {
    return json({ ok: false, mode: "placeholder", message: "Method not allowed — use POST" }, 405);
  }

  // ── Parser le body ─────────────────────────────────────────
  let body: AiRunnerRequest;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, mode: "placeholder", message: "Invalid JSON body" }, 400);
  }

  const agentKey   = body.agent_key   ?? "unknown";
  const runType    = body.run_type    ?? "manual";
  const requestedBy = body.requested_by ?? "system";

  // ── Vérifier si une clé IA est configurée ──────────────────
  // FUTUR : const aiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? Deno.env.get('OPENAI_API_KEY');
  // FUTUR : if (!aiKey) { return placeholder ci-dessous; }
  // ACTUELLEMENT : aucune clé → placeholder systématique

  // ── Réponse placeholder ────────────────────────────────────
  // Retourner cette réponse jusqu'à configuration d'une vraie clé IA
  return json({
    ok:        false,
    mode:      "placeholder",
    message:   "AI runner not configured yet. Add server-side AI secret before activation.",
    agent_key: agentKey,
    run_type:  runType,
    timestamp: new Date().toISOString(),
    // Notes architecture future (informatives uniquement) :
    // - Configurer ANTHROPIC_API_KEY ou OPENAI_API_KEY dans Supabase Secrets
    // - Ne jamais exposer cette clé dans le frontend HTML/JS
    // - Le frontend (AI_CENTER_EMBEDDED.html) reste en VERALUZ_AI_MODE='mock'
    //   jusqu'à ce que cette Edge Function retourne ok:true
  });

  /*
   * ════════════════════════════════════════════════════════════
   * CODE FUTUR — À DÉCOMMENTER QUAND CLÉ IA CONFIGURÉE
   * ════════════════════════════════════════════════════════════
   *
   * const aiKey = Deno.env.get('ANTHROPIC_API_KEY');
   * if (!aiKey) throw new Error('AI secret not configured');
   *
   * // 1. Charger l'agent depuis Supabase
   * const agent = await fetchAgent(agentKey);
   * if (!agent) return json({ok:false, mode:'edge', message:'Agent not found'}, 404);
   * if (agent.status !== 'active') return json({ok:false, mode:'edge', message:'Agent inactive'}, 403);
   *
   * // 2. Charger données autorisées (PAS pin_code, PAS salaires, PAS données RH privées)
   * const data = await loadAuthorizedData(agent.data_sources_json);
   *
   * // 3. Appeler l'API IA avec le prompt système de l'agent
   * const aiResponse = await callAnthropicAPI(aiKey, agent.system_prompt, data);
   *
   * // 4. Sauvegarder run + recommandations
   * const runId = await saveRun(agentKey, runType, requestedBy, aiResponse);
   * await saveRecommendations(agentKey, aiResponse.recommendations);
   *
   * return json({ ok:true, mode:'edge', report:aiResponse, run_id:runId });
   * ════════════════════════════════════════════════════════════
   */
});
