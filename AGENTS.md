# AGENTS.md — MINT Dream Team (Agent Teams Mode)

**Date** : 9 février 2026 (mis à jour)
**Mode** : Claude Code Agent Teams + Dream Team parallel agents
**Statut** : S20 shipped, S21 next

---

## ARCHITECTURE D'ÉQUIPE

```
┌─────────────────────────────────────────────────────┐
│                   TEAM LEAD (toi)                    │
│              Claude Opus — session principale        │
│                                                      │
│  Rôle : Orchestrer, reviewer, décider, merger        │
│  Ne code PAS directement (sauf urgence)              │
└──────────┬──────────┬──────────┬────────────────────┘
           │          │          │
     ┌─────▼──┐ ┌─────▼──┐ ┌────▼─────┐
     │ DART   │ │ PYTHON │ │  SWISS   │
     │ Agent  │ │ Agent  │ │  BRAIN   │
     │        │ │        │ │          │
     │Sonnet  │ │Sonnet  │ │ Opus     │
     └────────┘ └────────┘ └──────────┘
```

---

## COMMENT LANCER L'ÉQUIPE

### Étape 1 — Vérifier que l'agent team est activé
Le fichier `~/.claude/settings.json` doit contenir :
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Étape 2 — Spawner les teammates selon le chantier

> **IMPORTANT : Skills** — Chaque teammate doit lire le skill correspondant dans `.claude/skills/`
> en plus des fichiers de base. Les skills contiennent les patterns, conventions et pièges connus.

**Pour un chantier Flutter (UI, widgets, screens) :**
```
Spawn a teammate named "dart-agent" with model sonnet.
Prompt: "Tu es le Flutter/Dart engineer de MINT.
Lis ces fichiers AVANT d'agir :
1. .claude/skills/mint-flutter-dev/SKILL.md (patterns Flutter MINT, UI kit, conventions)
2. .claude/skills/mint-test-suite/SKILL.md (comment lancer et fixer les tests)
3. AGENTS.md, rules.md, SOT.md
Tu travailles exclusivement dans apps/mobile/. Tu suis le pattern existant du projet.
Avant chaque changement : flutter analyze && flutter test.
Ne touche JAMAIS au backend."
```

**Pour un chantier Backend (FastAPI, rules_engine, tax) :**
```
Spawn a teammate named "python-agent" with model sonnet.
Prompt: "Tu es le Backend Python engineer de MINT.
Lis ces fichiers AVANT d'agir :
1. .claude/skills/mint-backend-dev/SKILL.md (patterns backend MINT, rules_engine, schemas)
2. .claude/skills/mint-test-suite/SKILL.md (comment lancer et fixer les tests)
3. AGENTS.md, rules.md, SOT.md
Tu travailles exclusivement dans services/backend/.
Avant chaque changement : ruff check . && pytest -q.
Ne touche JAMAIS au code Flutter.
Si tu changes un contrat API, mets à jour tools/openapi/mint.openapi.yaml ET SOT.md."
```

**Pour un chantier métier complexe (fiscalité, LPP, divorce, compliance) :**
```
Spawn a teammate named "swiss-brain" with model opus.
Prompt: "Tu es l'expert finance suisse et compliance de MINT.
Lis ces fichiers AVANT d'agir :
1. .claude/skills/mint-swiss-compliance/SKILL.md (droit suisse, mots interdits, format specs)
2. AGENTS.md, rules.md, AGENT_SYSTEM_PROMPT.md, LEGAL_RELEASE_CHECK.md
3. Tous les visions/*.md
Tu ne codes PAS. Tu produis :
1. Les règles de calcul exactes avec sources juridiques (articles de loi)
2. Les cas de test avec valeurs attendues
3. Les textes éducatifs conformes (pas de 'garanti', 'optimal', etc.)
4. Les alertes compliance si un teammate propose du code non conforme.
Tu es le garde-fou. Si un calcul est faux ou un wording non conforme, tu bloques."
```

### Étape 3 — Assigner les tâches via TaskCreate

Le Team Lead crée les tâches, les assigne, et les teammates les exécutent :
```
Crée 3 tâches :
1. "dart-agent: Créer l'écran SimulateurRenteCapital avec les champs du wireframe"
2. "python-agent: Implémenter compute_rente_vs_capital() dans rules_engine.py"
3. "swiss-brain: Valider les formules LPP et fournir 5 cas de test avec valeurs exactes"
Tâche 1 est bloquée par 2. Tâche 2 est bloquée par 3.
```

---

## LES 3 TEAMMATES — FICHES DE POSTE

### 🔹 DART-AGENT (Flutter/Dart Engineer)

**Modèle** : Sonnet (économie tokens)
**Scope** : `apps/mobile/` uniquement
**Compétences** :
- Widgets Flutter, Material 3, responsive
- State management (Provider — pattern existant du projet)
- Navigation GoRouter (pattern existant)
- Tests widget + golden tests

**Règles strictes** :
- Lire le code existant AVANT de créer un nouveau widget
- Réutiliser les widgets de `lib/widgets/mint_ui_kit.dart`
- Respecter le thème de `lib/theme/colors.dart`
- Chaque nouvel écran = 1 test smoke minimum
- `flutter analyze` doit passer à 0 warning
- Ne jamais hardcoder de strings (préparer pour i18n)

**Skill** : `.claude/skills/mint-flutter-dev/SKILL.md`

**Fichiers de référence à lire en premier** :
- `.claude/skills/mint-flutter-dev/SKILL.md` (conventions, UI kit, pièges connus)
- `.claude/skills/mint-test-suite/SKILL.md` (tests Flutter, patterns d'erreur)
- `apps/mobile/lib/app.dart` (routing)
- `apps/mobile/lib/widgets/mint_ui_kit.dart` (composants réutilisables)
- `apps/mobile/lib/theme/colors.dart` (palette)
- `apps/mobile/lib/models/` (modèles de données)

---

### 🔹 PYTHON-AGENT (Backend FastAPI Engineer)

**Modèle** : Sonnet (économie tokens)
**Scope** : `services/backend/` uniquement
**Compétences** :
- FastAPI, Pydantic v2, async Python
- Rules engine (logique métier financière)
- Tests pytest, fixtures
- OpenAPI spec maintenance

**Règles strictes** :
- Fonctions pures pour tout calcul financier (testable, déterministe)
- Chaque nouvelle règle de calcul = test avec valeur attendue hardcodée
- Pas de dépendance lourde sans validation du Team Lead
- `ruff check .` et `pytest -q` doivent passer
- Si un endpoint change → mettre à jour `tools/openapi/mint.openapi.yaml`
- Docstrings obligatoires sur les fonctions de calcul (hypothèses + sources)

**Skill** : `.claude/skills/mint-backend-dev/SKILL.md`

**Fichiers de référence à lire en premier** :
- `.claude/skills/mint-backend-dev/SKILL.md` (conventions backend, patterns rules_engine)
- `.claude/skills/mint-test-suite/SKILL.md` (tests pytest, erreurs courantes)
- `services/backend/app/services/rules_engine.py` (moteur de règles)
- `services/backend/app/schemas/` (modèles Pydantic)
- `services/backend/app/api/v1/` (endpoints)
- `tools/openapi/mint.openapi.yaml` (contrat API)
- `SOT.md` (source de vérité données)

---

### 🔹 SWISS-BRAIN (Expert Finance Suisse & Compliance)

**Modèle** : Opus (raisonnement complexe requis)
**Scope** : Transversal — review, règles, textes, tests
**Compétences** :
- Droit suisse (LPP, LIFD, LAVS, LAMal, CC successions)
- Fiscalité fédérale + cantonale (26 cantons)
- Prévoyance professionnelle (2e et 3e pilier)
- Behavioral finance, nudges, JIT education
- Compliance FINMA, LPD

**Règles strictes** :
- Chaque affirmation juridique doit citer la source (loi, article, alinéa)
- Chaque calcul doit être vérifié contre une source officielle
- Wording conforme à `LEGAL_RELEASE_CHECK.md` : pas de "garanti", "optimal", "meilleur"
- Chaque recommandation doit avoir un disclaimer
- Safe Mode : si dette toxique détectée, désactiver les optimisations

**Skill** : `.claude/skills/mint-swiss-compliance/SKILL.md`

**Output attendu (pas de code, mais) :**
```
1. SPEC CALCUL :
   Formule : rente_annuelle = avoir_vieillesse × taux_conversion
   Source : LPP art. 14 al. 2
   Taux conversion minimum obligatoire : 6.8% (LPP art. 14 al. 2)

2. CAS DE TEST :
   | Avoir     | Taux  | Rente attendue | Note                    |
   |-----------|-------|----------------|-------------------------|
   | 500'000   | 6.8%  | 34'000/an      | Part obligatoire seule  |
   | 500'000   | 5.0%  | 25'000/an      | Taux enveloppe typique  |

3. TEXTE ÉDUCATIF :
   "Le taux de conversion détermine combien de rente annuelle vous recevrez
    pour chaque franc accumulé dans votre caisse de pension. Le minimum légal
    est de 6.8% sur la part obligatoire, mais de nombreuses caisses appliquent
    un taux inférieur sur la part surobligatoire."

4. ALERTE COMPLIANCE :
   ⚠️ Ne pas écrire "votre rente sera de X" → écrire "votre rente estimée serait d'environ X"
```

---

## PROTOCOLE DE TRAVAIL EN ÉQUIPE

### Règle 1 : Le Team Lead ne code pas (sauf urgence)
Le Team Lead orchestre, review, et merge. Il crée les tâches, vérifie les outputs, et tranche les décisions.

### Règle 2 : Swiss-Brain valide AVANT que les devs implémentent
Workflow obligatoire pour tout chantier métier :
```
Swiss-Brain (spec + cas de test)
    → Python-Agent (implémentation backend)
        → Dart-Agent (UI/écran Flutter)
            → Team Lead (review + merge)
```

### Règle 3 : Économie de tokens (budget Pro $20/mois)
- Teammates en **Sonnet** par défaut (sauf Swiss-Brain en Opus)
- Ne spawner que les teammates nécessaires au chantier en cours
- Un teammate à la fois si possible (sauf chantiers indépendants)
- Préférer les tâches bien définies et courtes aux prompts vagues
- Utiliser `haiku` pour les tâches triviales (formatting, renommage)

### Règle 4 : Convention de commit
Chaque teammate prefixe ses commits :
- `[dart]` : changements Flutter
- `[py]` : changements backend
- `[spec]` : specs, textes éducatifs, cas de test
- `[infra]` : config, CI, settings

### Règle 5 : Fichiers interdits de modification croisée
| Teammate | Peut modifier | NE PEUT PAS modifier |
|----------|--------------|----------------------|
| dart-agent | `apps/mobile/` | `services/backend/`, `tools/openapi/` |
| python-agent | `services/backend/`, `tools/openapi/`, `SOT.md` | `apps/mobile/` |
| swiss-brain | `docs/`, `education/`, `decisions/`, `visions/` | Code (`*.dart`, `*.py`) |

---

## SPRINT ROADMAP (actualisé 9 février 2026)

### Sprints livrés (S0-S20)

| Sprint | Module | Commit | Tests |
|--------|--------|--------|-------|
| S0-S8 | Core, Budget, RAG, Bank Import, i18n DE | various | ~600 |
| S9 | Job Change LPP Comparator | `6e37675` | +20 |
| S10 | Divorce + Succession | `92bb677` | +30 |
| S11 | Proactive Coaching Engine | `8e2f2d3` | +25 |
| S12 | Sociological Segments | `3eb7a00` | +20 |
| S13 | LAMal Franchise Optimizer | `1ef929d` | +30 |
| S14 | Open Banking bLink/SFTI | `49c64be` | +25 |
| S15 | LPP Deep Dive (rachat, LP, EPL) | `8259894` | +50 |
| S16 | 3a Deep + Debt Prevention | `aa9b607` | +59 |
| S17 | Mortgage + Real Estate (5 services) | `71460f9` | +68 |
| S18 | Indépendants complet (5 services) | `5ed7c24` | +66 |
| S19 | Chômage + Premier emploi | — | — |
| S20 | Fiscalité cantonale (26 cantons) | — | — |

**Total backend tests : ~876 passed**
**Flutter analyze : 0 errors**

### Sprints à venir

| Sprint | Module | Événement de vie | Cible |
|--------|--------|-----------------|-------|
| S21 | Retraite complète | `retirement` → L4 | AVS+LPP+3a: rente vs capital, planification |
| S22 | Mariage + Naissance + Concubinage | famille → L3+ | Splitting, allocations, testament |

### Dream Team workflow actuel

Le pattern éprouvé depuis S10 :
```
1. Lire PLAN_ACTION_10_CHANTIERS.md pour le scope du sprint
2. Lancer 2 agents en parallèle :
   - Backend agent (general-purpose, bypassPermissions)
   - Flutter agent (general-purpose, bypassPermissions)
3. Vérifier le baseline (tests + analyze) pendant que les agents bossent
4. Senior audit : cross-check backend vs Flutter (10-20 points de contrôle)
5. Fixer toutes les divergences CRIT
6. Lancer les tests + flutter analyze
7. Commit chirurgical (seulement les fichiers du sprint)
```

**Résultat typique** : 10-15 fichiers, 50-70 tests, 5-10 CRIT fixés par sprint

---

## SKILLS (Agent Skills — `.claude/skills/`)

Les skills sont des instructions spécialisées chargées automatiquement par Claude Code.
Chaque teammate DOIT lire le skill correspondant à son rôle avant de travailler.

| Skill | Fichier | Pour qui |
|-------|---------|----------|
| **mint-flutter-dev** | `.claude/skills/mint-flutter-dev/SKILL.md` | dart-agent |
| **mint-backend-dev** | `.claude/skills/mint-backend-dev/SKILL.md` | python-agent |
| **mint-swiss-compliance** | `.claude/skills/mint-swiss-compliance/SKILL.md` | swiss-brain |
| **mint-test-suite** | `.claude/skills/mint-test-suite/SKILL.md` | tous (tests) |
| **mint-commit** | `.claude/skills/mint-commit/SKILL.md` | team-lead (commits) |

Les skills contiennent :
- Les patterns et conventions du projet
- Les pièges connus et leurs solutions
- Les commandes de référence
- Les checklists par type de tâche

---

## HIÉRARCHIE DE VÉRITÉ (Immutable)

En cas de conflit, l'ordre de priorité est :
1. **rules.md** — Règles techniques et éthiques non-négociables
2. **AGENTS.md** (ce fichier) — Mode opératoire obligatoire
3. **`.claude/skills/`** — Conventions et patterns techniques
4. **LEGAL_RELEASE_CHECK.md** — Wording compliance
5. **visions/** — Intention produit + limites
6. **decisions/** (ADR) — Décisions d'architecture validées
7. **SOT.md** — Source of Truth des modèles de données
8. **Code** — L'implémentation se plie aux documents, pas l'inverse

---

## ANTI-PATTERNS (ce qu'on ne fait JAMAIS)

1. **Coder sans spec** — Swiss-Brain produit la spec, PUIS on code
2. **Paralléliser quand c'est inutile** — Sur budget Pro, mieux vaut 1 agent bien guidé que 3 en parallèle qui brûlent des tokens
3. **Ignorer les tests qui échouent** — Si `flutter test` ou `pytest` fail, on fix AVANT de continuer
4. **Créer des fichiers inutiles** — Préférer modifier l'existant
5. **Toucher à SOT.md/OpenAPI sans le dire** — Toujours notifier le Team Lead
6. **Promettre des rendements** — Scénarios (Bas/Moyen/Haut) + disclaimers, toujours

---

## DREAM TEAM ÉLARGIE (agents parallélisables)

Au-delà des 3 teammates engineering (dart-agent, python-agent, swiss-brain),
ces agents peuvent être lancés en parallèle des sprints pour accélérer MINT :

### Phase actuelle — lançables dès maintenant

| Agent | Mission | Output | Quand |
|-------|---------|--------|-------|
| **QA Agent** | Augmenter la couverture de tests, fuzzing edge cases financiers | Tests supplémentaires, rapport de couverture | Après chaque sprint |
| **Content Agent** | Générer articles éducatifs à partir de `education/inserts/` | 10-15 articles blog, FAQ structurée | En parallèle de S18+ |
| **i18n Agent** | Compléter la localisation DE (commencée S5) | Fichiers .arb, audit traductions | En parallèle de S19+ |
| **Accessibility Agent** | Audit WCAG 2.1 AA sur tous les écrans | Rapport a11y, fixes contrast/VoiceOver | Avant beta |

### Phase pré-lancement — à planifier

| Agent | Mission | Output | Quand |
|-------|---------|--------|-------|
| **ASO Agent** | Fiches App Store / Play Store (FR+DE), mots-clés | Store listings, screenshots descriptions | 4 sem avant launch |
| **Design System Agent** | Auditer cohérence visuelle 30+ écrans, Widgetbook | Design audit, composants unifiés | 2 sem avant beta |
| **Growth Agent** | Système parrainage, analytics events (PostHog) | Referral flow, event tracking plan | Post-beta |
| **Legal Agent** | Audit LPD/nLPD, CGU, politique de confidentialité | Documents légaux finalisés | Avant launch |

### Comment lancer un agent parallèle

```
Spawn background agent:
Task(subagent_type="general-purpose", run_in_background=true, prompt="...")
```

Chaque agent doit lire `CLAUDE.md` en premier pour avoir le contexte complet.
Le Team Lead review toujours l'output avant merge.

---

## DOCUMENTS DE RÉFÉRENCE

| Document | Rôle | Quand le lire |
|----------|------|---------------|
| `CLAUDE.md` | Contexte auto-chargé (constantes, compliance, architecture) | Automatique |
| `AGENTS.md` | Workflow équipe, rôles, sprint tracker | Début de session |
| `rules.md` | Règles non-négociables (commandes, workflow, fintech-grade) | Avant tout changement |
| `visions/vision_product.md` | Mission, promesse, North Star metric | Pour décisions produit |
| `visions/vision_features.md` | Specs fonctionnelles, screen contracts | Pour nouveaux écrans |
| `visions/vision_compliance.md` | Cadre légal, FINMA, LPD | Pour compliance check |
| `docs/PLAN_ACTION_10_CHANTIERS.md` | Scope détaillé de chaque sprint | Pour planifier un sprint |
| `docs/ROADMAP_EVENEMENTS_VIE.md` | 18 événements de vie, matrice couverture | Pour scope événements |
| `LEGAL_RELEASE_CHECK.md` | Wording compliance, mots interdits | Avant tout texte user-facing |
| `DefinitionOfDone.md` | Critères de qualité par sprint | Pour valider un livrable |
