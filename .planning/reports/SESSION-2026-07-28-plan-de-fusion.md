---
description: Plan de fusion de la campagne étalon fiscal — 37 PR ouvertes (#1063-#1099), 5 vagues ordonnées, carte des chevauchements mesurée par diff, état CI re-sondé le 2026-07-28. Fusion réservée à Julien.
---

# Plan de fusion — campagne étalon fiscal (2026-07-28)

Source de vérité git-diffable du rapport HTML `SESSION-2026-07-28-plan-de-fusion.html`.
Données : `gh pr view` (mergeable, mergeStateStatus, statusCheckRollup) + `git diff --name-only origin/dev...origin/<branche>` pour les 37 branches, intersections calculées par script. Base : origin/dev = `204b31e8b`.

## 1. État CI (re-sondé 2026-07-28, soirée)

- **34 vertes** — toutes MERGEABLE / CLEAN au moment du sondage.
- **3 rouges** (cause mécanique lue dans les logs de job) :
  - **#1084** `lint-prescriptions` — job « Backend tests » : pytest **7979 passed**, mais l'étape diff-coverage sort en exit 1 : `prescription_vocab.py` 0 % (lignes 25, 29, 98 non couvertes). CI Gate rouge par cascade. Correctif : un petit test unitaire du module.
  - **#1094** `suppression-cles-mortes` — job « Flutter services » : 1 test rouge, `test/services/coach/de_it_terminology_test.dart` (« IT ARB contains pensionamento or previdenza for retirement ») : le test asserte sur des clés retraite-first que la PR supprime. Correctif : ajuster le test dans la branche.
  - **#1097** `recalibrage-capital-marie` — « Backend tests » : `tests/test_coach_tools_parity.py::test_retirement_projection_parity[edge_age_65__get_retirement_projection]` ; « Flutter services » : `retirement_service_test.dart` (« compareLpp — capital vs rente impot capital VD — capital 300k (modèle v2) »). Deux tests de parité figés sur l'ancien rabais forfaitaire ; à refixer avec les montants calibrés.
- **0 pending** — #1099 est passée au vert pendant la collecte (MERGEABLE / CLEAN, toutes checks pass).

## 2. Tableau des PR (37)

| PR | Branche (codex/journey-os-…) | CI | Vague |
|---|---|---|---|
| #1065 | constat-rachat-echelonne | verte | 1 |
| #1066 | constat-precision-service | verte | 1 |
| #1067 | constat-family-service | verte | 1 |
| #1070 | inventaire-prescriptions | verte | 1 |
| #1074 | constats-triade-3-5 | verte | 1 |
| #1077 | constat-frontalier | verte | 1 |
| #1078 | constat-succession-tax | verte | 1 |
| #1079 | constats-donation-housing | verte | 1 |
| #1086 | socle-succession-donnees | verte | 1 |
| #1089 | gains-immo-donnees | verte | 1 |
| #1095 | triage-tables-annassign | verte | 1 |
| #1080 | adr-decisions-deleguees | verte | 1 (dernière de la vague) |
| #1088 | garde-annassign | verte | 2 (première de la vague) |
| #1068 | accent-lint-added-only | verte | 2 |
| #1069 | collect-estv-dry-run | verte | 2 |
| #1071 | no-hardcoded-fr-staged-blob | verte | 2 |
| #1063 | drain-taux-marginaux | verte | 2 |
| #1064 | drain-minimal-profile | verte | 2 |
| #1072 | drain-precision-service | verte | 2 |
| #1073 | rachat-echelonne-code-mort | verte | 2 |
| #1075 | fix-citation-cc-reserves | verte | 2 |
| #1076 | drain-divorce-simulator | verte | 2 |
| #1082 | suppression-base-rate-mort | verte | 2 (avant #1085) |
| #1085 | lamal-pays-residence | verte | 2 (après #1082) |
| #1081 | fix-remploi-methode-absolue | verte | 2 |
| #1083 | purge-attribution-fortune | verte | 2 |
| #1096 | drain-rag-tax-specifics | verte | 2 |
| #1091 | reecriture-arb | verte | 3 (ordre 1) |
| #1092 | reecriture-backend | verte | 3 (ordre 2) |
| #1093 | reecriture-dart | verte | 3 (ordre 3) |
| #1094 | suppression-cles-mortes | **rouge** (Flutter services) | 3 (ordre 4, après correctif) |
| #1084 | lint-prescriptions | **rouge** (Backend tests / diff-coverage) | 3 (ordre 5, après correctif + élagage baseline) |
| #1087 | socle-succession-code-impl | verte | 4 (ordre 1) |
| #1090 | gains-immo-calibres | verte | 4 (ordre 2) |
| #1098 | oracle-estv-reveil | verte | 5 (ordre 1) |
| #1099 | etalon-noeuds-bas | verte | 5 (ordre 2) |
| #1097 | recalibrage-capital-marie | **rouge** (parité ×2) | 5 (ordre 3, après correctif) |

## 3. Carte des chevauchements

251 paires de branches partagent au moins un fichier, mais l'écrasante majorité ne partagent que les deux fichiers de garde :

- `tools/checks/journey_os_check.py` (liste ALLOW) — touché par **22 branches** : 1063, 1068, 1069, 1072, 1075, 1076, 1080, 1081, 1082, 1083, 1084, 1085, 1087, 1090, 1091, 1092, 1093, 1094, 1096, 1097, 1098, 1099. Conflit trivial d'union (1 ligne par entrée) à chaque rebase.
- `tools/checks/no_cantonal_rate_table.py` (allowlist) — touché par **8 branches** : 1063, 1064, 1073, 1076, 1085, 1087, 1088, 1097. Écart vs la liste déclarée : #1072 et #1090 ne touchent PAS ce fichier ; #1063, #1076 et #1085 le touchent en plus.

### Chevauchements non triviaux (hors fichiers de garde)

| Paire | Fichiers | Statut | Résolution (1 ligne) |
|---|---|---|---|
| #1086 ↔ #1087 | `socle_extraction.json` | déclaré | copie identique — fusion dans n'importe quel ordre, no-op |
| #1089 ↔ #1090 | 5 fichiers archive gains immo | déclaré (corps #1090) | copie identique — no-op |
| #1081 ↔ #1090 | 4 fichiers housing_sale (py+dart+tests) | déclaré | #1081 d'abord ; py identique = no-op, dart → prendre la version verdict de #1090 |
| #1091 ↔ #1094 | 12 ARB + dart générés | déclaré | zones disjointes par clé ; `flutter gen-l10n` après rebase |
| #1097 ↔ #1098 | `test_estv_oracle.py` + `estv_oracle.SCHEMA.md` | déclaré | #1098 d'abord ; #1097 rebase sur l'oracle réveillé |
| #1063 ↔ #1092 | `coaching_engine.py`, `first_job/onboarding_service.py` | **non déclaré** | #1063 (drain) d'abord ; hunks wording de #1092 a priori disjoints |
| #1072 ↔ #1092 | `precision_service.py` | **non déclaré** | #1072 (drain) d'abord ; même patron |
| #1064 ↔ #1097 | `test_rules_engine.py` | **non déclaré** | #1064 d'abord (verte) ; #1097 rebase |
| #1076 ↔ #1087 | `test_life_events.py` | **non déclaré** | #1076 a normalisé CRLF→LF ; #1076 d'abord, rebase #1087 sur la version LF (conflit apparent massif, diff réel minime) |
| #1082 ↔ #1085 | `frontalier_service.py` | **non déclaré** | #1082 (champ mort) d'abord ; zones distinctes |
| #1083 ↔ #1087, #1083 ↔ #1090 | `tools/openapi/*.json` | **non déclaré** | regen OpenAPI canonique après rebase, mécanique |
| #1068 ↔ #1084 | `lefthook.yml` | **non déclaré** | union de deux hooks, trivial |
| #1087 ↔ #1090/#1091/#1094 | 12-13 fichiers ARB + gen + (pour #1090) `life_events.py`/schemas/openapi | partiellement déclaré | ordre vague 3 → vague 4 ; gen-l10n + regen OpenAPI à chaque rebase |
| #1097 ↔ #1099 | `income_tax_model_v2.dart`, `cantonal_comparator.py`, `rvc_parity_v1.json` | **non déclaré** | vrai couplage étalon — #1099 (verte) d'abord, #1097 refixe la parité sur l'état fusionné |

Couplage sémantique (sans chevauchement de fichier) : la baseline cliquet de #1084 (`_baseline_prescription_sites.txt`) référence les sites réécrits par #1091/#1092/#1093 et supprimés par #1094 — élagage obligatoire dans #1084 après leurs fusions (comportement voulu du cliquet). De même, l'allowlist gelée par #1088 contient des tables tuées par #1072/#1087/#1090 → retrait des entrées lors de leurs rebases (rétrécissement forcé). Le correctif de parité de #1097 touchera vraisemblablement `coach_tools_parity_v1.jsonl`, que #1099 modifie aussi → refixer après la fusion de #1099.

## 4. Ordre de fusion recommandé (5 vagues)

### Vague 1 — docs, constats, ADR, données (12 PR, toutes vertes, ordre libre)
#1065, #1066, #1067, #1070, #1074, #1077, #1078, #1079, #1086, #1089, #1095, puis **#1080 en dernier** (seule de la vague à toucher `journey_os_check.py` — sa fusion déclenche la première salve de rebases ALLOW).
Justification : zéro chevauchement entre elles, zéro code exécutable (sauf la ligne ALLOW de #1080).
**Rebases après vague 1** : les 21 branches code touchant `journey_os_check.py` (conflit d'union 1 ligne chacune).

### Vague 2 — lint/infra + drains backend indépendants (15 PR, toutes vertes)
Ordre interne : **#1088 d'abord** (fige l'allowlist AnnAssign) → #1068, #1069, #1071 → #1063, #1064, #1072, #1073, #1075, #1076 → **#1082 puis #1085** (même `frontalier_service.py`, zones distinctes) → #1081, #1083, #1096.
Justification : chaque PR est autonome ; les seuls conflits entre elles sont les unions ALLOW/allowlist et la paire #1082→#1085.
**Rebases après vague 2** : #1084, #1087, #1090, #1091, #1092, #1093, #1094, #1097, #1098, #1099. Notes : #1092 rejoue ses hunks wording sur les fichiers drainés (#1063/#1072) ; #1087 reprend `test_life_events.py` en LF (#1076) + retire l'entrée donation de l'allowlist (#1088) + regen OpenAPI (#1083) ; #1090 regen OpenAPI + retrait éventuel d'entrées allowlist.

### Vague 3 — campagne prescriptions (5 PR, ordre imposé)
**#1091 → #1092 → #1093 → #1094 → #1084.**
- #1094 est **rouge** : corriger `de_it_terminology_test.dart` dans la branche avant fusion (le test asserte sur les clés supprimées).
- #1084 est **rouge** : couvrir `prescription_vocab.py` (lignes 25/29/98) pour le gate diff-coverage, puis élaguer la baseline des 56 sites réécrits + 8 supprimés, union `lefthook.yml` avec #1068.
Justification : les lots 1-3 sont verts et vérifiés au lint de la branche #1084 ; fusionner le lint en dernier évite quatre retraits successifs de baseline (un seul élagage final).
**Rebases après vague 3** : #1087, #1090 (ARB + `flutter gen-l10n`), #1097, #1098, #1099 (ALLOW).

### Vague 4 — grosses unités fiscales (2 PR, vertes)
**#1087 (socle succession) → #1090 (gains immo).**
Résolutions au rebase : archives #1086/#1089 déjà sur dev (no-op), ARB → gen-l10n, OpenAPI → regen, `test_life_events.py` LF, allowlist AnnAssign à rétrécir, housing_sale → py identique no-op + dart version verdict (#1081 déjà fusionnée).
**Rebases après vague 4** : #1097, #1098, #1099 (ALLOW).

### Vague 5 — étalon et oracle (3 PR, ordre imposé)
**#1098 → #1099 → #1097.**
- #1098 verte : réveille l'oracle (fixture 260 vecteurs).
- #1099 verte : nœuds bas 15k/25k/35k ; pas de couplage déclaré avec #1098.
- #1097 **rouge** : refixer les 2 tests de parité avec les montants calibrés, puis rebase sur #1098 (`test_estv_oracle.py` + SCHEMA) et #1099 (`income_tax_model_v2.dart`, `cantonal_comparator.py`, `rvc_parity_v1.json`, et parité coach_tools sur l'état fusionné).
**Après la vague** : refresh de la fixture oracle (script versionné #1069/#1098) pour intégrer la zone sous-40k et le capital marié calibré, avec tolérances documentées.

## 5. Ce qui reste après les fusions

1. **Élagage baseline #1084** — effectué lors de sa fusion en fin de vague 3 ; le cliquet interdit toute ré-expansion ensuite.
2. **Refresh oracle ESTV** post-#1097/#1098/#1099 — recapture de la fixture, vecteurs sous-40k admis, tolérances honnêtes.
3. **Rebases résiduels** — aucune branche de la campagne ne doit rester en CONFLICTING ; l'état MERGEABLE affiché aujourd'hui vaut contre le dev du sondage, il se dégrade à chaque fusion (attendu, unions triviales).
4. **Suivis déclarés hors périmètre de la campagne** : SaleSurprisesWidget à câbler sur le verdict ou supprimer (#1090) ; `ResidenceCountry` sans LI + paramètre `canton` devenu superflu sur l'endpoint frontalier (#1085) ; divergence préexistante `plus_value_brute` py↔dart (#1090) ; 7 tables AnnAssign restantes à trier (#1095).

*Sondage CI et diffs : 2026-07-28. Les états CI sont périmables — re-sonder `gh pr checks` avant chaque fusion.*
