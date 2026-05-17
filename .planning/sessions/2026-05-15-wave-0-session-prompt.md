---
description: Prompt à copier-paster au début d'une new session Claude Code pour exécuter Wave 0 du design doc 2026-05-14 (Coach Vivant Karpathy + Trajectoire). Tous les chemins sont in-repo durables.
---

# Wave 0 — Prompt new session (in-repo paths, drift-aware)

Ce fichier est le **prompt durable** à copier-paster au démarrage d'une new session Claude Code pour exécuter Wave 0 du design doc « Coach Vivant Karpathy + Trajectoire Visuelle » du 2026-05-14. Tous les chemins référencés vivent dans le repo (pas de dépendance `~/Downloads/` volatile). Le prompt inclut un drift audit explicite entre handoff archive et code actuel.

---

## Le prompt (copy-paste tout ce qui est dans le bloc de code)

```
Je démarre Wave 0 du design doc MINT « Coach Vivant Karpathy + Trajectoire Visuelle ».

=== CONTEXT À CHARGER (ordre exact, ne saute pas) ===

1. Design doc APPROVED 2026-05-14 (source of truth pour Wave 0-4) :
   /Users/julienbattaglia/.gstack/projects/MINT-IA-MINT/julienbattaglia-feature-S98-sentry-v0-design-20260514-110101.md

2. Handoff archive vision préexistante (in-repo durable) :
   .planning/handoff/README.md  ← lire EN PREMIER pour comprendre le caveat drift
   .planning/handoff/2026-04-26-chat-vivant-services/00-README.md
   .planning/handoff/2026-04-26-chat-vivant-services/01-vision.md
   .planning/handoff/2026-04-26-chat-vivant-services/02-chat-vivant-services.md
   .planning/handoff/2026-04-26-chat-vivant-services/ARCHITECTURE.md
   .planning/handoff/2026-04-26-chat-vivant-services/03-components.md
   .planning/handoff/2026-04-26-chat-vivant-services/colors_and_type.css
   .planning/handoff/2026-04-26-chat-vivant-services/prompts.md

3. Design system + brand PDFs (in-repo) :
   .planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf (lire pages 1-15)
   .planning/handoff/pdfs/MINT-Brand-print-2026-05-09.pdf (lire pages 1-10)
   .planning/handoff/pdfs/Karpathy-Wiki-Pattern-2026-05-06.pdf (lire si vue d'ensemble nécessaire sur §8 CLAUDE.md)

4. Source of truth actuelle (pour drift audit) :
   docs/MINT_IDENTITY.md
   docs/DESIGN_SYSTEM.md
   docs/VOICE_SYSTEM.md
   apps/mobile/lib/theme/colors.dart  (MintColors tokens)
   apps/mobile/lib/widgets/mint_shell.dart  (tab structure courante)
   apps/mobile/lib/services/feature_flags.dart  (chatTabVisible state)
   services/backend/app/services/coach/coach_tools.py  (28 backend tools)
   services/backend/app/services/coach/prompt_registry.py
   services/backend/app/constants/social_insurance.py  (Swiss-law registry)

5. PR #598 statut (HARD GATE Wave 1 ; Wave 0 peut démarrer en parallèle) :
   gh pr view 598 --json mergedAt,state,statusCheckRollup

6. Memories MINT critiques :
   ~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/feedback_zero_trust_protocol.md
   ~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/project_coach_forced_tool_invocation.md
   ~/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/feedback_audit_corpus_before_patching.md

=== DRIFT AUDIT (avant tout build) ===

Avant de lancer Wave 0 build, produire `.planning/audit/2026-MM-DD-handoff-vs-code-drift.md` qui :

- Pour chaque proposition handoff 02-chat-vivant-services.md : (a) shippée vs (b) divergée vs (c) jamais câblée
- Pour colors_and_type.css : diff avec docs/DESIGN_SYSTEM.md + apps/mobile/lib/theme/colors.dart (MintColors)
- Pour prompts.md : diff avec services/backend/app/services/coach/prompt_registry.py
- Pour ARCHITECTURE.md : diff avec mint_shell.dart + coach_chat_screen.dart + état Phase 96 (chatTabVisible)

Verdict : quelles propositions handoff sont encore utilisables ? Lesquelles sont obsolètes ? Lesquelles auraient dû être câblées et ne l'ont pas été (= dette technique vision) ?

STOP et présente le drift audit à Julien avant Wave 0 build. Pas de re-implementation aveugle du handoff.

=== WAVE 0 BUILD (après drift audit validé) ===

Branche : crée `feature/S99-wave-0-foundation` depuis `origin/dev` (après merge PR #598).

3 SUB-AGENTS EN PARALLÈLE (lance tout en même temps) :

A. Audit corpus visuel Explorer (60+ flows) :
   - Map chaque flow Explorer en (a) interactif simulateur, (b) statique didactique, (c) page info
   - Output : .planning/audit/2026-MM-DD-corpus-visuel-explorer.md
   - Verdict : combien embed-able dans Coach didactique inline (Wave 4 spec)

B. Inventaire 28 backend tools :
   - services/backend/app/services/coach/coach_tools.py
   - Pour chaque tool : nom × catégorie (NAVIGATE/READ/WRITE/SEARCH) × source-actuel × cible-refactor × risque-hallucination-numérique
   - Output : .planning/audit/2026-MM-DD-coach-tools-inventory.md
   - Identifier les 7 READ déjà nommés + tout READ secondaire à risque (Wave 1 si ≤ 3, sinon Wave 2.5)

C. Wireframe TrajectoryMap ASCII/markdown (suffisant pour personas LLM Phase A) :
   - S'appuyer sur le drift audit pour savoir si les composants handoff sont réutilisables
   - Lire les 3 PNG racine repo (01-landing.png, 02-concrete-facts-typed.png, 03-chips-rendered.png) pour design existant
   - Dessiner en markdown wireframe TrajectoryMap : timeline horizontale FRI A→B, milestones, marker position
   - Output : .planning/design/2026-MM-DD-trajectory-map-wireframe-v1.md

PUIS, AVEC LES 3 OUTPUTS + DRIFT AUDIT, SÉQUENTIEL :

D. /design-shotgun avec brief construit depuis : wireframe v1 + handoff colors_and_type.css (filtré drift audit) + DESIGN_SYSTEM.md
   → Output : 3 mockups HTML production-quality dans ~/.gstack/projects/MINT-IA-MINT/designs/2026-MM-DD/
   → STOP et demander Julien de choisir variant

E. Vision doc Mon Argent :
   - 3 propositions (numbers panel statique / surface secondaire trajectoire / point d'entrée banking integration)
   - Output : docs/vision/MON_ARGENT-PROPOSAL.md
   → STOP et demander Julien

F. Décision Aujourd'hui doctrine :
   - Steel-man ratify-anti-dashboard (DESIGN_SYSTEM:17)
   - Steel-man pivot-director-dashboard
   - Output : .planning/decisions/2026-MM-DD-aujourdhui-doctrine-proposal.md (status: Proposed)
   → STOP et demander Julien

G. Guide recrutement 5 personas (préparation seulement) :
   - 5 archetypes ancrés Suisse : infirmière valaisanne 27 ans / frontalier 52 ans / expat EU Zurich 34 ans / indépendant sans LPP 38 ans / veuve 68 ans
   - Pour chacun : backstory ancré, ce qu'on lui montre, ce qu'on lui demande, ce qu'on cherche à mesurer
   - Output : .planning/user-research/2026-MM-DD-persona-recruitment-guide.md

=== RÈGLES ===

- 0-trust per memory : aucune claim "shipped/ready/works/validated/green" sans citation file:line OU command output OU PR-merge timestamp. PR opened ≠ shipped.
- Aucun "PROVISIONALLY READY". Honest fallback "je dois vérifier ce point" si bloqué.
- Si décision dépend de mon input (D/E/F), STOP et demander, pas d'auto-décide.
- Si étape révèle blocker (e.g. corpus visuel < 5 widgets embed-able), STOP et flag, attends arbitrage.
- Drift audit doit STOP avant Wave 0 build pour validation Julien sur ce qui est encore utilisable.
- À la fin Wave 0 : commit + PR feature/S99-wave-0-foundation → dev. Wait pour merge avant Wave 1.

Démarre maintenant. Step 1-6 (context load), confirme que tu as tout lu + drift audit produit, puis attends validation Julien avant Wave 0 build.
```

---

## Notes pour Julien

- **Avant** d'ouvrir la new session : merge PR #598 (Phase 7 PAUSE) + ce PR (`feature/S98.6-handoff-archive`) pour que les chemins in-repo soient sur `dev` et que `feature/S99-wave-0-foundation` puisse les utiliser.
- **Alternative GSD** : remplace le prompt direct par `/gsd-plan-phase wave-0-coach-vivant-foundation` après avoir loadé context. Plus cérémonieux mais produit PLAN.md + VERIFICATION.md automatiquement.
- **Drift audit explicit** est la nouveauté par rapport au prompt initial — répond à ton point « les designs handoff ne sont peut-être pas alignés avec le code actuel ». Karpathy Wiki anti-pattern évité par construction.
