# PANEL B — Peer Tools : ce que FONT Cursor, Devin, Codex, Replit pour ne pas perdre le contexte

**Auteur** : context engineer ex-Cursor / ex-Cognition
**Date** : 2026-04-19
**Scope** : comparatif outillé + traduction concrète pour MINT

---

## 1. Cursor — `.cursor/rules/*.mdc` conditionnel

**État de l'art 2026** : Cursor a déprécié `.cursorrules` (racine, monolithique) mi-2025 au profit de `.cursor/rules/` contenant des fichiers `.mdc` (Markdown + frontmatter YAML). Source : Cursor changelog 0.45+ et docs/rules.

Frontmatter typique :
```yaml
---
description: Swiss compliance rules (banned terms, accents)
globs: ["**/*.dart", "**/*.py", "lib/l10n/**"]
alwaysApply: false
type: auto_attached   # always | agent_requested | auto_attached | manual
---
```

Quatre modes de chargement :
- **Always** : injecté tout le temps (mission, identity, banned terms)
- **Auto Attached** : injecté si le glob matche un fichier ouvert/édité (ex: `*.arb` → règles i18n)
- **Agent Requested** : l'agent lit la description et décide d'ouvrir le fichier (rules-à-la-demande)
- **Manual** : chargé uniquement via `@rule-name` dans le prompt

**Taille efficace community-reported** (r/cursor, forums Cursor) : ≤ 500 lignes par fichier, ≤ 6 000 tokens cumulés en "always", sinon dégradation mesurable de l'adhérence. Le `.cursorrules` monolithique > 1 000 lignes est considéré comme anti-pattern en 2026.

**Budget** : Cursor injecte les rules dans le system prompt avant le user turn — donc comptées dans la fenêtre mais mises en cache (prompt caching Anthropic / OpenAI). Les rules `always` bénéficient d'un cache hit ~90% sur sessions consécutives.

---

## 2. Cognition Devin — mémoire persistante structurée

Devin ne repose PAS sur un fichier statique. Architecture publique (blog Cognition 2024-2025, talks Scott Wu) :

- **Knowledge base** : KV store éditable par l'utilisateur ("When working on repo X, always Y"). Injecté conditionnellement sur match sémantique (embeddings), pas via glob.
- **Prior task outputs** : chaque run produit un résumé structuré (ce qui a été fait, ce qui a échoué, ce qui a été appris). Indexé et rappelé au début du run suivant.
- **Machine snapshots** : Devin conserve l'état de la VM entre sessions — le contexte inclut le workspace réel, pas seulement du texte.

**Différence clé vs CLAUDE.md** : Devin sépare **contexte déclaratif** (règles, identité) du **contexte expérientiel** (ce qui a marché / cassé dans les runs passés). MINT mélange les deux dans MEMORY.md — c'est la cause racine du drift : MEMORY.md grossit sans distinction structurelle entre "doctrine" et "journal de session".

**Leçon pour MINT** : séparer `IDENTITY.md` (immuable, toujours chargé) de `PLAYBOOK.md` (patterns qui marchent, éditable) de `JOURNAL/` (session logs, retrieval on-demand).

---

## 3. OpenAI Codex / aider / Claude Code — AGENTS.md

`AGENTS.md` est devenu standard de facto fin 2025 (adopté par Codex CLI, aider, Cursor en fallback, Claude Code). Format : Markdown plat, pas de frontmatter. Structure typique observée sur GitHub (Stripe, Vercel, Supabase repos open-source) :

```
# AGENTS.md
## Project overview (5-10 lignes)
## Setup / commands
## Code style
## Testing
## Don't do
```

**Hiérarchie Claude Code** (doc officielle Anthropic 2025):
1. `~/.claude/CLAUDE.md` — user memory (préférences perso, voix, outils)
2. `<repo>/CLAUDE.md` — project memory (identity, stack, règles projet)
3. `<repo>/**/CLAUDE.md` — directory memory (règles locales à un sous-dossier)
4. Session memory — turn-by-turn, non persistant

MINT n'utilise QUE le niveau 2 (project CLAUDE.md 429 lignes) + un MEMORY.md user-level non standard (226 lignes, au-dessus du plafond ~200 indiqué par le harness lui-même). Aucun CLAUDE.md directoriel dans `apps/mobile/`, `services/backend/`, `lib/l10n/` alors que chacun a des règles spécifiques.

**Token cost** : 429+226 = ~655 lignes ≈ 6 500 tokens injectés à chaque turn. Sur 100 turns = 650k tokens "perdus" en répétition sans cache → avec cache Anthropic (TTL 5min) le coût réel est ~10% de ça. MAIS : plus c'est long, plus l'attention se dilue — l'effet "lost in the middle" est mesuré dès 4k tokens de system prompt.

---

## 4. Replit Agents / v0 / Lovable — anti-hallucination low-code

Replit Agents et Lovable hallucinent massivement (fichiers inexistants, APIs inventées). Leurs parades publiques :

- **Replit** : "project replit.md" + outil `search_filesystem` forcé avant toute création de fichier (documenté dans leurs changelog fin 2025).
- **v0** : prompt chain rigide — chaque génération commence par lister les composants shadcn/ui existants avant d'en inventer.
- **Lovable** : "knowledge files" versionnés, re-embedded à chaque édition, vector search sur la knowledge base avant réponse.

**Parallèle MINT** : les accents français perdus et `financial_core/` réimplémenté = même classe de hallucination. La parade peer est **retrieval forcé** (lire avant écrire), pas seulement "plus de règles dans le prompt".

---

## 5. Standard AGENTS.md 2026

Pas de spec officielle Anthropic publiée. Convention émergente (GitHub search `AGENTS.md` : ~40k repos début 2026) :
- ≤ 200 lignes
- Sections ordonnées : Overview → Commands → Style → Tests → Gotchas
- Pas d'historique de session (celui-ci va dans `.agent/journal/` ou équivalent)
- Liens vers docs détaillées, pas inline

---

## 6. Traduction pour MINT

**Verdict dur** :

a) **Migrer CLAUDE.md monolithique → `.claude/rules/*.md` conditionnels** : OUI. Les 429 lignes actuelles contiennent du "always" (identity, banned terms, 4 pages) mêlé à du "auto-attach" (Flutter design system utile seulement en `.dart`, i18n rules utiles seulement en `.arb`). Splitting proposé :
  - `rules/00-identity.md` (always, ~80 lignes) — mission, doctrine, banned terms, accents FR
  - `rules/10-flutter.md` (glob `apps/mobile/**/*.dart`) — MintColors, GoRouter, Provider
  - `rules/20-backend.md` (glob `services/backend/**/*.py`) — Pydantic v2, pure functions
  - `rules/30-i18n.md` (glob `lib/l10n/**/*.arb`) — 6 langues, diacritiques
  - `rules/40-compliance.md` (always, court) — LSFin, disclaimers obligatoires
  - `rules/50-financial-core.md` (glob `lib/services/financial_core/**`) — ADR calculateurs
  - `rules/90-never.md` (always, ~30 lignes) — anti-patterns top 5

b) **Les 10 skills `mint-*`** (mint-flutter-dev, mint-backend-dev, mint-swiss-compliance, mint-commit, mint-review-pr, mint-audit-complet, mint-test-suite, mint-phase-audit, mint-retro, mint-office-hours) : **redondance mesurable** avec CLAUDE.md section 5-7. Ex : `mint-swiss-compliance` et CLAUDE.md §6 disent la même chose. Les skills sont invoqués explicitement (`/mint-commit`), donc contexte chargé à la demande — c'est BON. Mais CLAUDE.md redit tout en always → **double injection**. Recommandation : CLAUDE.md ne garde qu'un résumé 1-ligne par skill ("Swiss compliance → `/mint-swiss-compliance`") et déplace le détail dans les skills eux-mêmes.

c) **MEMORY.md 226 lignes au-dessus du plafond harness** : c'est un smell. Le harness te l'a dit explicitement ("Only part of it was loaded"). Il faut trancher : MEMORY.md = INDEX (< 100 lignes, liens uniquement) + `memory/topics/*.md` détaillés chargés à la demande. C'est exactement le pattern Cursor `agent_requested`.

d) **Pattern optimal pour fintech suisse compliance-strict** : combinaison Cursor rules + Devin-style journal.
  - Immutable : `rules/00-identity.md` + `rules/90-never.md` — always, ~100 lignes, caché
  - Conditional : `rules/[glob].md` — chargés via auto-attach
  - Experiential : `.planning/journal/YYYY-MM-DD-*.md` — Devin-style, retrieval à la demande
  - **Hook CI** : `tools/checks/no_chiffre_choc.py` existe déjà — étendre à un `no_banned_terms.py` + `accents_fr_present.py` qui bloque le merge. Les règles dans le prompt sont un filet, pas un mur ; le mur c'est le CI gate.

---

## 7. Verdict Phase 30.5 (2 semaines dédiées)

**Sous-dimensionné à 2 semaines, sur-scopé en intention**. Ce qu'il faut vraiment :

- **3 jours suffisent** pour le travail productif : split CLAUDE.md → `rules/*.md`, compresser MEMORY.md → index + topics, écrire 2 CI gates (banned terms, accents), redéployer. C'est de la refacto de config, pas du R&D.
- **Les 11 jours restants que Julien imagine** = symptôme que le vrai problème n'est pas le FICHIER mais le PROCESS : pas de gate CI bloquant les drifts, pas d'audit automatique post-merge, pas de Devin-style journal des échecs d'agents.
- **Peer reality check** : Cursor a shippé son nouveau format rules en **1 release** (sprint interne 1-2 semaines équipe entière), Cognition a itéré Devin sur des mois mais avec équipe dédiée. Pour un solo fondateur, 2 semaines bloquées = coût d'opportunité massif avant Phase 31.

**Recommandation** :
1. **Phase 30.5a (3 jours)** : split CLAUDE.md + compression MEMORY.md + 2 CI gates. Produit concret, mesurable (accents FR = 100% CI pass).
2. **Phase 30.5b (continu, pas de phase dédiée)** : journal des drifts agent (1 ligne par incident dans `.planning/agent-drifts.md`), review mensuel. C'est ça le Devin-pattern.
3. **Phase 31 démarre immédiatement après 30.5a**. Ne pas bloquer 2 semaines.

Si Julien veut vraiment 2 semaines, **alors** investir le surplus dans un vrai vector-retrieval des ADR + docs (Lovable-style), ce qui résout aussi le "recrée financial_core" — mais c'est du build, pas de la refonte de markdown.
