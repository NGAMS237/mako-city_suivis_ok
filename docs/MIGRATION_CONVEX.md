# Plan de migration Supabase → Convex

Voir `docs/AUDIT_2026-10.md` pour l'état de départ.

## 1. Correspondance des briques

| Supabase aujourd'hui | Convex cible |
|---|---|
| Tables Postgres `veraluz_*` | Tables déclarées dans `convex/schema.ts` (validateurs `v.*`, index explicites) |
| `fetch()` PostgREST + clé anon | `query` / `mutation` Convex appelées par le client `ConvexClient` (`convex/browser`) |
| RLS (absente ou `USING (TRUE)`) | Vérification d'identité et de rôle **dans chaque fonction** (`ctx.auth` + helper `requireRole`) |
| Realtime `postgres_changes` | Requêtes réactives (`client.onUpdate`) : natif, rien à configurer |
| RPC `upsert_restaurant_product` | `mutation` transactionnelle |
| Edge Functions PIN / login | Convex Auth avec fournisseur `ConvexCredentials` (PIN haché, verrouillage) |
| `veraluz-ai-runner` | `action` Convex (appel Anthropic/OpenAI, clés en variables d'environnement Convex) |
| `cinetpay-webhook` | `httpAction` dans `convex/http.ts` avec vérification de signature |
| Storage bucket `veraluz` | Convex File Storage (`ctx.storage`, URLs signées) |
| `localStorage` métier (contacts, modèles e-mail, infos hôtel) | Tables Convex `settings`, `contacts` |

Le frontend peut rester en HTML vanilla : `ConvexClient` fonctionne sans React. On évite ainsi
une réécriture complète de l'interface.

## 2. Stratégie : migration module par module

Pas de « big bang ». Une couche d'accès unique `veraluz-data.js` remplace les ~15 clients
HTTP dupliqués ; chaque module passe de Supabase à Convex derrière cette couche, l'un après l'autre.

| Lot | Contenu | Tables principales |
|---|---|---|
| **0 — Socle** | Projet Convex, `schema.ts` (tenants, employees, teams), helper d'autorisation, `veraluz-data.js`, CI (typecheck + tests `convex-test`) | `tenants`, `tenant_modules`, `employees`, `teams` |
| **1 — Auth** | Login admin + PIN employé via Convex Auth, hash bcrypt/argon2, verrouillage après N échecs, reset PIN réservé aux admins. Corrige C1–C4, E1, E3, E4 | `authAccounts`, `auth_events` |
| **2 — Restaurant / Food Lounge / Livreur** | Module le plus volumineux (48 appels REST). Carte, commandes, livraisons temps réel | `restaurant_products`, `restaurant_orders`, `food_orders`, `delivery_*`, `restaurant_stock*`, `suppliers` |
| **3 — Réservations / Booking / Housekeeping** | Unités, réservations, ménage, frais de chambre | `units`, `reservations`, `room_charges`, `housekeeping` |
| **4 — RH / Paie / Pointage** | Employés (données sensibles isolées), pointages, paie | `attendance`, `pointages`, `payroll*`, `pay_periods`, `advances`, `hr_*` |
| **5 — Finance / Paiements / Appro** | Caisse, dépenses, rapprochements, CinetPay | `payments`, `caisse`, `expenses`, `invoices`, `refunds`, `rapprochements`, `transactions` |
| **6 — Messagerie / Notifications / Alertes / Documents / IA** | Messages ciblés, notifications, stockage de fichiers, agents IA | `internal_messages`, `message_threads`, `notifications`, `alerts`, `documents`, `ai_*` |
| **7 — Bascule** | Import final des données, gel de Supabase en lecture seule, puis arrêt | — |

## 3. Migration des données

1. Export Supabase de chaque table en JSONL (`COPY ... TO` ou dump via le tableau de bord).
2. Script de transformation : `uuid` → champ `legacyId` indexé (les `_id` Convex sont générés), dates ISO → `number` (ms), clés étrangères résolues en `Id<"table">`.
3. `npx convex import --table <table> <fichier>.jsonl` sur un déploiement de développement, vérification, puis sur la production.
4. **Les PIN ne sont pas migrés** : ils sont considérés comme compromis (audit C2/C3). Chaque employé reçoit un PIN temporaire à changer.

## 4. Règles de sécurité de la cible

- Aucune fonction publique sans `requireRole(ctx, [...])` ; les fonctions internes passent par `internalQuery` / `internalMutation`.
- Chaque document porte `tenantId` ; chaque index commence par `tenantId`.
- Les champs sensibles (`pinHash`, salaire, contrat) vivent dans une table séparée (`employee_private`), jamais renvoyée au client.
- Les secrets (clés IA, CinetPay) sont stockés en variables d'environnement Convex, jamais dans le dépôt.
- Les fonctions Convex valident leurs arguments (`args: { ... }`) ; `innerHTML` est remplacé par `textContent` dans les modules migrés.

## 5. Prérequis côté propriétaire du projet

- Créer un compte et un projet Convex, puis générer une **deploy key** de développement.
- La stocker dans l'environnement cloud de la session (variable `CONVEX_DEPLOY_KEY`), jamais dans la conversation ni dans le dépôt.
- Fournir un export des données Supabase (ou autoriser un accès en lecture seule) pour le lot 7.
- Choisir l'hébergement du frontend (GitHub Pages peut rester).
