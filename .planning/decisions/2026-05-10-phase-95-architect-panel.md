---
date: 2026-05-10
status: Proposed
authors: Senior backend/data engineer (1-shot panel) + PM Claude (synthesis)
panel: 1-pers architect brief (pre-GSD-discuss scope decision)
supersedes: —
superseded_by: —
description: Phase 95 MVP-DAG-INVALIDATION architecture: inputs_hash via RFC 8785 JCS + UUID7 superseded_by + GroundingPack Pydantic v2 model + 2-wave plan split.
related:
  - .planning/decisions/2026-05-09-calc-first-llm-illumination.md
  - services/backend/app/services/coach/citation_registry.py
  - services/backend/app/services/coach/citation_parser.py
  - services/backend/app/services/coach/grounding_pack.py
  - .planning/ROADMAP.md
---

# Phase 95 MVP-DAG-INVALIDATION — Architecture pré-GSD scope decision

## TLDR

Phase 95 adopte : `inputs_hash` via JCS/SHA256 avec quantisation Decimal(2), `superseded_by` UUID7 persisté en SQLite TEXT, `GroundingPack` Pydantic v2 (`ProjectionGroundingPack`) émis par les wrappers `financial_core/`, Pareto réduit à 3-point scalarisation OMIS-II de l'arbitrage 3a/rachat-LPP/amortissement, Sobol repoussé au backlog 999.x, et intervalles de confiance via bootstrap fréquentiste 200-itérations sur Monte Carlo existant — en 2 waves.

## Context

Phase 94 MVP-CITATION-GATE a posé la fondation `{{cite:<key>}}` + `GatedResponse.inputs_hash = None` (stub Phase 95). Le `citation_registry.py` ligne 8 annonce explicitement le remplacement par `GroundingPack`. La décision architecturale `2026-05-09-calc-first-llm-illumination.md` N2 mandate : « l'arbitrage_engine + monte_carlo_service émettent un `GroundingPack` JSON au narrateur : snapshot user + Pareto front N points + Sobol indices S1/ST + what-ifs précalculés + legal_constraints + credible intervals ».

Le ROADMAP.md Phase 95 Success Criteria impose :
1. `inputs_hash: String` + `superseded_by: ProjectionId?` sur chaque projection.
2. Staleness detection — hash mismatch → `staleness: high`.
3. Migration additive (`inputs_hash` nullable).
4. Tests couvrant fresh/mismatch/recompute.

Contrainte de calendrier : budget 4d, profil L2 (backend + Flutter financial_core). Le Pareto NSGA-II Expert 4 et Sobol SALib complets sont en backlog 999.x — Phase 95 doit cibler le sous-ensemble livrable en 4d.

## Decision

### Q1 — Hash function pour `inputs_hash`

**JCS (RFC 8785) + SHA256 + Decimal quantisation.**

Approche : sérialiser les inputs de projection en JSON canonique via `jcs` (PyPI, RFC 8785 compliant), puis `hashlib.sha256(jcs.canonicalize(inputs_dict)).hexdigest()`.

Pourquoi pas `json.dumps(sort_keys=True)` seul ? Le comportement de `sort_keys` pour les clés imbriquées n'est pas garanti récursif dans toutes les implémentations Python (CPython l'est, mais c'est un détail d'implémentation). RFC 8785 impose un order lexicographique déterministe récursif + normalisation IEEE 754 → c'est la fondation utilisée par les systèmes de signature JSON (HMAC-SHA256 sur objets JSON financiers, [connect2id.com](https://connect2id.com/blog/how-to-secure-json-objects-with-hmac)).

**Problème des floats :** les inputs financiers (salaire, taux) DOIVENT être quantisés avant sérialisation. Convention : `round(value, 2)` via `Decimal(str(value)).quantize(Decimal('0.01'))` → stocké comme `float` à 2 décimales. Un float IEEE 754 `0.1 + 0.2 = 0.30000000000000004` produit un hash différent de `0.30` — la quantisation élimine ce cas. JCS normalise ensuite la représentation IEEE 754 selon ECMAScript `NumberToString` (déterministe cross-platform).

```python
import hashlib, jcs
from decimal import Decimal, ROUND_HALF_UP

def _quantize(v: float) -> float:
    return float(Decimal(str(v)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))

def compute_inputs_hash(inputs: dict) -> str:
    canonical = {k: (_quantize(v) if isinstance(v, float) else v)
                 for k, v in inputs.items()}
    return hashlib.sha256(jcs.canonicalize(canonical)).hexdigest()
```

### Q2 — `superseded_by` : UUID7, durabilité SQLite

**UUID7 (RFC 9562, Python ≥ 3.12 `uuid.uuid7()`) stocké en SQLite comme TEXT(36).**

Pourquoi UUID7 vs UUID4 ou ULID : UUID7 est time-ordered (milliseconde précision), ce qui permet `ORDER BY superseded_by` pour reconstruire la chaîne de supersession sans colonne `created_at` séparée. UUID7 est maintenant standardisé (RFC 9562, mai 2024) et disponible nativement en Python 3.12+. [uuid7.com](https://uuid7.com/) confirme les propriétés monotoniques intra-milliseconde via compteur synchronisé.

Durabilité : persister dans la table `projections` SQLite existante (colonne `superseded_by TEXT NULLABLE`). Migration additive — `inputs_hash TEXT NULLABLE, superseded_by TEXT NULLABLE`. Pas de table séparée. En mémoire (non persisté) dans les wrappers Dart `financial_core/` — le Flutter side traite `inputs_hash` comme champ de modèle sérialisé dans le JSON de réponse, sans ORM côté mobile.

### Q3 — GroundingPack JSON schema (Pydantic v2)

Nom du modèle : **`ProjectionGroundingPack`** (découplé de `CitationSource` existant, remplace `CITATION_REGISTRY` à terme).

```python
from pydantic import BaseModel, ConfigDict
from typing import Optional
from decimal import Decimal

class GroundingPackEntry(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    key: str                    # stable snake_case identifier (cite key)
    value: str                  # formatted human-readable value
    raw_value: Optional[float]  # numeric for Phase 96 narrator substitution
    source_ref: str             # spec:OPP3#art_7... / calc:avs.computeMonthlyRente
    asof: str                   # ISO date of computation
    credible_low: Optional[float]   # bootstrap P5
    credible_high: Optional[float]  # bootstrap P95
    staleness: str              # "fresh" | "high"

class ParetoPoint(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    label: str                  # "3a_prioritaire" | "rachat_lpp" | "amortissement"
    tax_saving_chf: float
    liquidity_score: float      # 0-1 normalised
    ruin_prob_reduction: float  # delta vs baseline

class ProjectionGroundingPack(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    inputs_hash: str
    computed_at: str            # ISO datetime
    entries: dict[str, GroundingPackEntry]
    pareto_points: list[ParetoPoint]
    what_ifs: dict[str, GroundingPackEntry]  # key → entry with mutated input
    legal_constraints: list[str]             # plain FR strings from ADR/spec refs
```

Ce modèle est consommé par `citation_parser._substitute_placeholders()` : Phase 95 remplace l'appel à `resolve(key, ctx)` par `pack.entries[key]` quand le `ProjectionGroundingPack` est disponible dans le contexte.

### Q4 — Pareto, Sobol, intervalles de confiance : forme MVP

**Pareto :** pas de NSGA-II en Phase 95 (4d budget). Le Pareto NSGA-II (Expert 4, backlog 999.2) est une optimisation multi-objectif complète — inadaptée au calendrier. Ce qui est adapté en Phase 95 : **3-point scalarisation** sur les 3 leviers principaux MINT (3a vs rachat LPP vs amortissement indirect), calculée par les wrappers `financial_core/` existants avec 3 pondérations prédéfinies (`tax_weight=1.0`, `liquidity_weight=0.5`, `ruin_weight=0.3`). Résultat : 3 `ParetoPoint` precomputed — suffisant pour que le narrateur dise « dans votre situation, le levier 3a domine sur l'axe fiscal ». Ce n'est pas un vrai front Pareto, mais c'est ce qui « gagne le label calc-first » sans ouvrir `pymoo`.

**Sobol :** overkill pour MVP — repousser en backlog 999.x. SALib Sobol nécessite N × (D+2) évaluations de modèle (Saltelli sampling), soit 200+ évaluations pour 5 paramètres. Sur un modèle aussi rapide que les calculateurs Dart/Python existants c'est faisable, mais l'interprétation des indices S1/ST dans une UI MINT n'est pas encore designée. En Phase 95, on substitue par une **analyse de sensibilité uni-variée** : ±10% sur chaque input → delta output. 5 `what_ifs` entries dans `ProjectionGroundingPack.what_ifs`. Le narrateur peut dire « si votre salaire augmente de 10%, votre rente AVS pourrait progresser de X ». Sobol entre quand Phase 96 a designé une surface de visualisation.

**Intervalles de confiance :** bootstrap fréquentiste, 200 itérations sur le Monte Carlo existant (`monte_carlo_service`), P5/P95. Pas Bayésien (pas de prior calibré sur données MINT). Bootstrap est adapté parce qu'il réutilise le MC existant sans dépendances nouvelles ([SALib docs](https://salib.readthedocs.io/en/latest/user_guide/basics.html) confirme que le bootstrap est le point d'entrée standard avant d'aller vers Sobol). Résultat dans `GroundingPackEntry.credible_low` / `credible_high`.

### Q5 — Wave split : 2 waves

**Wave 1 (2d) — DAG-INVALIDATION core :**
- `inputs_hash` + `superseded_by` sur les 4 modèles de projection (LPP, AVS, 3a, marge fiscale) côté backend + Flutter.
- Migration SQL additive.
- `compute_inputs_hash()` util + `staleness` flag.
- Tests `test_projection_dag_invalidation.py` (4 scénarios ROADMAP §Success Criteria).

**Wave 2 (2d) — GroundingPack emission :**
- `ProjectionGroundingPack` Pydantic v2 model.
- Wrappers `financial_core/` émettant le pack (3-point Pareto + 5 what-ifs + bootstrap P5/P95).
- Mise à jour `citation_parser._substitute_placeholders()` pour consommer le pack quand disponible.
- Migration `citation_registry.py` → `grounding_pack.py` : `GROUNDING_PACK_KEYS_REGISTRY` peuplé avec les 18 clés existantes du registre Phase 94 mappées vers `GroundingPackEntry`.

### Q6 — Top 3 risques

| # | Risque | Mitigation |
|---|---|---|
| R1 | **Float hash non-déterministe cross-runtime** : un calcul intermédiaire (ex. conversion taux AVS) produit 0.30000000000000004 en Python mais 0.3 en Dart → hash mismatch fantôme → staleness false-positive permanent. | Quantiser AVANT hash (`Decimal(2)` mandatory), ajouter test de parité hash Python↔Dart avec 50 fixtures gelées dans `tests/fixtures/hash_parity.jsonl`. Si parité impossible à fermer : passer `inputs_hash` en entier (CHF en centimes, taux en bps). |
| R2 | **Scope creep Sobol/NSGA-II en Wave 2** : le ticket Wave 2 est tentant d'élargir vers SALib Sobol + pymoo. 200+ MC évaluations × 5 leviers = 20min CI. | Hard boundary dans `PLAN.md` : « Wave 2 n'ouvre pas SALib, pas pymoo. Sobol = 999.x. Pareto = 3-point scalarisation uniquement. CI gate : temps ≤2min. » |
| R3 | **Migration citation_registry → grounding_pack casse les 18 clés Phase 94** : `citation_parser` importe `CITATION_REGISTRY` directement. Si Wave 2 remplace le module avant que le pack soit hydraté, le gate renvoie `None` sur toutes les clés → FALLBACK systématique. | Stratégie de cohabitation : `_substitute_placeholders()` cherche d'abord `pack.entries[key]`, puis fall-back sur `CITATION_REGISTRY.get(key)`. `CITATION_REGISTRY` reste READ-ONLY jusqu'à Phase 96. Aucune suppression de clés en Phase 95. |

### Q7 — Migration citation_registry.py → GroundingPack

Stratégie en 3 étapes, toutes dans Wave 2 :

1. **Peupler `GROUNDING_PACK_KEYS_REGISTRY`** (actuellement `frozenset()` dans `grounding_pack.py`) avec les 18 clés Phase 94. Chaque clé mappe vers un `GroundingPackEntry` statique (même `description_fr` que `CitationSource`, plus `raw_value=None`, `credible_low=None`, `credible_high=None`, `staleness="fresh"`).

2. **Double-lookup dans `_substitute_placeholders()`** : `pack.entries[key]` si pack non-None, sinon `resolve(key, ctx)` (comportement Phase 94 inchangé). Aucun caller ne casse.

3. **Test de non-régression** : `test_citation_gate/test_registry_contract.py::test_no_recursive_keys` + `test_registry_subset_of_bundle_allowlists` continuent de passer sur l'ancien registry. Nouveau test `test_grounding_pack_covers_registry_keys` vérifie que `GROUNDING_PACK_KEYS_REGISTRY ⊇ CITATION_REGISTRY.keys()`.

Suppression de `CITATION_REGISTRY` : Phase 96 uniquement, après que le narrateur consomme `ProjectionGroundingPack` systématiquement.

## Counter-arguments and data gaps

### What does the strongest opposing view say?

L'opposition la plus solide : **« Phase 95 est prématurée — investir 4d dans DAG-INVALIDATION alors que la staleness de projections n'est pas un bug utilisateur confirmé. »** Steel-man : aucune donnée Sentry ou session utilisateur ne documente un user frustré de voir une « vieille » LPP card. Le bug est théorique (profile salary update → 3-day stale projection). Les 4d seraient mieux investis en Phase 96 (chat-as-verb) qui a un impact UX immédiat. De plus, le `inputs_hash` nullable + lazy-compute de Phase 95 crée une fenêtre de 2-3 semaines où les projections PEUVENT être stales sans détection (les profils existants ne recomputed pas automatiquement).

Réponse : Phase 96 dépend explicitement de Phase 95 (`ROADMAP.md §Depends on`) pour « garantir des projections fraîches avant que le chat les surface ». Casser la dépendance = risque de Phase 96 narrateur qui cite des chiffres périmés via les `what_ifs`. La staleness devient visible dès que Phase 96 ouvre la surface chat-as-verb.

### What does this source not address?

- **Pas de mesure de la fréquence réelle de staleness** : on ne sait pas combien de profils MINT (staging) ont des projections avec `inputs_hash` mismatch si on les calculait maintenant. Ça pourrait être 0% (les profils de test sont static) ou 100% (chaque update staging recalcule). À mesurer dans Wave 1 en ajoutant un log Sentry `projection_staleness_rate`.
- **Bootstrap 200-itérations sans calibration** : le P5/P95 bootstrap est calibré sur le Monte Carlo existant (`monte_carlo_service`) dont les hypothèses de rendement (i.i.d. Gaussien) sont notées comme insuffisantes par Expert 1 (HMM, backlog 999.1). Les intervalles de confiance Phase 95 sont donc une borne indicative, pas une borne actuarielle. Le narrateur DOIT l'annoter (`selon le modèle simplifié actuel`).
- **`jcs` PyPI maintenu ?** Le package `jcs` (RFC 8785) a 27k téléchargements/mois (PyPI, 2026-05-10). Pas de version 1.x stable. Alternative si le package est abandonné : `json.dumps(sorted_dict, separators=(',', ':'), ensure_ascii=False)` avec tri récursif custom — moins propre mais sans dépendance externe.

### What would change this conclusion?

- Si `jcs` sort une v1.0 stable avant Phase 95 Wave 1 → adopter immédiatement (supprimer la mention « alternative si abandonné »).
- Si un user-test pilote (staging, ≥5 users) révèle que les projections stales sont invisibles pour eux (ils ne revisitent pas les cards après profile update) → rétrograder Phase 95 en Phase 96.5 post-chat-as-verb.
- Si Python runtime passe à ≥ 3.14 (uuid.uuid7 RFC 9562 aligné) sur Railway avant Phase 95 Wave 1 → supprimer `uuid7` PyPI dep, utiliser stdlib.

## Sources

- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — ADR calc-first N2 mandate GroundingPack
- `.planning/ROADMAP.md §Phase 95` — Success Criteria + Budget 4d + Depends on Phase 94
- `services/backend/app/services/coach/citation_registry.py` — ligne 8 : annonce remplacement par GroundingPack
- `services/backend/app/services/coach/citation_parser.py` — `_substitute_placeholders()` + `GatedResponse.inputs_hash` stub
- `services/backend/app/services/coach/grounding_pack.py` — `GROUNDING_PACK_KEYS_REGISTRY = frozenset()` Phase 93.5 stub
- [RFC 8785 — JSON Canonicalization Scheme (JCS)](https://www.rfc-editor.org/rfc/rfc8785) — standard de sérialisation canonique JSON, base du hash déterministe
- [connect2id.com — How to secure JSON objects with HMAC (JCS)](https://connect2id.com/blog/how-to-secure-json-objects-with-hmac) — référence pratique JCS + HMAC-SHA256 (fetched 2026-05-10)
- [uuid7.com — UUIDv7 Benefits](https://uuid7.com/) — monotonic time-ordering + RFC 9562 (fetched 2026-05-10)
- [SALib docs — Sensitivity Analysis basics](https://salib.readthedocs.io/en/latest/user_guide/basics.html) — Sobol S1/ST + bootstrap point d'entrée (fetched 2026-05-10)
- [death.andgravity.com — Deterministic hashing of Python data objects](https://death.andgravity.com/stable-hashing) — float quantisation pitfalls (fetched 2026-05-10)
- [Springer — Multiobjective portfolio optimization via Pareto front evolution](https://link.springer.com/article/10.1007/s40747-022-00715-8) — référence Pareto multi-objectif finance (fetched 2026-05-10)
- [jcs · PyPI](https://pypi.org/project/jcs/) — implémentation Python RFC 8785

## Status & follow-up

- **Status :** Proposed — à valider par Julien lors de `/gsd-discuss-phase 95 --auto`.
- **Implementation tracking :** Phase 95 TBD — 2 waves per §Q5.
- **Re-litigation triggers :**
  - `jcs` PyPI abandonné → switch to custom recursive sort + `json.dumps`
  - User-test pilote révèle staleness invisible pour les users → rétrograder Phase 95
  - Python ≥ 3.14 sur Railway → stdlib `uuid.uuid7()`, supprimer dep externe
  - Sentry `projection_staleness_rate` = 0% sur 4 semaines post-Wave-1 → supprimer `staleness: high` badge côté Flutter (dead feature)

---
*Brief 1-shot senior backend/data engineer — 2026-05-10 — pré-GSD-discuss Phase 95.*
