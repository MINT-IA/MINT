# Analyse des Frameworks — GStack, Superpowers, GSD appliqués à MINT

> Document de référence interne. Synthèse de 3 frameworks open-source et leur application au système de skills MINT.
> Dernière mise à jour : 2026-04-05 | 10 passes itératives (substance → compression → verdict)

---

## Table des matières

1. [Contexte](#1-contexte)
2. [Les 3 frameworks en bref](#2-les-3-frameworks-en-bref)
3. [12 mécanismes clés extraits](#3-12-mécanismes-clés-extraits)
4. [Cartographie MINT : où en est-on ?](#4-cartographie-mint--où-en-est-on-)
5. [Les 7 gaps prouvés](#5-les-7-gaps-prouvés)
6. [Les 6 forces que MINT a et que personne n'a](#6-les-6-forces-que-mint-a-et-que-personne-na)
7. [Recommandations par priorité](#7-recommandations-par-priorité)
8. [Matrice croisée : mécanismes × domaines de vie](#8-matrice-croisée--mécanismes--domaines-de-vie)
9. [Verdict](#9-verdict)

---

## 1. Contexte

MINT est une app fintech suisse d'éducation financière (Flutter + FastAPI) couvrant **18 life events** — pas uniquement la retraite. L'app s'appuie sur 18 skills Claude Code (11 boucles Karpathy autonomes + 5 orchestration + 2 config) pour son développement.

Ce document analyse 3 frameworks de développement assisté par IA — GStack (Garry Tan/YC), Superpowers (obra/Jesse Vincent), GSD (meta-prompting) — et identifie ce que MINT peut en extraire pour combler ses gaps sans casser ce qui fonctionne déjà.

**Portée** : chaque analyse couvre tous les domaines MINT (retraite, logement, famille, fiscalité, patrimoine, carrière, dette, mobilité, santé) et les 8 archetypes financiers (swiss_native, expat_eu, expat_non_eu, expat_us, independent_with_lpp, independent_no_lpp, cross_border, returning_swiss).

---

## 2. Les 3 frameworks en bref

### 2.1 GStack (Garry Tan, YC) — 31 skills (23 specialists + 8 power tools), MIT

**Philosophie** : Pipeline complet de startup, de l'idéation au post-mortem.

| Phase | Skill | Mécanisme principal |
|-------|-------|-------------------|
| Cadrage | `/office-hours` | 6 Forcing Questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit) + design doc + spec review adversarial. 2 modes : Startup (questions dures) vs Builder (brainstorming créatif) |
| Plan | `/plan-eng-review` | Diagrammes ASCII, matrice de tests, review ingénierie |
| Review | `/review` | Fix-First (AUTO-FIX vs ASK), specialist passes via Agent tool, findings dedup cross-PR |
| Ship | `/ship` | 18 étapes (pre-flight → tests → coverage audit IA → plan completion → review → version bump → CHANGELOG → PR → document-release), Test Halt Loop |
| Retro | `/retro` | Git log analysis, per-author stats, hotspot detection, snapshot JSON |
| Sécurité | `/cso` | 15 phases (0-14) OWASP A01-A10, STRIDE, secrets archaeology, CVE scan |
| QA | `/qa` | Chromium headless, 11 phases, screenshots, fix loop, regression test auto-gen |
| Safety | `/careful` + `/freeze` + `/guard` | Empêche commandes destructrices, verrouille edits à un répertoire |
| Debug | `/investigate` | 4 phases + auto-freeze du module investigué |
| Learnings | `/learn` | show, search, prune, stats, export, manual add |

**Mémoire** : `learnings.jsonl` — append-only, confidence 0-10, decay temporel (1pt/30j), dedup par key+type, cross-project search, chargé automatiquement au démarrage de chaque skill via preamble. Types structurés : `pattern`, `pitfall`, `preference`, `architecture`, `tool`.

**Gouvernance** : 5 éléments hiérarchiques (inférés, pas formalisés explicitement par GStack) — ETHOS.md → CLAUDE.md → Preamble → Skills → Learnings.

**Session tracking** : compte les sessions actives, passe en mode "ELI16" (re-grounding systématique) quand 3+ sessions tournent simultanément.

### 2.2 Superpowers (obra/Jesse Vincent) — 14 skills, MIT

**Philosophie** : Rigueur TDD absolue, isolation des subagents, anti-rationalisation. Pas de mémoire inter-sessions (contrairement à GStack/GSD).

| Phase | Mécanisme |
|-------|-----------|
| Brainstorm | HARD GATE — zéro code avant design approuvé. Questions une par une. Spec sauvée dans `docs/superpowers/specs/` |
| Plans | Tasks de 2-5 min avec code COMPLET. Zéro placeholder ("TBD", "TODO" = plan failure) |
| Subagent | 1 agent frais par task, ne hérite JAMAIS le contexte de la session. Double review : spec reviewer ("Do Not Trust the Report") + quality reviewer. 4 statuts : DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, BLOCKED |
| TDD | DELETE si code avant test. RED-GREEN-REFACTOR strict |
| Debug | 4 phases (Root Cause → Pattern Analysis → Hypothesis → Implementation). Règle des 3 tentatives : 3 fixes échoués → STOP, questionner l'architecture |
| Verification | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" + table anti-rationalisation dédiée (8 excuses) |
| Escalation | Subagent peut dire "BLOCKED" ou "NEEDS_CONTEXT" sans pénalité. "Bad work is worse than no work." |
| Meta | `writing-skills` : TDD appliqué aux skills eux-mêmes (RED sans skill → GREEN avec → REFACTOR) |

**Anti-rationalisation** : 2 tables distinctes — 11+ excuses TDD ("too simple", "I'll test after", etc.) + 12 excuses pour ne pas utiliser un skill ("this is too simple", "I need more context first", etc.). Ce sont des instructions dans les prompts (prompt engineering), pas des mécanismes bloquants techniques.

**Anti-performativité** : le skill `receiving-code-review` interdit les réponses comme "You're absolutely right!" — impose de vérifier avant d'implémenter le feedback.

### 2.3 GSD (Get Shit Done) — meta-prompting + context engineering

**Philosophie** : Le context window est une ressource finie. La qualité se dégrade quand il se remplit.

| Couche | Mécanisme |
|--------|-----------|
| Statusline | Barre visuelle du remplissage context window |
| Context monitor | Hook PostToolUse, warnings à 35%/25% restant |
| Budget tiers | PEAK 0-30%, GOOD 30-50%, DEGRADING 50-70%, POOR 70%+ |
| Fresh context | Orchestrateur à ~10-15% d'utilisation, travail délégué dans contextes frais (200k ou 1M) |
| Session | STATE.md (mémoire inter-sessions), `.continue-here.md` (pause/resume), wave execution |
| Agents | 21 spécialisés (planner, executor, verifier, debugger, researcher, security-auditor, ui-auditor, etc.) |
| Vérification | 4 niveaux : Existence → Substantiveness → Wiring → Data Flow |
| Model profiles | quality (Opus/Opus/Sonnet/Sonnet), balanced (Opus/Sonnet/Haiku/Haiku), budget (Sonnet/Sonnet/Haiku/Haiku), inherit (modèle courant) |

**Hooks** : advisory-only, jamais bloquants, toujours informatifs.

---

## 3. 12 mécanismes clés extraits

L'analyse croisée des 3 frameworks fait émerger 12 mécanismes distincts. Chacun est documenté avec sa source, son fonctionnement et son applicabilité à un projet fintech multi-domaines.

### M1 — Cadrage pré-code (GStack `/office-hours` + Superpowers BRAINSTORM)

**Quoi** : Avant toute ligne de code, une phase structurée force la clarification du problème.
- GStack : 6 questions YC (problème, utilisateur, insight, solution, traction, ask) + génération automatique d'un design doc + review adversarial de la spec.
- Superpowers : HARD GATE — l'agent ne peut pas écrire de code tant que le design n'est pas approuvé. Questions posées une par une, jamais en bloc.

**Pourquoi c'est critique pour MINT** : le piège "façade sans câblage" (identifié W14, documenté dans `.claude` memory `feedback_facade_sans_cablage.md`) vient directement de l'absence de cadrage. Un agent code un composant parfait mais jamais connecté. Le cadrage force à répondre : "qui consomme cet output ?" avant de coder.

**Domaines impactés** : tous les 18 life events. Un simulateur d'EPL (housing) mal cadré ne vérifie pas les seuils LPP. Un calcul FATCA (expat_us) sans cadrage ignore la convention US-CH.

### M2 — Review automatique avec auto-fix (GStack `/review`)

**Quoi** : Review de PR en 2 modes — AUTO-FIX (corrections triviales appliquées directement) et ASK (questions bloquantes posées à l'auteur). Findings stockés en JSONL avec fingerprint pour dedup cross-PR. Subagents spécialisés en parallèle (sécurité, perf, style). Score PR final.

**Pourquoi c'est critique pour MINT** : `mint-commit` (v2.1) fait du formatage — branch flow, conventional commits, Co-Authored-By. Il ne lit pas le diff. Il ne détecte pas les anti-patterns CLAUDE.md §9.

**Domaines impactés** : surtout `financial_core/` (calculateurs partagés par tous les domaines). Une erreur dans `avs_calculator.dart` affecte retraite + couple + expat simultanément.

### M3 — TDD strict avec anti-rationalisation (Superpowers)

**Quoi** : RED-GREEN-REFACTOR imposé. Si du code de production est écrit avant un test, le code est supprimé. 6+ excuses courantes sont bloquées mécaniquement :

| # | Excuse bloquée | Pourquoi c'est dangereux |
|---|---------------|-------------------------|
| 1 | "Too simple for tests" | Les bugs les plus coûteux sont dans le code "simple" |
| 2 | "I'll test after" | "After" n'arrive jamais |
| 3 | "TDD is dogmatic" | Rationalisation pour éviter la discipline |
| 4 | "Just a refactor" | Un refactor sans tests = régression silencieuse |
| 5 | "Tests would be trivial" | Trivial = rapide à écrire, aucune excuse |
| 6 | "I need to see the shape first" | Spike OK, mais dans une branche jetable |

**Pourquoi c'est critique pour MINT** : `autoresearch-test-generation` crée des tests APRÈS le code. `autoresearch-quality` fixe le code pour passer les tests existants. Aucun skill ne force à écrire le test D'ABORD. Résultat : les tests couvrent le code tel qu'il est, pas tel qu'il devrait être.

**Domaines impactés** : les 8 archetypes. Un test TDD pour `expat_us` forcerait à spécifier le comportement FATCA AVANT de coder, évitant les oublis.

### M4 — Mémoire inter-sessions (GStack `learnings.jsonl` + GSD `STATE.md`)

**Quoi** :
- GStack : fichier append-only `learnings.jsonl`. Chaque entrée a une confidence (0-10), un decay temporel (1 point perdu tous les 30 jours), une clé+type pour dedup. Chargé automatiquement au démarrage de chaque skill.
- GSD : `STATE.md` pour la mémoire entre sessions + `HANDOFF.json` pour pause/resume propre.

**Pourquoi c'est critique pour MINT** : les 11 boucles Karpathy n'ont aucune mémoire. `autoresearch-quality` redécouvre les mêmes patterns de bugs à chaque session. `autoresearch-compliance-hardener` reteste les mêmes vecteurs. `autoresearch-calculator-forge` rejoue les mêmes scénarios edge-case.

**Domaines impactés** : tous. La mémoire permettrait de capitaliser : "le calcul AVS couple plafonné à 150% a déjà été validé avec Julien+Lauren" évite de retester ce cas à chaque session.

### M5 — Isolation des subagents (Superpowers + GSD)

**Quoi** :
- Superpowers : chaque task est exécutée par un agent frais qui n'hérite JAMAIS le contexte de la session parente. Double review : un spec reviewer (ne fait pas confiance au rapport de l'implémenteur) + un quality reviewer.
- GSD : l'orchestrateur reste à 30-40% de contexte, délègue le travail dans des contextes frais de 200k.

**Pourquoi c'est critique pour MINT** : les boucles Karpathy tournent dans un seul contexte. Après 20+ itérations de `autoresearch-quality`, le contexte est saturé et la qualité des fixes se dégrade. C'est le "context rot" que GSD a formalisé.

**Domaines impactés** : les sprints longs (S51-S56 avaient des phases de 100+ fichiers modifiés). Un audit complet (`mint-audit-complet`) avec 75 gates dans un seul contexte perd en précision vers la fin.

### M6 — Coverage gate bloquant (GStack `/ship`)

**Quoi** : Le pipeline `/ship` de GStack a 14 étapes dont un coverage gate à 60% minimum. Si la couverture descend en dessous, le ship est bloqué. Un "Test Halt Loop" détecte les tests flaky et les isole.

**Pourquoi c'est critique pour MINT** : `mint-commit` ne vérifie pas la couverture. On peut commiter du code sans aucun test associé. Le seul garde-fou est la règle CLAUDE.md "minimum 10 unit tests par service" — mais elle n'est pas vérifiée mécaniquement.

**Domaines impactés** : les nouveaux calculateurs. Si `withdrawal_sequencing_service.dart` ou `tornado_sensitivity_service.dart` sont ajoutés sans tests, ils passeront en production. Tous les domaines qui les consomment héritent du risque.

### M7 — Gestion du context window (GSD)

**Quoi** : 3 couches complémentaires :
1. **Statusline** : barre visuelle du remplissage (toujours visible)
2. **Context monitor** : hook PostToolUse qui injecte des warnings à 35% et 25% restant
3. **Budget tiers** : PEAK (0-30% utilisé), GOOD (30-50%), DEGRADING (50-70%), POOR (70%+)

Les hooks sont advisory-only — ils informent, ne bloquent jamais.

**Pourquoi c'est critique pour MINT** : aucun skill MINT ne gère le context window. Les boucles Karpathy avec `N=50` ou `N=100` itérations remplissent le contexte bien avant la fin. La qualité des dernières itérations est significativement inférieure aux premières.

**Domaines impactés** : tout sprint long. Un `autoresearch-calculator-forge 50` qui teste 50 scénarios AVS/LPP/fiscalité perd en rigueur après le scénario 25-30.

### M8 — Pipeline de ship structuré (GStack `/ship`)

**Quoi** : 14 étapes séquentielles — lint → type check → test → coverage gate → build → changelog → version bump → tag → push → deploy → smoke test → announce → cleanup → retro trigger. Chaque étape est un point d'arrêt : si elle échoue, le pipeline s'arrête.

**Pourquoi c'est important pour MINT** : le flow actuel est : `flutter analyze` + `flutter test` + commit. Pas de coverage gate, pas de smoke test, pas de changelog automatique, pas de retro trigger. Le skill `mint-commit` fait du formatage de message, pas du quality gating.

### M9 — Cross-skill communication (gap MINT spécifique)

**Quoi** : aucun des 3 frameworks ne résout ce problème proprement, mais MINT en souffre spécifiquement. Les 11 boucles Karpathy produisent des outputs (test_gaps.json, findings, scores) qui ne sont pas consommés par les autres skills. `autoresearch-test-coverage` produit `test_gaps.json` — `autoresearch-test-generation` est censé le consommer, mais le lien n'est pas garanti mécaniquement.

**Solution hybride** : le pattern `learnings.jsonl` de GStack (fichier partagé, append-only) + le `STATE.md` de GSD (état lisible par tous) pourraient servir de bus inter-skills.

### M10 — Retro automatique (GStack `/retro`)

**Quoi** : analyse du git log post-sprint — stats par auteur, breakdown par type de commit, détection de hotspots (fichiers les plus modifiés), tracking de streaks, snapshot JSON pour comparaison inter-sprints.

**Pourquoi c'est utile pour MINT** : après chaque sprint (S51-S56), la retro est manuelle. Pas de détection automatique des fichiers chauds (ex: `app.dart` modifié 47 fois en 6 sprints = hotspot évident). Pas de tracking de la vélocité.

**Domaines impactés** : planification des sprints. Savoir que `financial_core/` est un hotspot aide à prioriser les tests. Savoir que les life events "mobilité" (cantonMove, countryMove) n'ont jamais été touchés aide à prioriser la couverture.

### M11 — Audit de sécurité structuré (GStack `/cso`)

**Quoi** : 14 phases couvrant OWASP A01-A10, modélisation STRIDE, archéologie de secrets (scan historique git), audit de dépendances CVE. Rapport structuré avec severity scoring.

**Pourquoi c'est pertinent pour MINT** : `autoresearch-privacy-guard` couvre les fuites PII mais pas les vulnérabilités applicatives. Pas d'audit OWASP. Pas de scan de secrets dans l'historique git. Pas d'audit de dépendances (Flutter + Python).

**Domaines impactés** : les données FATCA (Lauren, expat_us) sont particulièrement sensibles. Les clés API (ANTHROPIC_API_KEY sur Railway) n'ont pas d'audit de rotation.

### M12 — Vérification 4 niveaux anti-façade (GSD verifier)

**Quoi** : Le vérificateur GSD ne se contente pas de "les tests passent". Il vérifie 4 niveaux progressifs :
1. **Existence** — le fichier/fonction existe-t-il ?
2. **Substantiveness** — c'est du vrai code ou un stub/placeholder ?
3. **Wiring** — c'est importé et utilisé par un consommateur réel ?
4. **Data Flow** — de vraies données circulent-elles de bout en bout ?

**Pourquoi c'est LE mécanisme le plus critique pour MINT** : le piège "façade sans câblage" (feedback W14) est exactement le problème que ce vérificateur résout. Un composant peut exister (niveau 1), contenir du vrai code (niveau 2), mais n'être connecté à rien (niveau 3) et ne traiter aucune donnée réelle (niveau 4). Les tests unitaires ne vérifient que les niveaux 1-2. Les niveaux 3-4 nécessitent une vérification de câblage.

**Domaines impactés** : tous. Un calculateur `arbitrage_engine.dart` qui existe et passe ses tests unitaires mais n'est jamais appelé depuis un écran = façade. Un `tornado_sensitivity_service.dart` câblé mais qui reçoit toujours des données mock = façade niveau 4.

### M13 — Vérification fraîche obligatoire (Superpowers)

**Quoi** : "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" — un agent ne peut pas dire "c'est fait" sans avoir lancé une commande de vérification DANS LE MÊME message. Pas de claim basée sur la mémoire.

**Pourquoi c'est critique pour MINT** : les boucles Karpathy ont un risque de "green by memory" — l'agent "se souvient" que les tests passaient il y a 3 itérations et ne relance pas. Le pattern vérifié : `autoresearch-quality` relance `flutter test` à chaque itération (conforme). Mais d'autres skills pourraient accumuler des fixes sans vérification intermédiaire.

---

## 4. Cartographie MINT : où en est-on ?

### 4.1 Matrice mécanismes × skills MINT

| Mécanisme | Skill MINT existant | Statut | Couverture |
|-----------|-------------------|--------|------------|
| M1 Cadrage pré-code | aucun | ABSENT | 0% |
| M2 Review auto + auto-fix | `mint-commit` (format only) | PARTIEL | 15% |
| M3 TDD strict | `autoresearch-test-generation` (post-hoc) | INVERSÉ | 0% (tests après, pas avant) |
| M4 Mémoire inter-sessions | aucun | ABSENT | 0% |
| M5 Isolation subagents | boucles Karpathy (contexte unique) | ABSENT | 0% |
| M6 Coverage gate | `autoresearch-test-coverage` (audit-only) | PARTIEL | 30% (détecte mais ne bloque pas) |
| M7 Gestion context window | aucun | ABSENT | 0% |
| M8 Pipeline ship | `mint-commit` + `flutter analyze` + `flutter test` | PARTIEL | 25% |
| M9 Cross-skill comm | `test_gaps.json` (1 lien) | MINIMAL | 10% |
| M10 Retro automatique | aucun | ABSENT | 0% |
| M11 Audit sécurité | `autoresearch-privacy-guard` (PII only) | PARTIEL | 20% |
| M12 Vérification 4 niveaux | aucun (tests unitaires = niveaux 1-2 seulement) | ABSENT | 0% (câblage non vérifié) |
| M13 Vérification fraîche | dans boucles Karpathy (variable) | PARTIEL | 60% |

### 4.2 Ce qui fonctionne bien (ne pas toucher)

**Boucles Karpathy** : le pattern "1 métrique, 1 cible, budget temps fixe, boucle autonome" est absent des 3 frameworks analysés. C'est un avantage MINT. Les 11 boucles couvrent :

| Boucle | Métrique | Domaines couverts |
|--------|----------|-------------------|
| `autoresearch-quality` | flutter test failure count | tous (régression globale) |
| `autoresearch-calculator-forge` | calculation accuracy % | retraite, logement (EPL), fiscalité, couple, archetype |
| `autoresearch-test-generation` | new passing tests | tous (coverage) |
| `autoresearch-compliance-hardener` | compliance pass rate | tous (10 red lines) |
| `autoresearch-prompt-lab` | compliance + quality score | coach AI (tous domaines via prompts) |
| `autoresearch-coach-evolution` | mechanical text score | contenu éducatif (tous domaines) |
| `autoresearch-i18n` | hardcoded string count | i18n (6 langues × tous écrans) |
| `autoresearch-ux-polish` | ux violations count | UI (tous écrans) |
| `autoresearch-navigation` | navigation gap count | routes (18 life events) |
| `autoresearch-test-coverage` | coverage matrix completeness | audit (tous services) |
| `autoresearch-privacy-guard` | PII violations count | données (tous champs) |

**Gouvernance** : la hiérarchie `rules.md → CLAUDE.md → skills/` est plus stricte que GStack (5 couches) et comparable à Superpowers. MINT a l'avantage d'avoir 10 red lines compliance codifiées et un golden couple de test (Julien + Lauren) validé sur 6+ domaines.

**Compliance** : aucun des 3 frameworks n'a d'équivalent au ComplianceGuard, aux termes bannis, aux disclaimers obligatoires, ou aux sources légales (LPP, LIFD, LAVS). C'est un avantage structurel.

---

## 5. Les 7 gaps prouvés

### Gap 1 — Pas de cadrage pré-code

**Preuve** : aucun des 18 skills ne contient de phase "define the problem before coding". Le flow est : recevoir une instruction → coder. Le résultat documenté : "façade sans câblage" (feedback W14) — des composants parfaits individuellement mais jamais connectés.

**Impact multi-domaines** : un simulateur de rachat LPP (travail + logement + retraite) sans cadrage ne vérifie pas que le rachat impacte le calcul EPL. Un simulateur FATCA sans cadrage ne vérifie pas l'interaction avec le 3a.

**Mécanismes applicables** : M1 (GStack `/office-hours` + Superpowers BRAINSTORM).

**Action** : créer un skill `mint-design-review` qui pose 5 questions avant tout sprint : (1) Qui consomme cet output ? (2) Quels calculateurs `financial_core/` sont impactés ? (3) Quels archetypes sont affectés ? (4) Quels life events sont concernés ? (5) Comment le golden couple teste ce changement ?

### Gap 2 — Pas de review code

**Preuve** : `mint-commit` (v2.1) fait : branch flow check → conventional commit format → Co-Authored-By → push. Il ne lit pas le diff. Il ne détecte pas les anti-patterns CLAUDE.md §9. Il ne vérifie pas que `financial_core/` est utilisé au lieu de calculs dupliqués.

**Impact multi-domaines** : une erreur dans `tax_calculator.dart` (utilisé par retraite, logement, arbitrage, couple) passe en production sans détection. Un `Navigator.push` au lieu de `context.go` passe sans détection.

**Mécanismes applicables** : M2 (GStack `/review` — auto-fix + ask).

**Action** : enrichir `mint-commit` ou créer `mint-review` qui analyse le diff pour : (1) calculs dupliqués hors `financial_core/`, (2) hardcoded strings/colors, (3) `Navigator.push`, (4) termes bannis, (5) imports manquants de `financial_core.dart`.

### Gap 3 — TDD absent (tests après, pas avant)

**Preuve** : `autoresearch-test-generation` a pour section Mutable : `test/**/*_test.dart (CREATE only)` et Immutable : `lib/**/*.dart (read-only reference)`. Il crée des tests qui vérifient le comportement EXISTANT du code. Ce n'est pas du TDD — c'est de la couverture rétroactive.

**Impact multi-domaines** : les tests vérifient que `avs_calculator.dart` retourne ce qu'il retourne — pas ce qu'il DEVRAIT retourner selon LAVS art. 21-40. Pour les 8 archetypes, cela signifie que si le code a un bug pour `cross_border` (impôt source), le test va valider le bug.

**Mécanismes applicables** : M3 (Superpowers TDD strict + anti-rationalisation).

**Action** : pour les sprints sur `financial_core/`, imposer une phase TDD : écrire le test avec les valeurs attendues (source : loi suisse, golden couple) AVANT de coder. Intégrer la table anti-rationalisation dans le preamble des skills `calculator-forge` et `test-generation`.

### Gap 4 — Skills qui ne se parlent pas

**Preuve** : `autoresearch-test-coverage` produit un fichier `test_gaps.json`. `autoresearch-test-generation` est censé le consommer. Mais le SKILL.md de `test-generation` ne mentionne pas `test_gaps.json` — il scanne lui-même les fichiers avec `find`. Les deux skills font un travail redondant de détection.

**Impact multi-domaines** : les 11 boucles redécouvrent le même état du monde à chaque session. `compliance-hardener` ne sait pas que `calculator-forge` a déjà validé un scénario AVS. `ux-polish` ne sait pas que `i18n` a déjà extrait les strings d'un fichier.

**Mécanismes applicables** : M4 (learnings.jsonl) + M9 (bus inter-skills).

**Action** : créer un fichier partagé `.claude/skill-state.jsonl` (append-only, format : `{skill, timestamp, type, key, data}`). Chaque boucle Karpathy y écrit ses résultats. Chaque boucle le lit au démarrage. Dedup par key+type comme GStack.

### Gap 5 — Pas de mémoire dans les skills

**Preuve** : aucun des 18 fichiers SKILL.md ne contient de section "learnings" ou de référence à un fichier de mémoire. Chaque session part de zéro.

**Impact multi-domaines** : `autoresearch-calculator-forge` reteste les mêmes scénarios edge-case (couple marié AVS cap 150%, EPL min 20k, 3a max 7'258) sans savoir qu'ils ont été validés hier. Perte de temps proportionnelle au nombre de sessions.

**Mécanismes applicables** : M4 (GStack `learnings.jsonl` avec confidence + decay).

**Action** : ajouter à chaque boucle Karpathy une étape finale "append learning" et une étape initiale "load learnings". Format : `{key, type, confidence, timestamp, detail}`. Decay de 1 point de confidence tous les 30 jours. Seuil : ignorer si confidence < 3.

### Gap 6 — Pipeline de ship minimal

**Preuve** : le flow de ship est : `flutter analyze` (0 errors) → `flutter test` → `git commit`. Pas de coverage gate chiffré. Pas de Test Halt Loop pour les tests flaky. Pas de smoke test post-deploy. Pas de changelog automatique.

**Impact multi-domaines** : un service critique (`withdrawal_sequencing_service.dart`) peut être déployé avec 0 tests. Les tests flaky (identifiés dans les sprints précédents) ne sont pas isolés automatiquement.

**Mécanismes applicables** : M6 (coverage gate) + M8 (pipeline structuré).

**Action** : ajouter à `mint-commit` : (1) un check "nouveaux fichiers `lib/services/` → test correspondant existe ?", (2) un seuil de couverture par service (minimum 10 tests, déjà dans CLAUDE.md mais pas vérifié mécaniquement), (3) détection de tests flaky (même test échoue puis passe = flag).

### Gap 7 — Pas de gestion du context window

**Preuve** : les boucles Karpathy acceptent un paramètre N (nombre d'itérations). `autoresearch-test-generation 100` = 100 itérations dans un seul contexte. Aucun mécanisme ne détecte la dégradation de qualité quand le contexte se remplit. Aucun skill ne délègue à un sous-agent frais.

**Impact multi-domaines** : les sprints longs sur des domaines complexes (fiscalité cantonale, archetypes multiples) accumulent du contexte. L'itération 80 d'un `calculator-forge 100` est significativement moins fiable que l'itération 5.

**Mécanismes applicables** : M5 (isolation subagents) + M7 (context budget).

**Action** : ajouter aux boucles Karpathy un compteur de contexte estimé. Au-delà de 30 itérations, recommander un restart avec les learnings chargés. Alternative : découper N=100 en 4×25 avec passage de `skill-state.jsonl` entre les sessions.

---

## 6. Les 6 forces que MINT a et que personne n'a

### Force 1 — Boucles Karpathy autonomes (11 boucles)

Aucun des 3 frameworks n'a de boucle autonome comparable. GStack a des phases séquentielles. Superpowers a des subagents mais pas de boucle autoresearch. GSD a des agents spécialisés mais sans le pattern "1 métrique, 1 cible, budget temps, boucle".

Le pattern MINT `measure → act → verify → repeat` avec une seule métrique mutable est plus rigoureux que les approches génériques. Chaque boucle a un contrat clair : ce qui est mutable, ce qui est immutable, quel est le critère d'arrêt.

### Force 2 — Compliance Swiss-grade codifiée

10 red lines avec severity scoring (CRITICAL/HIGH). Termes bannis mécaniquement détectables. Disclaimers obligatoires avec sources légales. ComplianceGuard comme filtre LLM. Aucun framework n'a d'équivalent — GStack a `/cso` pour la sécurité technique, mais pas de compliance métier.

Pour les 18 life events, cela signifie que chaque output (retraite, logement, famille, fiscalité) est soumis aux mêmes contraintes : pas de promesse, pas de conseil, pas de classement.

### Force 3 — Golden couple validé multi-domaines

Julien (swiss_native, 49 ans, CPE Plan Maxi, VS) + Lauren (expat_us/FATCA, 43 ans, HOTELA, VS) testent simultanément : AVS couple (cap 150%), LPP (2 caisses différentes), fiscalité (capital withdrawal + FATCA), logement (EPL), 3a, et les interactions entre domaines.

Aucun framework n'a de "golden test persona" — ils testent du code, pas des scénarios métier.

### Force 4 — 8 archetypes financiers avec détection

Le système d'archetypes (swiss_native, expat_eu, expat_non_eu, expat_us, independent_with_lpp, independent_no_lpp, cross_border, returning_swiss) avec détection automatique est un pattern métier que les frameworks de dev ne peuvent pas fournir. Chaque archetype modifie les calculs dans tous les domaines.

### Force 5 — 75 gates d'audit parallélisées

`mint-audit-complet` orchestre 5 équipes (actuariat, juridique, UX, 3 piliers, DevOps) avec 75 gates au total. C'est plus large que le `/cso` de GStack (14 phases sécurité) et plus structuré que le review de Superpowers (spec + quality).

### Force 6 — Gouvernance hiérarchique à 10 niveaux

La hiérarchie `rules.md → CLAUDE.md → skills/` avec résolution de conflits explicite ("si le code contredit 1-9, corriger le code OU écrire une ADR") est plus formalisée que les 5 couches de GStack. La hiérarchie de résolution est plus formalisée que les 5 couches de GStack.

---

## 7. Recommandations par priorité

### Priorité 1 — Impact immédiat, effort modéré

| # | Recommandation | Source | Effort | Impact |
|---|---------------|--------|--------|--------|
| R1 | Ajouter `learnings.jsonl` aux 11 boucles Karpathy | GStack M4 | 2-3h par skill (preamble + append + load) | Élimine le travail redondant cross-sessions. DoD : chaque boucle lit les learnings au démarrage et en écrit au moins 1 par session. |
| R2 | Enrichir `mint-commit` avec analyse du diff | GStack M2 | 4-6h (grep patterns sur diff) | Détecte anti-patterns avant merge. DoD : `mint-commit` refuse si calcul dupliqué hors `financial_core/`, hardcoded color/string, ou `Navigator.push` détecté. |
| R3 | Ajouter un seuil context window aux boucles | GSD M7 | 1-2h par skill (compteur + warning) | Évite la dégradation qualité en fin de boucle. DoD : warning émis après 25 itérations, arrêt recommandé après 35. |

### Priorité 2 — Impact structurel, effort significatif

| # | Recommandation | Source | Effort | Impact |
|---|---------------|--------|--------|--------|
| R4 | Créer `mint-design-review` (cadrage pré-code) | GStack+Superpowers M1 | 1 sprint | Élimine le piège "façade sans câblage" |
| R5 | Créer `skill-state.jsonl` (bus inter-skills) | GStack M4 + M9 | 1 sprint (format + intégration 11 skills) | Les boucles se parlent enfin |
| R6 | Phase TDD pour `financial_core/` | Superpowers M3 | 2-3h par sprint | Tests spécifient le comportement correct, pas l'existant. DoD : chaque nouveau calcul a un test RED avant le code GREEN. |
| R7 | Anti-rationalisation dans preamble des boucles Karpathy | Superpowers M3 | 1h (texte dans SKILL.md) | Bloque les excuses courantes. DoD : 6 excuses listées dans chaque boucle `financial_core`. |
| R8 | Vérification fraîche obligatoire (M12) dans tous les skills | Superpowers M12 | 2h | Aucun skill ne dit "fait" sans commande de vérification dans le même message. DoD : grep "MUST run" dans chaque SKILL.md. |

### Priorité 3 — Amélioration continue

| # | Recommandation | Source | Effort | Impact |
|---|---------------|--------|--------|--------|
| R9 | Retro automatique post-sprint | GStack M10 | 4h (script git log analysis) | Détection hotspots + vélocité. DoD : rapport JSON avec fichiers chauds + vélocité commit. |
| R10 | Coverage gate bloquant dans `mint-commit` | GStack M6 | 2h (check test exists for new service) | Empêche le déploiement sans tests. DoD : `mint-commit` refuse si nouveau service sans test. |
| R11 | Audit sécurité étendu (OWASP + secrets) | GStack M11 | 1 sprint | Couvre les angles morts de `privacy-guard`. DoD : rapport OWASP Top 10 avec 0 findings CRITICAL. |

### Ce qu'il ne faut PAS importer

| Mécanisme | Pourquoi pas |
|-----------|-------------|
| GStack `/qa` (Chromium headless) | MINT est une app mobile Flutter, pas une webapp. Les tests Flutter widget suffisent. |
| Superpowers WORKTREES | Les boucles Karpathy de MINT sont déjà plus sophistiquées que le pattern worktree+subagent. |
| GSD model profiles (Opus/Sonnet/Haiku) | MINT a déjà une répartition Team Lead (Opus) / agents (Sonnet) dans CLAUDE.md §10. |
| GStack `/office-hours` complet | Les 6 questions YC sont orientées startup pitch, pas fintech suisse. Adapter, ne pas copier. |
| Hooks bloquants GSD | Les boucles Karpathy ont déjà des guards non-bloquants qui fonctionnent. |

---

## 8. Matrice croisée : mécanismes × domaines de vie

Cette matrice vérifie que chaque recommandation couvre tous les domaines MINT, pas seulement la retraite.

| Mécanisme | Retraite | Logement | Famille | Fiscalité | Patrimoine | Carrière | Dette | Mobilité | Santé |
|-----------|----------|----------|---------|-----------|------------|---------|-------|----------|-------|
| M1 Cadrage | spec AVS/LPP | spec EPL/hypothèque | spec couple/naissance | spec LIFD/cantonal | spec succession | spec indépendant | spec mode safe | spec frontalier | spec invalidité |
| M2 Review | calculs retraite | calculs mortgage | caps couple | tax calc | arbitrage | archetype check | seuils dette | permis G | LAMal |
| M3 TDD | golden couple | EPL min 20k | AVS cap 150% | barème progressif | donation/héritage | LPP bonif. | taux endettement | convention bilat. | rente invalidité |
| M4 Mémoire | "AVS validé" | "EPL testé" | "couple cap OK" | "FATCA audité" | "succession OK" | "indép. LPP OK" | "safe mode OK" | "frontalier OK" | "invalidité OK" |
| M5 Isolation | projection longue | simulation 30 ans | scénarios couple | 26 cantons | Monte Carlo | 8 archetypes | analyse dette | 2+ pays | multi-assurance |
| M6 Coverage | 3 calculateurs | tax + arbitrage | avs_calculator | tax_calculator | monte_carlo | lpp_calculator | budget_service | expat_service | disability (todo) |
| M7 Context | boucle 50+ tests | boucle hypothèque | boucle couple | boucle 26 cantons | boucle Monte Carlo | boucle archetype | boucle dette | boucle mobilité | boucle santé |

**Constat** : chaque mécanisme s'applique à tous les domaines. Aucune recommandation n'est "retraite-only". La force du pattern Karpathy est justement sa généricité : une boucle `calculator-forge` teste aussi bien l'AVS que l'EPL ou le barème fiscal.

---

## 9. Verdict

### La question : "Comment ces frameworks aident MINT à devenir la meilleure app fintech suisse ?"

**Réponse en 3 points** :

**1. MINT a un avantage structurel que les frameworks ne fournissent pas** : compliance codifiée, golden couple, archetypes, boucles Karpathy. Ces 4 piliers n'existent dans aucun des 3 frameworks. Ils sont le socle — il ne faut pas les remplacer.

**2. MINT a 7 gaps que les frameworks résolvent** : cadrage pré-code (GStack+Superpowers), review automatique (GStack), TDD (Superpowers), mémoire inter-sessions (GStack+GSD), isolation subagents (Superpowers+GSD), coverage gate (GStack), gestion context window (GSD). Ces gaps sont réels, documentés (W14 "façade sans câblage", sessions redondantes, context rot) et les solutions existent.

**3. L'ordre d'implémentation compte** : les 3 recommandations P1 (learnings, review enrichie, seuil context) sont implémentables en 1 sprint et éliminent les pertes les plus visibles. Les 3 P2 (cadrage, bus inter-skills, TDD) sont structurelles et requièrent un sprint dédié. Les 4 P3 (retro, coverage gate, anti-rationalisation, audit sécurité) sont de l'amélioration continue.

### Progression attendue

| Dimension | Avant | Après P1 | Après P1+P2 | Après P1+P2+P3 |
|-----------|-------|----------|-------------|-----------------|
| Mécanismes couverts (sur 12) | 3/12 (25%) | 6/12 (50%) | 9/12 (75%) | 12/12 (100%) |
| Travail redondant cross-sessions | Élevé (aucune mémoire) | Réduit (learnings chargés) | Minimal (bus inter-skills) | Négligeable |
| Détection bugs avant merge | Tests uniquement | Tests + review diff | Tests + review + cadrage | + retro + coverage gate |
| Couverture domaines | 18/18 life events | 18/18 | 18/18 | 18/18 |

### Ce que MINT doit garder tel quel

- Les 11 boucles Karpathy (pattern unique, supérieur aux alternatives)
- La hiérarchie de gouvernance à 10 niveaux
- Le golden couple comme fixture de test multi-domaines
- Les 10 red lines compliance avec ComplianceGuard
- Le pattern "1 métrique, 1 cible, budget temps" des boucles

### Ce que MINT doit importer

- La mémoire `learnings.jsonl` (GStack) → adaptée en `skill-state.jsonl`
- Le cadrage pré-code (GStack+Superpowers) → adapté en `mint-design-review`
- La review de diff (GStack) → intégrée dans `mint-commit`
- L'anti-rationalisation TDD (Superpowers) → intégrée dans les preambles
- La gestion du context window (GSD) → compteur + seuil dans les boucles
- Le bus inter-skills → `skill-state.jsonl` partagé

### Ce que MINT doit ignorer

- Chromium headless QA (pas pertinent pour Flutter mobile)
- Model profiles (déjà géré via la répartition Opus/Sonnet)
- Questions YC telles quelles (adapter au contexte fintech suisse)
- Hooks bloquants GSD (les boucles Karpathy ont des guards non-bloquants qui fonctionnent)
- Worktrees Superpowers complètes (mais le pattern d'isolation par subagent frais — R3/M7 — est retenu)

**Note sur les hooks Claude Code** : les recommandations R2 (review diff) et R3 (seuil context) peuvent être implémentées comme des hooks natifs dans `settings.json` (PreToolUse/PostToolUse), ce qui est plus léger que de modifier chaque SKILL.md. C'est le pattern exact de GSD.

---

> Ce document est une référence interne. Il ne constitue pas un plan d'exécution.
> Pour transformer ces recommandations en sprint, créer un ticket par recommandation Rx avec les critères de CLAUDE.md §4 (branch flow, tests, analyze).
