/**
 * veraluz-ai-runner — Edge Function placeholder
 * PROMPT 013 — VERALUZ AI Center
 *
 * SÉCURITÉ :
 *  - Ne contient aucune clé IA (OpenAI, Claude, Anthropic, etc.)
 *  - Toute clé IA future sera injectée via Supabase Secrets (côté serveur uniquement)
 *  - Ne jamais exposer de secret dans le frontend
 *
 * En production future :
 *  - Récupérer la clé IA via Deno.env.get('OPENAI_API_KEY') ou 'ANTHROPIC_API_KEY'
 *  - Valider le token utilisateur avant tout appel IA
 *  - Logger chaque run dans veraluz_ai_agent_runs
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ ok: false, message: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // Placeholder — aucune clé IA configurée pour l'instant
    // Retourner une réponse indiquant que le runner n'est pas encore opérationnel
    const body = await req.json().catch(() => ({}));
    const agentKey = body?.agent_key ?? "unknown";

    return new Response(
      JSON.stringify({
        ok: false,
        message: "AI runner not configured yet",
        agent_key: agentKey,
        mode: "placeholder",
        note: "Pour activer : déployer avec ANTHROPIC_API_KEY ou OPENAI_API_KEY dans Supabase Secrets. Ne jamais exposer de clé IA dans le frontend.",
        timestamp: new Date().toISOString(),
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ ok: false, message: "Internal error", error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
