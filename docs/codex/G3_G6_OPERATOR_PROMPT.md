# MINT — Prompt opérateur G3 → produit-G6

Status: Draft operator prompt. Repo reality wins over this document.

Objectif : lancer les G produits restants sans théâtre de preuve. Chaque
critère ci-dessous doit produire une commande, un fichier de preuve, ou un
`FAIL` explicite dans le scorecard.

## Lire avant d'agir

- `CLAUDE.md`.
- `AGENTS.md` §Operating Mode.
- `docs/MINT_AGENT_WORKFLOW.md`.
- `docs/codex/{DATA_LEDGER,DATA_QUEST,SCREEN_CONTRACTS,MAESTRO_FLOWS}.md`.
- `docs/codex/SCREEN_CONTRACTS.md` §0 HARD RULE pour `extra`.
- `docs/codex/INTERACTION_REGISTRY.md` reste Proposed : ne pas implémenter.
- Mémoire : repo git/docs/ADR/agents = source de vérité ; Engram = rappel,
  jamais source primaire.

## 0. Pré-vol bloquant

1. Atterrir ou rebaser les trains avant de coder.
   - Base intégrée minimale à ce prompt : #836 (spec reality), #842 (gitleaks),
     #868 (Interaction Registry Proposed).
   - Commande de réalité : `gh pr list --repo MINT-IA/MINT --base claude/mint-swiss-coach-eu33i7`.
   - Les branches draft restantes sont des carrières : inspecter, extraire une
     tranche courte, ne jamais merger en bloc.
   - Legacy #849 est superseded par #868 pour `INTERACTION_REGISTRY.md` ; ne pas
     l'utiliser comme autorité d'exécution.
   - Preuve scorecard : `gh pr checks <num>` exit 0 pour chaque PR intégrée.

2. Réglementaire avant goldens G4/G5.
   - Commande :
     `cd services/backend && python3 -m pytest tests/test_regulatory_registry.py -q`
   - Mesure :
     `python3 - <<'PY'` puis `RegulatoryRegistry.instance().count()` et
     `len(RegulatoryRegistry.instance().check_freshness())`.
   - Ne pas figer un compte depuis un ancien HEAD : mesurer dans le checkout
     courant, puis exiger 100 % des entrées `reviewed_at` fraîches, ou un pin
     `taxYear=2026` documenté sous
     `.planning/phases/<G>/regulatory-freshness-waiver.md`.
   - Tant que cette étape échoue, aucun golden capacité/succession/donation ne
     peut servir de preuve produit.

3. Spec swiss-brain avant code.
   - Artefact obligatoire : `.planning/phases/<G>/swiss-brain-spec.md`.
   - Pour G5, la spec liste les 6 défauts `swiss_native` à neutraliser avec
     `file:line` et cite le log source exact :
     `.planning/runtime-evidence/mint-lucidity-claude-architecture-audit-20260703T170229/claude-architecture-audit.txt`.
   - Absence de spec = scorecard `FAIL`.

4. Gate single-write-path obligatoire.
   - Avant tout G qui écrit le ledger, livrer ou réutiliser
     `tools/checks/no_bypass_persistence.py` implémentant `DATA_LEDGER.md` §8.3
     et câblé dans Lefthook pour les fichiers Dart touchés.
   - Commande scorecard : `python3 tools/checks/no_bypass_persistence.py`.
   - Le gate échoue si une écriture de clé domaine ou `wizard_answers_v2` passe
     hors `report_persistence_service.dart` et `coach_profile_provider.dart`.
     `budget_local_store.dart` reste cache non autoritatif et ne peut pas écrire
     `wizard_answers_v2`.

5. PR courte, preuve archivée.
   - Mesure : `git diff --shortstat origin/<base>...HEAD`.
   - Cible : moins de 300 insertions nettes. Split si au-delà.
   - Toute preuve runtime va sous `.planning/runtime-evidence/<G>-<slug>/`.

## 1. Exit criteria de chaque PR produit

1. `flutter analyze` : 0 nouvelle issue, plus tests ciblés et shards CI verts.
2. `python3 tools/checks/arb_parity.py` si ARB touchés.
3. Accents FR et termes LSFin : gates hook/CI verts.
4. Constantes et taux :
   - Toute nouvelle constante cite `registry.py` ou `financial_core` avec
     `file:line` dans le scorecard.
   - Revue quality-gate :
     `rg -nE '0\\.0[1-9]|rate\\s*=\\s*[0-9]|taux\\s*=\\s*[0-9]' <fichiers touchés>`.
5. Calculs :
   - Mobile : `apps/mobile/lib/services/financial_core/`.
   - Backend : service miroir testé.
   - Interdit : créer une nouvelle classe `TaxCalculator` pour satisfaire un
     texte ancien. Le nom réel est
     `RetirementTaxCalculator.capitalWithdrawalTax()`.
6. Confiance :
   - Test widget nommé qui assert la présence de la surface 4 axes
     `EnhancedConfidence`/`MintTrameConfiance` sur l'écran touché.
   - Commande scorecard : `flutter test <fichier>` exit 0.
7. Runtime :
   - Maestro requis si écran/route touché.
   - Patrol est le gate cible pour les vrais inputs P0. Avant de l'exiger :
     `command -v patrol` et `rg -n "patrol:" apps/mobile/pubspec.yaml`.
     Si absent, le scorecard note le gap et utilise Maestro ; ne jamais écrire
     "Patrol passé" sans log Patrol réel.

## 2. G3 — Data-block delta UX

Livrer `AskMode.reconfirm` pour un fait périmé (`freshness < 0.60`) sans mur de
formulaire.

Preuves minimales :
- test widget par mode (`collect`, `reconfirm`, `update`) ;
- assertion que `dataTimestamps` conserve l'ordre avant/après reconfirm ;
- `python3 tools/checks/no_bypass_persistence.py` vert après livraison du gate ;
  si le script est absent, scorecard `FAIL` et PR infra séparé avant G3 ;
- flow Maestro reconfirm avec JUnit/vidéo archivés.

## 3. G4 — buy_property

Objectif : capacité hypothécaire branchée ledger, pas démonstration statique.

Preuves minimales :
- `housing_cost_calculator` golden Julien+Lauren après registre frais ou waiver ;
- assertion que la source sheet affiche la valeur provenant de
  `dataSources['q_gross_salary_annual']` ;
- i18n complète du hub Logement : ne pas corriger seulement
  `Capacite hypothecaire`; traiter aussi les labels voisins sans accents ou
  lister les labels différés avec ticket ;
- flow Maestro F2 étendu jusqu'au résultat avec assertions de valeurs.

## 4. G5 — transmit_property

Réutiliser les services backend existants :
- `services/backend/app/services/succession_simulator.py`
- `services/backend/app/services/donation_service.py`

Preuves minimales :
- goldens Julien+Lauren succession/donation ;
- scénarios Bas/Moyen/Haut + disclaimer ;
- aucun défaut `swiss_native` implicite ;
- LIFD art. 38 : utiliser
  `RetirementTaxCalculator.capitalWithdrawalTax()` ou exposer le risque comme
  question spécialiste. Source finding H-4 :
  `.planning/runtime-evidence/mint-lucidity-claude-architecture-audit-20260703T170229/claude-architecture-audit.txt`.

H-6 dans ce même log signifie `maestro_flow_id: pending`. Le fix G4 doit donc
câbler un vrai `maestro_flow_id` pour `buy_property`, pas fermer un autre H-6.

## 5. produit-G6 — dossier PDF

Surface sortante = revue compliance avant merge.

Preuves minimales :
- texte extrait du PDF archivé sous `.planning/runtime-evidence/` ;
- script nommé, par exemple `tools/checks/pdf_text_banned_terms.py`, exit 0 ;
- disclaimer sur chaque projection ;
- confidence par section ;
- revue `mint-swiss-brain` puis audit `mint-external-auditor`.

## 6. Protocole d'échec

- Train cassé mid-stack : stop, fix sur la branche du train, puis reprise.
- Maestro flaky : reboot simulateur, 2 retries, JUnit/vidéo archivés ; échec
  persistant = bloqueur.
- Bug hors périmètre : issue + note scorecard ; pas de fix inline dans le G actif.

## 7. Interdictions anti-théâtre

- Un PR produit ne modifie pas les scripts de gate pour les faire passer. Si un
  gate manque, livrer un PR infra séparé.
- Les goldens Julien+Lauren viennent de calculs externes documentés, jamais du
  code sous test.
- Aucun changement `Runner.entitlements`, `Info.plist` ou signing dans G6 PDF ;
  ces fichiers exigent un PR isolé dédié.
