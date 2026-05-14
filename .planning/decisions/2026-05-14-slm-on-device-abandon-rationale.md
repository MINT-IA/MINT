---
date: 2026-05-14
status: Decided
authors: Julien (decided), Claude (drafted)
panel: single
supersedes: .planning/handoff/2026-05-09-design-system-v8/MINT_COACH_AI_INTEGRATION_PROMPT.md (Coach Layer on-device Gemma 3n)
superseded_by: —
description: SLM on-device Gemma 3n abandonné comme PRIMARY Coach inference path (forced-tool-invocation + financial_core round-trip exigent server-side) ; garde open pour tâches narrow on-device (voice STT, banned-terms pre-check, offline fallback).
related:
  - .planning/audit/2026-05-14-handoff-vs-code-drift.md
  - .planning/handoff/2026-05-09-design-system-v8/MINT_COACH_AI_INTEGRATION_PROMPT.md
  - services/backend/app/services/coach/claude_coach_service.py
  - apps/mobile/lib/services/byok_service.dart
---

# Abandon SLM on-device Gemma 3n comme primary Coach (formaliser la décision tacite)

## TLDR

Le pari « SLM on-device Gemma 3n E2B/E4B comme primary Coach inference path » du `MINT_COACH_AI_INTEGRATION_PROMPT.md` est abandonné de facto ; primary inference = ServerKey cloud Anthropic via `claude_coach_service.py` car le forced-tool-invocation pattern (memory `project_coach_forced_tool_invocation`) exige round-trip backend + `financial_core` + citations vérifiables que Gemma 3n 7B ne tient pas. SLM on-device garde open pour tâches narrow (voice STT, banned-terms pre-check local, offline fallback).

## Context

Le `MINT_COACH_AI_INTEGRATION_PROMPT.md` (handoff 2026-05-09) prescrit en 22 KB une architecture Coach Layer on-device :
- Modèle : Gemma 3n E2B (~2 GB Q4_K_M) ou E4B (~3 GB) via `llm_llamacpp` Flutter package
- Justification : « les données du CoachProfile ne quittent JAMAIS le device » (nLPD compliance)
- 7 transformations T1-T7 toutes en on-device inference
- Fallback : BYOK cloud (`byok_service.dart`) si modèle pas téléchargé

L'audit drift `2026-05-14-handoff-vs-code-drift.md` Section F a constaté que :
- `llm_llamacpp` n'est pas dans `pubspec.yaml`
- `lib/coach/` et `lib/llm/` Dart packages n'existent pas
- Le path SLM-first dans `coach_chat_screen.dart` reste dans le code mais l'orchestration backend (`claude_coach_service.py` 66 KB + Phase 94 closed-world citation gate + Phase 93.5 bundles compiler) montre clairement que la primary inference est server-side via Anthropic Claude
- `memory project_byok_scope` (BYOK out-of-scope pour QA jusqu'à launch) confirme : pour le MVP, c'est ServerKey Anthropic, pas SLM, pas BYOK

L'absence d'ADR documentant ce pivot crée un Karpathy Wiki anti-pattern : une future session lit le code, voit SLM-first dans `coach_chat_screen.dart` et le prompt 22 KB en archive, et re-propose Gemma 3n. Cycles perdus en re-débat.

## Decision

**ABANDON** : SLM Gemma 3n on-device comme **PRIMARY** Coach inference path.

**KEEP OPEN** : SLM on-device pour tâches **narrow et bornées** :
- Voice-to-text (potentiellement Whisper / Gemini Nano STT — décision Phase voice 2028+)
- Banned-terms pre-check local (lint LSFin sur la sortie LLM avant affichage)
- Offline fallback « je ne suis pas connecté · récupère un récap statique »
- Cache local pour réponses Coach déjà-vues (24h SharedPreferences, déjà dans le design original)

**RATIONALE** :

1. **Forced-tool-invocation server-side** : memory `project_coach_forced_tool_invocation` impose que le LLM Coach ne peut produire un nombre Swiss-law sans avoir invoqué un tool de retrieval (`get_regulatory_constant`, etc.). Cette enforcement vit dans `services/backend/app/services/coach/citation_parser.py` (Phase 94 closed-world gate). Mettre la même enforcement sur Gemma 3n 7B on-device demanderait :
   - Embarquer une copie des constantes Swiss-law sur device (sync nightly) — duplication
   - Embarquer la regex `NumericClaimExtractor` côté client — duplication
   - Re-prompt loop on-device — Gemma 3n 7B ne supporte pas fiablement le tool_use Anthropic-style
   - Citation registry + `{{cite:<key>}}` parsing — duplication
   
   Coût ≥ 6 mois ingénierie pour atteindre une qualité inférieure à Claude Opus en cloud.

2. **financial_core en Python sur backend** : les calculatrices déterministes (AVS / LPP / 3a / tax) vivent côté Python (`services/backend/app/services/`) avec golden tests Python. La parité Dart (`apps/mobile/lib/services/financial_core/`) existe pour les calculs côté client autonomes — pas pour servir des LLM tools. Round-trip LLM ↔ financial_core => server-side par défaut.

3. **Claude Opus tool-use quality** : la fiabilité tool_use d'Anthropic Claude Opus est ~10x supérieure à un 7B GGUF (basé sur les benchmarks publics tool-use 2025-2026). Pour un domaine vie-réelle / argent / Suisse-law, la fiabilité tool-use est non-négociable (memory `feedback_zero_trust_protocol`).

4. **nLPD compliance reste tenable cloud** : la pré-mise sur on-device était l'argument nLPD. Mais le ServerKey Anthropic via Railway respecte nLPD via DPA Anthropic 2026 + minimisation du payload + zero-retention API (configurable). Coût compliance cloud < coût ingénierie on-device.

5. **Pivot Phase 96 chat-as-verb + Option C Coach vivant didactique** : le destination Coach = surface conversationnelle didactique avec artéfacts inline (4 artéfacts PDF DS v2 mai 8 page 4) + grounded citations. Cette destination est server-side native ; l'on-device n'aurait été qu'une couche de fallback à valeur incrémentale faible.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Steel-man on-device-first : (a) privacy strict — aucune donnée user ne quitte le device, c'est un argument marketing fort en 2026 post-LLM-scrapping-scandals ; (b) zero variable cost — pas de marge OPEX qui croît avec usage ; (c) offline first — UX dégradée gracieusement sans connexion ; (d) Apple Intelligence + Gemma 3n + Phi-3 ouvrent la voie à du SLM mobile qui tient. Si MINT veut un moat « only-app-with-true-on-device-Swiss-financial-coach », SLM est le différenciateur. La décision actuelle accepte de perdre ce différenciateur pour gagner la qualité tool-use cloud — c'est un tradeoff stratégique pas trivial.

- **What does this source not address ?**
  - Le coût OPEX runtime Anthropic API à 10k / 100k / 1M users actifs — pas modélisé.
  - La latence cloud round-trip en condition réseau cellulaire dégradée (Suisse rurale, Valais montagne) — pas mesurée.
  - Si Apple Intelligence ou un SLM open-source 30B+ avec tool_use de qualité Opus émerge en 2026 H2 / 2027 H1, le tradeoff peut basculer.
  - Le passé BYOK (`byok_service.dart` existe) — quel est son scope futur ? Out-of-scope MVP per memory `project_byok_scope`, mais pas définitivement enterré. Si BYOK revient (utilisateurs power qui veulent payer leur clé), il vit dans le même path ServerKey-style — pas SLM.

- **What would change this conclusion ?**
  1. Un SLM open-source 30B+ avec tool-use fiable on-device (≥ 95% precision/recall sur tool_use benchmarks publics) ET un coût mémoire < 4 GB → re-évaluer.
  2. Régulation suisse / EU forçant le traitement on-device de données financières personnelles (hypothétique mais plausible 2027+) → re-évaluer.
  3. Coût OPEX Anthropic dépassant 30% du runway projeté → re-évaluer (par exemple via hybride : SLM on-device pour requêtes triviales, cloud pour Wave 1+ flows).
  4. Si un benchmark MINT-spécifique (50 prompts Swiss-law standardisés) montre Gemma 3n 7B atteignant ≥ 90% parity avec Claude Opus sur tool-use enforcement + numeric citation → re-évaluer.

## Sources

- `.planning/handoff/2026-05-09-design-system-v8/MINT_COACH_AI_INTEGRATION_PROMPT.md` — prompt 22 KB Julien-authored mai 9 (architecture cible originelle SLM-first)
- `services/backend/app/services/coach/claude_coach_service.py` (66 KB) — primary Coach service ServerKey
- `services/backend/app/services/coach/citation_parser.py` (31 KB) — Phase 94 closed-world citation gate
- `services/backend/app/services/coach/hallucination_detector.py` — Sprint S34
- `apps/mobile/lib/services/byok_service.dart` — BYOK fallback (out-of-scope MVP per memory `project_byok_scope`)
- `~/.claude/projects/.../memory/project_coach_forced_tool_invocation.md`
- `~/.claude/projects/.../memory/project_byok_scope.md`
- `~/.claude/projects/.../memory/feedback_app_targets_staging_always.md`
- `~/.claude/projects/.../memory/feedback_anthropic_key_on_railway.md`
- `.planning/audit/2026-05-14-handoff-vs-code-drift.md` Section F (état Coach on-device)

## Status & follow-up

- **Implementation tracking** :
  - Wave 0 PR `feature/S99-wave-0-foundation` : commit ce ADR.
  - Aucun code change immédiat — c'est un ADR rétroactif qui formalise une décision tacite déjà landed.
  - Si Wave 1 backend re-câble les tools Coach sur services Python (Wave 1a), cohérent avec ce ADR.

- **Re-litigation triggers** :
  - Apparition d'un SLM open-source 30B+ on-device tool-use Opus-quality → re-évaluer
  - Régulation suisse forçant traitement on-device → re-évaluer (highest priority)
  - Coût OPEX Anthropic > 30% runway → re-évaluer hybride
  - Benchmark MINT-spécifique montrant Gemma 3n ≥ 90% parity avec Opus sur tool-use Swiss-law → re-évaluer

---
*Decided 2026-05-14 par Julien après drift audit Section F + Wave 0 question explicite « SLM abandon ADR ? » réponse « A avec scope précisé : abandon SLM-first comme PRIMARY Coach inference path, mais garde open pour tâches narrow on-device (voice STT, banned-terms pre-check, offline fallback). Re-trigger si SLM open-source 30B+ Opus-quality on-device émerge. »*
