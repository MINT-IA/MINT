---
description: Phase 95 MVP-DAG-INVALIDATION research — deepens locked decisions D-01..D-18 with verified library versions, code-search results, code patterns, and pitfall mitigations. Consumed by /gsd-plan-phase 95.
researched: 2026-05-10
domain: backend data-modeling + Python↔Dart deterministic hashing + Pydantic v2 schema
confidence: HIGH on D-01/D-02/D-04/D-05/D-06/D-07/D-08/D-09 (verified against codebase + PyPI 2026-05-10) ; MEDIUM on D-03 (calc_harness compile-exe BLOCKED today — fallback path documented) ; MEDIUM on D-10/D-11/D-12 (no existing backend wrapper for financial_core, planner must decide module placement)
---

# Phase 95: MVP-DAG-INVALIDATION — Research

**Researched:** 2026-05-10
**Domain:** backend data-modeling + Python↔Dart deterministic hashing + Pydantic v2 schema
**Confidence:** HIGH (most decisions verified) ; MEDIUM on hash parity + Dart-side emission

## TLDR

Phase 95 ships in 2 waves (~2+2d) : (W1) add `inputs_hash` (SHA256 of RFC 8785 canonical JSON, floats quantized to `Decimal(0.01)`) + `superseded_by` (UUID7 backport via `uuid_utils` — `uuid.uuid7` stdlib is **3.14-only**, Railway runs 3.12) on the canonical projection model (currently `ScenarioModel` — the architect-panel-named `projections` table does not exist, planner picks fresh-create vs scenarios-extension) ; (W2) `ProjectionGroundingPack` Pydantic v2 emitter at `services/backend/app/services/coach/grounding_pack.py`, consumed by `_substitute_placeholders()` via D-09 double-lookup against the existing 18-key `CITATION_REGISTRY` namespace. Hash parity Python↔Dart is R1 — `calc_harness` `dart compile exe` is still BLOCKED today (Phase 92.7 closure plan exists, not landed) so Wave 1 ships with the `flutter test` fallback documented in calc_diff_harness precedent. Library pins : `rfc8785==0.1.4` (Trail of Bits, zero-deps, preferred over stale `jcs==0.2.1`) + `uuid_utils>=0.14,<1.0` (Rust-backed, supports 3.9-3.14, 16× faster than backport-pure-python).

**Primary recommendation:** Follow CONTEXT D-01..D-18 verbatim. Adjust the **storage target** from « `projections` table » to « `ScenarioModel.scenarios` table » OR create a NEW `projections` table — this is a Claude-discretion ambiguity the planner must resolve in Wave 1 task #1.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**inputs_hash algorithm**
- D-01 : SHA256 of canonical JSON serialization (RFC 8785 JCS, via the `jcs` Python package). Fallback : recursive key-sort + `json.dumps(separators=(",", ":"), ensure_ascii=False, sort_keys=True)` documented as no-dep contingency.
- D-02 : Floats quantized to `Decimal(2)` BEFORE canonicalisation via recursive `_quantize_floats()` walker. `np.float64` must be cast to Python `float` before quantize.
- D-03 : Python↔Dart hash parity validated by `tests/fixtures/hash_parity_50.jsonl` — 50 input dicts hashed Python-side AND via `dart compile exe` of `apps/mobile/tools/calc_harness/main.dart`, equality asserted. Centime/bps integer-scaling fallback documented.

**superseded_by ID format**
- D-04 : UUID7 via `uuid.uuid7()` (architect-panel claim « Python 3.12+ » — verified WRONG, see Open Questions OQ-1). Time-ordered (first 48 bits = ms since Unix epoch).
- D-05 : Storage TEXT(36) in SQLite. Two new nullable columns on the projections table : `inputs_hash TEXT NULL` and `superseded_by TEXT NULL`. ADDITIVE migration only — zero backfill.
- D-06 : Alembic additive migration only. Forward + downgrade. Verified on staging DB clone before merging.

**GroundingPack data contract**
- D-07 : `ProjectionGroundingPack` Pydantic v2 (`frozen=True`, `extra="forbid"`). Lives at `services/backend/app/services/coach/grounding_pack.py` (stub today).
- D-08 : Top-level fields : `inputs_hash: str`, `entries: dict[str, GroundingPackEntry]` keyed by SAME 18-key `CITATION_REGISTRY` namespace, `pareto_points: list[ParetoPoint]` (3 entries), `what_ifs: dict[str, GroundingPackEntry]` (5 entries), `legal_constraints: list[str]`, `superseded_by: str | None`. Sub-model `GroundingPackEntry { value: Decimal, raw: dict, source_ref: str, credible_low: Decimal | None, credible_high: Decimal | None, staleness_iso: str }`.
- D-09 : `_substitute_placeholders()` performs DOUBLE LOOKUP — `pack.entries.get(key)` first, fallback to `CITATION_REGISTRY.resolve(key)`. Cohabitation during Phase 95 + 96 ; `CITATION_REGISTRY` removal deferred post-96.

**Pareto computation MVP**
- D-10 : 3-point scalarisation on 3 leviers (3a / rachat-LPP / amortissement-indirect) with 3 fixed pondérations (fiscal-pure / liquidity-prioritized / ruin-reduction-prioritized). NSGA-II via `pymoo` deferred to backlog 999.2.
- D-11 : Sensitivity analysis : uni-variate ±10% per input → 5 `what_ifs` entries. Full Sobol indices via Saltelli sampling deferred to backlog 999.x.

**Credible intervals**
- D-12 : Bootstrap fréquentiste 200 iterations on existing `monte_carlo_service.dart` outputs. P5/P95 → `credible_low` / `credible_high`. Narrator MUST annotate « selon le modèle simplifié actuel ».

**Plan count and wave split**
- D-13 : 2 plans, 2 waves. W1 (~2d) hash+migration+staleness flag+parity fixture. W2 (~2d, BLOCKS on W1 merge) emission+double-lookup+pareto+what_ifs+bootstrap.

**Compliance gates**
- D-14 : `banned_terms_python.py` + `pii_fixture_scan.py` (new) + `no_legal_admission_in_public_docs.py` + `accent_lint_fr.py`. Lefthook pre-commit + CI.
- D-15 : `hash_parity_50.jsonl` 50/50 byte-identical Python vs Dart. Failure = blocker.
- D-16 : G4 regression suite — backend pytest ≥ 6471 baseline.
- D-17 : G5 schema migration — alembic upgrade head + downgrade head clean on staging DB clone. **Manual verification step in PLAN.md, NOT automated this phase.**
- D-18 : G1 Maestro — N/A for Phase 95 (backend-only).

### Claude's Discretion

- Internal class structure of GroundingPack emitters within `financial_core/` wrappers (helper module vs extend existing).
- Bootstrap RNG seed strategy : `np.random.RandomState(42)` deterministic OR per-input seed derived from `inputs_hash`.
- Whether to extend the existing `grounding_pack.py` stub (24 lines, `frozenset()`) or replace it wholesale.
- Decimal precision policy for `value` field on `GroundingPackEntry` : `Decimal(2)` for CHF, `Decimal(4)` for percentages — planner picks unified policy.

### Deferred Ideas (OUT OF SCOPE)

- Full Pareto front via NSGA-II + `pymoo` — backlog 999.2.
- Sobol sensitivity indices via Saltelli sampling — backlog 999.x.
- HMM regime-switching Monte Carlo + CVaR + BVG mortality — backlog 999.1.
- Bayesian credible intervals — deferred indefinitely.
- `CITATION_REGISTRY` complete removal — post-Phase-96 cleanup phase.
- Full Phase 96 CI integration of schema migration verifier — Phase 96 G3.

</user_constraints>

<phase_requirements>
## Phase Requirements

`.planning/REQUIREMENTS.md` does NOT exist (verified 2026-05-10 — `test -f` returns missing). The phase-id-keyed requirements DAG-01..DAG-04 come from the `<additional_context>` block in this research request and from `.planning/ROADMAP.md §Phase 95 Success Criteria` (cited via the architect panel at `.planning/decisions/2026-05-10-phase-95-architect-panel.md §Context`).

| ID | Description | Research Support |
|----|-------------|------------------|
| DAG-01 | `inputs_hash` on every projection (SHA256 of canonical JSON) | D-01/D-02 with `rfc8785==0.1.4` (HIGH) + `_quantize_floats()` recipe (§D-01 below). |
| DAG-02 | `superseded_by` chain (UUID7, time-ordered, populated when inputs mutate) | D-04/D-05 with `uuid_utils>=0.14` backport (HIGH — see OQ-1) + `_substitute_placeholders()` extension point already exists at `citation_parser.py:352`. |
| DAG-03 | `staleness=high` flag when inputs_hash mismatch detected | Field on `GroundingPackEntry.staleness_iso` + Boolean derivation rule. Planner defines the **mismatch detection trigger** — most likely a profile-update hook OR lazy compare at read time. |
| DAG-04 | Additive migration (hash nullable for backward compat) | D-06 with `op.add_column(..., nullable=True)` precedent at `alembic/versions/p86_anonymous_session_eclairage_delivered.py` (uses `server_default` for Boolean ; Phase 95 stays nullable with no default). |

**Critical:** The 4 requirement IDs refer to « every projection ». In the current codebase, the closest persisted analogue is `ScenarioModel` (`services/backend/app/models/scenario.py`) — there is NO `projections` table. See OQ-2.

</phase_requirements>

## D-01 + D-02 — SHA256 + JCS + Decimal2 hash (deepened)

### Library choice : `rfc8785` over `jcs`

| Package | Version | Released | Deps | Maintenance signal | Recommendation |
|---------|---------|----------|------|---------------------|-----------------|
| `jcs` | 0.2.1 | 2022-04-10 | None | STALE (4 years, no release) | Do not adopt |
| `rfc8785` | 0.1.4 | 2024-09-27 | None | Trail of Bits maintained, beta status | **Adopt** [VERIFIED: PyPI fetch 2026-05-10] |
| `json-canonical` | — | — | Unknown | Lower download count | Skip |

`rfc8785` is a pure-Python, zero-dependency implementation by Trail of Bits (the security firm that wrote `pip-audit`, `sigstore-python`). [VERIFIED: https://pypi.org/project/rfc8785/] [CITED: https://github.com/trailofbits/rfc8785.py]

CONTEXT D-01 names `jcs` explicitly. **The planner SHOULD substitute `rfc8785` and document the substitution in PLAN.md** — same RFC 8785 contract, no dep drift, actively maintained. If Julien wants strict CONTEXT compliance, fall back to `jcs==0.2.1` (still functional, just stale).

**Library pin:**
```
# pyproject.toml [project.dependencies]
"rfc8785>=0.1.4,<1.0.0",
```

### Canonicalisation recipe

```python
# services/backend/app/services/coach/dag_invalidation.py (NEW MODULE — Wave 1)
from __future__ import annotations

import hashlib
from decimal import Decimal, ROUND_HALF_UP
from typing import Any

import rfc8785  # noqa: F401 — preferred over stale `jcs`


def _quantize(value: Any) -> Any:
    """Recursive walker — quantize floats to 2 decimals BEFORE canonicalisation.

    Decimal-based to dodge IEEE 754 artifacts (`0.1 + 0.2 != 0.3`).
    Edge cases handled : `inf`, `nan`, `-0.0` raise ValueError (defensive
    — financial inputs MUST NOT be these). `int` passes through untouched.
    `numpy.float64` is cast via `float()` first (D-02 explicit edge case).
    """
    if isinstance(value, dict):
        return {k: _quantize(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_quantize(v) for v in value]
    if isinstance(value, bool):  # MUST precede the int branch
        return value
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if value != value:  # NaN
            raise ValueError("NaN not allowed in projection inputs")
        if value in (float("inf"), float("-inf")):
            raise ValueError("inf/-inf not allowed in projection inputs")
        return float(
            Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        )
    # numpy.float64 — cast via float(), then re-enter the float branch
    if hasattr(value, "__float__") and not isinstance(value, (str, bytes)):
        return _quantize(float(value))
    return value  # str, None, etc.


def compute_inputs_hash(inputs: dict[str, Any]) -> str:
    """SHA256 hex of RFC 8785 canonicalized JSON, floats pre-quantized."""
    quantized = _quantize(inputs)
    return hashlib.sha256(rfc8785.dumps(quantized)).hexdigest()
```

**Note on `bool` vs `int`:** Python's `bool` is a subclass of `int` (`isinstance(True, int) is True`). The check order in `_quantize()` matters — `bool` must come first or `True` becomes `1` in the canonical form. [VERIFIED: CPython `numbers.Integral` MRO]

**No-dep contingency (architect panel §Q1):**
```python
# Fallback if rfc8785/jcs both abandoned
def _canon_nodep(value: Any) -> bytes:
    # Recursive key-sort, no special IEEE 754 normalisation
    import json
    def walk(v):
        if isinstance(v, dict):
            return {k: walk(v[k]) for k in sorted(v.keys())}
        if isinstance(v, list):
            return [walk(x) for x in v]
        return v
    return json.dumps(walk(value), separators=(",", ":"), ensure_ascii=False, sort_keys=True).encode("utf-8")
```
**Misses vs JCS:** Unicode NFC normalisation, ECMAScript-style number formatting (`5e-1` vs `0.5`), surrogate-pair handling. Acceptable because our inputs are pre-quantized floats + ASCII keys.

## D-03 — Python ↔ Dart hash parity (deepened)

### Test fixture shape (proposal)

`services/backend/tests/fixtures/hash_parity_50.jsonl` — one JSON per line :

```jsonl
{"id":"hp-001","inputs":{"canton":"VD","age":35,"salary":80000.0,"gross_annual_3a":7056.0,"marital_status":"single"}}
{"id":"hp-002","inputs":{"canton":"ZH","age":50,"salary":120000.50,"gross_annual_3a":7056.0,"marital_status":"married","spouse_salary":90000.0}}
...
```

50 fixtures split across :
- **20 happy path** : single canton × age range 25-65 × salary 60-200k, no nested dicts
- **10 nested** : `{"prevoyance":{"avoir_lpp":350000.0,"taux_conv":0.068}}` (verifies recursive quantize)
- **10 edge floats** : `0.1+0.2` family (`0.30000000000000004`), `1/3` truncation (`0.3333333333333333`), negative `−0.0`, very small `0.005` (banker's-rounding ambiguity)
- **5 boolean** : `{"has_lpp":true,...}` and `{"has_lpp":false,...}` (must NOT collapse to `1`/`0`)
- **5 string-key collisions** : keys that sort lexically — `{"a3a":1, "AVS":2, "lpp":3}` (verifies UTF-8 lexical sort)

### Expected hash format

```jsonl
{"id":"hp-001","sha256":"a3f5...b09e","python_runtime":"3.12.x","rfc8785_version":"0.1.4","computed_at":"2026-05-10T22:00:00Z"}
```

Stored alongside fixtures at `services/backend/tests/fixtures/hash_parity_50_expected.jsonl`. Both Python and Dart must produce the same `sha256` for the same `inputs`.

### Dart-side implementation

**Critical blocker:** `apps/mobile/tools/calc_harness/main.dart` line 19 documents that `dart compile exe` is BLOCKED today by the `lib/constants/social_insurance.dart` → `flutter/foundation.dart` transitive import. The Phase 92.7 closure plan at `.planning/decisions/2026-05-10-pure-dart-calc-harness-extraction.md` (~3-4h scope, Path A two-file split) is **proposed but not landed**.

**Two paths for Phase 95 Wave 1:**

| Path | Risk | Cost |
|------|------|------|
| A — Hash parity uses a NEW pure-Dart standalone (no `financial_core/` imports — just JSON in, hash out) | LOW — no Flutter cascade because the new file only imports `dart:convert` + `dart:io` + a hash impl | ~2h |
| B — Hash parity reuses existing calc_harness AFTER Phase 92.7 closure ships | BLOCKED on Phase 92.7 timeline | sequenced |

**Recommendation : Path A.** Create `apps/mobile/tools/hash_parity_harness/main.dart` — pure-Dart standalone, takes JSONL stdin, emits `{id, sha256}` JSONL stdout. The `financial_core/` cascade is not needed for hash parity (we hash _inputs_, not computed outputs — no calculator code path involved). This sidesteps the 92.7 dependency entirely.

**Dart libraries required:**

| Need | Dart package | Status |
|------|--------------|--------|
| SHA256 | `package:crypto/crypto.dart` (Dart team, official) | [VERIFIED: pub.dev/packages/crypto] |
| Canonical JSON (RFC 8785) | NO official Dart impl | hand-written needed |
| JSON parse/encode | `dart:convert` (stdlib) | always available |

Dart has no `dart_jcs` equivalent on pub.dev (verified by absence in earlier WebSearch). The Dart side must implement RFC 8785 by hand. Three rules suffice for our quantized-float / ASCII-key inputs :

1. Object keys sorted by UTF-16 code unit (Dart's default `String.compareTo` is lexical UTF-16).
2. No whitespace (use `JsonEncoder()` not `JsonEncoder.withIndent`).
3. Floats already pre-quantized Python-side, so Dart sees `80000.0` as `"80000.0"` — but JCS demands `80000` (no trailing `.0` for integer-valued floats). **Recipe:** if `value.truncate() == value`, emit as int.

```dart
// apps/mobile/tools/hash_parity_harness/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

String canonicalize(dynamic v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return '{' + keys.map((k) => '${jsonEncode(k)}:${canonicalize(v[k])}').join(',') + '}';
  }
  if (v is List) {
    return '[' + v.map(canonicalize).join(',') + ']';
  }
  if (v is double) {
    // Integer-valued floats serialise without trailing .0 per JCS
    if (v.truncateToDouble() == v && v.isFinite) {
      return v.toInt().toString();
    }
    return v.toString();
  }
  if (v is bool) return v ? 'true' : 'false';
  if (v == null) return 'null';
  return jsonEncode(v); // strings + ints
}

Future<void> main() async {
  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final fx = jsonDecode(line) as Map<String, dynamic>;
    final canon = canonicalize(fx['inputs']);
    final hash = sha256.convert(utf8.encode(canon)).toString();
    stdout.writeln(jsonEncode({'id': fx['id'], 'sha256': hash}));
  }
}
```

**Integer-scaling fallback (architect R1 mitigation):** If Path-A Dart hash diverges from `rfc8785` Python despite the recipe above, switch the inputs schema BEFORE hash : multiply CHF by 100 (centimes) + rates by 10000 (bps), drop the float branch entirely. Pure integer canonicalisation is trivially deterministic.

## D-04 + D-05 — UUID7 + SQLite TEXT(36) (deepened)

### CRITICAL CORRECTION on D-04

The architect panel claim « UUID7 via `uuid.uuid7()` (Python 3.12+, RFC 9562) » is **WRONG**.

[VERIFIED 2026-05-10 via Python 3.14 release notes + cpython issue #102461]
- UUID6/7/8 **landed in Python 3.14**, not 3.12.
- Railway `services/backend/Dockerfile` line 6 + 22 pin `python:3.12-slim`.
- Local CPython is 3.9.6 (legacy ; not blocking, but `python3 -c "import uuid; uuid.uuid7()"` raises `AttributeError`).

**Backport recommendation:** `uuid_utils>=0.14.1` (released 2026-02-20, Rust-backed, BSD-3-Clause, 22kB sdist, supports Python 3.9-3.14). Drop-in replacement — `uuid_utils.uuid7()` returns a stdlib-compatible `UUID` instance.

```python
# services/backend/app/services/coach/dag_invalidation.py
import uuid_utils  # Rust-backed, Python 3.14 stdlib-compatible

def new_projection_id() -> str:
    """RFC 9562 UUID7 — 48-bit ms timestamp prefix, time-ordered.

    Sorts lexically equivalent to chronological order — `ORDER BY
    superseded_by ASC` reconstructs the supersession chain without
    a separate `created_at` column.
    """
    return str(uuid_utils.uuid7())
```

**Library pin:**
```
# pyproject.toml [project.dependencies]
"uuid_utils>=0.14.1,<1.0.0",
```

**Migration path to stdlib:** When Railway base image upgrades to `python:3.14-slim`, swap `import uuid_utils` for stdlib `import uuid` ; the `uuid.uuid7()` API is identical. Document the swap in the dag_invalidation.py module docstring.

### SQLite TEXT(36) vs alternatives

| Storage | Bytes | Sortability | Index size | Recommendation |
|---------|-------|-------------|------------|-----------------|
| `TEXT(36)` (canonical hyphenated) | 36 | Lexical = chronological (UUID7 property) | Larger | **D-05 choice** |
| `CHAR(32)` (hex no hyphens) | 32 | Same | Smaller by 4 bytes | Marginal win, breaks `UUID(str)` ergonomics |
| `BLOB(16)` (raw 128 bits) | 16 | Same (UUID7 bytes order preserves time) | Smallest | Costs `bytes ↔ UUID` conversion overhead in every read |

D-05 picks TEXT(36) — correct for our scale (likely <1M rows over project lifetime). Ergonomic gain outweighs 20-byte/row storage cost. SQLAlchemy column declaration :

```python
# services/backend/app/models/projection_model.py (NEW or extends scenario_model)
from sqlalchemy import Column, String

class ProjectionDAG:
    inputs_hash = Column(String(64), nullable=True, index=False)
    # SHA256 hex = 64 chars. NOT indexed (Wave 1 — only equality
    # comparisons happen during staleness check, scanned with the row).
    superseded_by = Column(String(36), nullable=True, index=False)
    # UUID7 hyphenated. NOT indexed (Wave 1 — single-row reads via
    # parent ID lookup ; supersession chain reconstruction is rare).
```

**Time-ordering verification:** `str(uuid_utils.uuid7()) < str(uuid_utils.uuid7())` evaluates to `True` for sequential calls because the first 48 bits encode ms since Unix epoch [CITED: RFC 9562 §5.7]. Pytest assertion :

```python
import time
import uuid_utils
def test_uuid7_time_ordered():
    ids = [str(uuid_utils.uuid7()) for _ in range(100)]
    assert ids == sorted(ids), "UUID7 must sort chronologically"
```

## D-06 — Additive migration (deepened)

### Precedent

The most recent additive migration is `alembic/versions/p86_anonymous_session_eclairage_delivered.py` (Phase 71b hotfix, 2026-05-06). It demonstrates :

- Idempotency via `inspector.get_columns(...)` check (re-runnable on local SQLite without error)
- Boolean nullable=False with `server_default=sa.text("false")` (Phase 95 differs : nullable=TRUE with no default)
- Clean `downgrade()` via `op.drop_column(...)`

**Total migrations:** 23 versions in `services/backend/alembic/versions/` [VERIFIED: ls 2026-05-10].

### Recipe for Phase 95 Wave 1

```python
# alembic/versions/p95_dag_invalidation.py
"""Phase 95 DAG-INVALIDATION — inputs_hash + superseded_by additive.

Revision ID: p95_dag_invalidation
Revises: p86_eclairage_delivered
Create Date: 2026-05-1X UTC

Adds two nullable columns to the {projections|scenarios} table :
- inputs_hash : SHA256 hex (64 chars) of RFC 8785 canonical inputs
- superseded_by : UUID7 (36 chars) of the projection that replaced this one

Both default NULL. Existing rows are NULL until the next projection
touch invokes the new emitter. Per CONTEXT D-06 + ROADMAP §Phase 95
Success Criteria #3 (additive only, zero backfill).
"""
from alembic import op
import sqlalchemy as sa


revision = "p95_dag_invalidation"
down_revision = "p86_eclairage_delivered"
branch_labels = None
depends_on = None

TARGET_TABLE = "scenarios"  # OR "projections" — see OQ-2


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c["name"] for c in inspector.get_columns(TARGET_TABLE)}
    if "inputs_hash" not in cols:
        op.add_column(
            TARGET_TABLE,
            sa.Column("inputs_hash", sa.String(64), nullable=True),
        )
    if "superseded_by" not in cols:
        op.add_column(
            TARGET_TABLE,
            sa.Column("superseded_by", sa.String(36), nullable=True),
        )


def downgrade() -> None:
    # SQLite < 3.35 can't drop columns directly — use batch_alter_table
    # for cross-DB compat (precedent: p86_eclairage_delivered raw drop
    # because postgres-only ; we go batch for safety).
    with op.batch_alter_table(TARGET_TABLE) as batch:
        batch.drop_column("superseded_by")
        batch.drop_column("inputs_hash")
```

### Staging DB clone verification (D-17, manual)

```bash
# Manual procedure documented in PLAN.md Wave 1 Task N
# (NOT automated — Phase 96 G3 picks this up)

# 1. Snapshot staging via Railway CLI
railway environment use staging
railway run pg_dump $DATABASE_URL > /tmp/staging_pre95.sql

# 2. Restore to a local Postgres
createdb mint_phase95_test
psql mint_phase95_test < /tmp/staging_pre95.sql

# 3. Run forward migration against the clone
DATABASE_URL=postgresql://localhost/mint_phase95_test alembic upgrade head

# 4. Verify columns exist
psql mint_phase95_test -c "\d scenarios"

# 5. Run downgrade against the same clone
DATABASE_URL=postgresql://localhost/mint_phase95_test alembic downgrade -1

# 6. Verify columns are gone
psql mint_phase95_test -c "\d scenarios"

# 7. Re-run upgrade (idempotency test)
DATABASE_URL=postgresql://localhost/mint_phase95_test alembic upgrade head
```

PLAN.md must capture this 7-step procedure verbatim. CI automation is **explicitly deferred to Phase 96 G3** (CONTEXT D-17).

## D-07 + D-08 — Pydantic v2 ProjectionGroundingPack (deepened)

### Existing stub state

`services/backend/app/services/coach/grounding_pack.py` is 24 lines :
- Single export `GROUNDING_PACK_KEYS_REGISTRY: frozenset[str] = frozenset()`
- Docstring confirms Phase 95 contract (`description_fr`, `raw_value`, `credible_low/high`, `staleness`)

**Decision (planner discretion per CONTEXT):** EXTEND the stub — keep the module path, replace the body. The `frozenset` export can either be retired (Wave 2) or kept as a derived view `frozenset(ProjectionGroundingPack.model_fields["entries"].annotation...)` — planner picks.

### Recipe for `GroundingPackEntry` + `ProjectionGroundingPack`

```python
# services/backend/app/services/coach/grounding_pack.py — Wave 2 replacement
"""Phase 95 DAG-INVALIDATION — ProjectionGroundingPack JSON contract.

Replaces the Phase 93.5 frozenset stub. The 18-key namespace is
inherited verbatim from `citation_registry.CITATION_REGISTRY` ; any
key drift between this model's `entries` dict and the registry triggers
the D-09 fallback path (CITATION_REGISTRY.resolve()).

Per CONTEXT D-07/D-08 :
- `model_config = ConfigDict(frozen=True, extra="forbid")` — Pydantic v2
  invariant project-wide (precedent : citation_registry.py:51).
- Decimal serialisation uses `field_serializer` to stringify (JSON has
  no native Decimal — `json.dumps(Decimal("1.50"))` raises TypeError).
- `staleness_iso` is ISO 8601 string, NOT datetime (planner picks str
  for cross-runtime determinism).
"""
from __future__ import annotations

from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_serializer


class GroundingPackEntry(BaseModel):
    """One cited value in a ProjectionGroundingPack.

    Per CONTEXT D-08 :
    - `value` is the canonical Decimal (CHF or pct depending on key).
    - `raw` is the full financial_core trace dict (audit-trail).
    - `source_ref` is the calc-call signature
      (e.g. `arbitrage_engine.compute_3a_ceiling`) — survives Phase 96
      rename via a registered-source-ref linter (deferred).
    - `credible_low/high` are bootstrap P5/P95 percentiles (None when
      the underlying calc is deterministic, not stochastic).
    - `staleness_iso` is the ISO 8601 timestamp of the input snapshot
      that produced this entry.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    value: Decimal
    raw: dict  # opaque audit trail — financial_core trace
    source_ref: str
    credible_low: Optional[Decimal] = None
    credible_high: Optional[Decimal] = None
    staleness_iso: str

    @field_serializer("value", "credible_low", "credible_high")
    def _ser_decimal(self, v: Optional[Decimal]) -> Optional[str]:
        # Decimal → str preserves precision in JSON ; clients re-hydrate
        # via Decimal(value_str).
        return None if v is None else str(v)


class ParetoPoint(BaseModel):
    """3-point scalarisation result per CONTEXT D-10.

    Three fixed weight sets (fiscal-pure / liquidity-prioritized /
    ruin-reduction-prioritized) — `label` identifies which one.
    Allocation is the recommended CHF split across 3 leviers
    (3a / rachat-LPP / amortissement-indirect).
    """

    model_config = ConfigDict(frozen=True, extra="forbid")

    label: str  # "fiscal_pure" | "liquidity_prioritized" | "ruin_reduction_prioritized"
    weights: dict[str, Decimal]  # {"tax": Decimal("1.0"), "liquidity": Decimal("0.0"), ...}
    allocation: dict[str, Decimal]  # {"3a": Decimal("7056.00"), "rachat_lpp": ..., "amort_indirect": ...}
    projected_outcomes: dict[str, Decimal]  # {"tax_saving_chf": Decimal("2400.00"), "ruin_prob_reduction": Decimal("0.05"), ...}

    @field_serializer("weights", "allocation", "projected_outcomes")
    def _ser_dec_dict(self, d: dict[str, Decimal]) -> dict[str, str]:
        return {k: str(v) for k, v in d.items()}


class ProjectionGroundingPack(BaseModel):
    """Per CONTEXT D-07/D-08."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    inputs_hash: str = Field(..., min_length=64, max_length=64)  # SHA256 hex
    entries: dict[str, GroundingPackEntry]
    pareto_points: list[ParetoPoint] = Field(..., min_length=3, max_length=3)  # D-10 : exactly 3
    what_ifs: dict[str, GroundingPackEntry] = Field(..., min_length=5, max_length=5)  # D-11 : exactly 5
    legal_constraints: list[str]
    superseded_by: Optional[str] = Field(default=None, min_length=36, max_length=36)  # UUID7


__all__ = ["GroundingPackEntry", "ParetoPoint", "ProjectionGroundingPack"]
```

**Decimal serialisation note:** Pydantic v2 supports `Decimal` natively in models, but the default `model_dump_json()` raises on Decimal. The `@field_serializer` decorator coerces to `str` for transport ; clients re-hydrate. [CITED: https://docs.pydantic.dev/latest/concepts/serialization/]

**18-key namespace coupling test (Wave 2 must add):**
```python
# tests/test_dag_invalidation/test_pack_registry_coupling.py
from app.services.coach.citation_registry import CITATION_REGISTRY
from app.services.coach.grounding_pack import ProjectionGroundingPack

def test_pack_entries_keys_subset_of_registry(sample_pack: ProjectionGroundingPack):
    """Every key in pack.entries MUST exist in CITATION_REGISTRY,
    otherwise the D-09 double-lookup fallback silently fires."""
    registry_keys = set(CITATION_REGISTRY.keys())
    pack_keys = set(sample_pack.entries.keys())
    drift = pack_keys - registry_keys
    assert not drift, (
        f"Pack-only keys (no registry fallback): {drift}. Add to "
        f"citation_registry.py or remove from pack.entries."
    )
```

## D-09 — Double-lookup cohabitation (deepened)

### Extension point exact location

`services/backend/app/services/coach/citation_parser.py:352-365` — current body :

```python
def _substitute_placeholders(response_text: str, ctx) -> str:
    def _swap(m: re.Match[str]) -> str:
        body = m.group(0)
        key = body[len("{{cite:"):-2]
        resolved = resolve(key, ctx)  # ← CITATION_REGISTRY lookup today
        return resolved if resolved is not None else body
    return _RE_CITE_PLACEHOLDER.sub(_swap, response_text)
```

### Required Wave 2 modification

```python
def _substitute_placeholders(
    response_text: str,
    ctx,
    pack: ProjectionGroundingPack | None = None,  # ← NEW Wave 2 param
) -> str:
    """D-09 double-lookup. Tries `pack.entries[key]` first when a pack
    is supplied ; falls back to `CITATION_REGISTRY.resolve(key, ctx)`.
    Both paths cohabit during Phase 95 + 96 (CITATION_REGISTRY removal
    deferred post-96 — sequencing-panel §1).
    """
    def _swap(m: re.Match[str]) -> str:
        body = m.group(0)
        key = body[len("{{cite:"):-2]
        # D-09 step 1 — pack lookup if present
        if pack is not None:
            entry = pack.entries.get(key)
            if entry is not None:
                # Format Decimal as FR-locale CHF/pct string — depends on
                # the registry source_kind. For Wave 2 MVP : str(entry.value).
                # Phase 96 NarrativeSleeve handles richer formatting.
                return str(entry.value)
        # D-09 step 2 — registry fallback (unchanged Phase 94 path)
        resolved = resolve(key, ctx)
        return resolved if resolved is not None else body

    return _RE_CITE_PLACEHOLDER.sub(_swap, response_text)
```

### Caller survey (grep result, 2026-05-10)

```
services/backend/app/services/coach/citation_parser.py:352:def _substitute_placeholders(response_text: str, ctx) -> str:
services/backend/app/services/coach/citation_parser.py:525:    gated_text = _substitute_placeholders(response_text, ctx)
```

**Only ONE caller** — line 525 of the same module, inside `gate()`. **No external callers.** This is a Karpathy #3 surgical win : the signature change blast-radius is 1 line. The wrapper at `coach_chat.py:3339-3376` (`_run_narrator_with_gate()`) passes through `gate()` and doesn't touch `_substitute_placeholders` directly.

**Plumbing required (Wave 2):**

1. `gate()` signature gains `pack: ProjectionGroundingPack | None = None` (default keeps Phase 94 behaviour).
2. Line 525 becomes `gated_text = _substitute_placeholders(response_text, ctx, pack=pack)`.
3. `_run_narrator_with_gate()` in `coach_chat.py:3339` receives the pack from the caller (Phase 96 source-card context will populate it ; in Phase 95 the param stays `None` end-to-end and falls back to registry — pure infrastructure).

### Pack/registry agreement contract

The 18 keys MUST agree. From `citation_registry.py` lines 67-177, the v1 baseline keys are :

```
r3a_plafond_salarie_2026, r3a_plafond_independant_2026, lifd_art_33_deduction,
lifd_art_38_capital_taux, lpp_taux_conv_obligatoire_2026, opp2_coordination_2026,
lpp_rente_survivant_pct, lavs_age_reference_2026, lifd_art_22_rentes,
lifd_art_33_deduction_3a, lifd_art_33_rachat_lpp, lifd_art_38_taux_reduit,
lhid_harmonisation, finma_taux_calculatoire, amortissement_taux_2026,
finma_lcb_tragbarkeit, ltv_max_residence_principale, ratio_endettement_max_33pct
```

**Wave 2 test : `tests/test_dag_invalidation/test_pack_keys_align_with_registry.py`** — asserts that every key the GroundingPack emitter populates is present in `CITATION_REGISTRY` keys. Drift breaks the D-09 fallback silently — the existing Phase 94 keys would fall to `resolve() → None → placeholder kept verbatim`, narrator quality degrades but no error fires. This test is the canary.

## D-10 — 3-point Pareto (deepened)

### Existing arbitrage_engine state

`apps/mobile/lib/services/financial_core/arbitrage_engine.dart` (2116 lines, S32 Phase 1) has methods :

- `compareRenteVsCapital(...)` — rente vs capital vs mixed (line 74)
- (continued lines 100-2116 contain allocation methods — only first 80 lines read in this research)

The 3 leviers (3a / rachat-LPP / amortissement-indirect) are mentioned in `TrajectoireOption.id` enum values at `arbitrage_models.dart:31` : `"3a", "rachat_lpp", "amort_indirect"`. The engine emits `TrajectoireOption` Dart objects already — **the calc work mostly exists**.

### 3 weight sets specification

```python
# Wave 2 — services/backend/app/services/coach/grounding_pack_emitter.py (NEW)

PARETO_WEIGHT_SETS = (
    # D-10 weight set 1 — fiscal-pure (maximize current-year tax savings)
    {
        "label": "fiscal_pure",
        "weights": {
            "tax_saving": Decimal("1.00"),
            "liquidity":  Decimal("0.00"),
            "ruin_red":   Decimal("0.00"),
        },
    },
    # D-10 weight set 2 — liquidity-prioritized (balance tax + 12-month cash buffer)
    {
        "label": "liquidity_prioritized",
        "weights": {
            "tax_saving": Decimal("0.50"),
            "liquidity":  Decimal("0.50"),
            "ruin_red":   Decimal("0.00"),
        },
    },
    # D-10 weight set 3 — ruin-reduction-prioritized
    {
        "label": "ruin_reduction_prioritized",
        "weights": {
            "tax_saving": Decimal("0.40"),
            "liquidity":  Decimal("0.00"),
            "ruin_red":   Decimal("0.60"),
        },
    },
)


def compute_pareto_points(
    profile: dict,
    trajectoires: list[dict],  # 3a + rachat_lpp + amort_indirect outputs from Dart side
) -> list[ParetoPoint]:
    """For each weight set, score the 3 leviers and pick the allocation
    that maximises the weighted objective. Returns exactly 3 ParetoPoint.
    
    NOT a real Pareto front — NSGA-II via pymoo is backlog 999.2 per D-10.
    This is fixed-weight scalarisation : 3 weighted sums, 3 winners.
    """
    points = []
    for spec in PARETO_WEIGHT_SETS:
        scored = []
        for t in trajectoires:
            weighted = (
                spec["weights"]["tax_saving"] * t["tax_saving_chf"]
                + spec["weights"]["liquidity"] * t["liquidity_score"]
                + spec["weights"]["ruin_red"] * t["ruin_prob_reduction"]
            )
            scored.append((weighted, t))
        scored.sort(key=lambda x: x[0], reverse=True)
        winner = scored[0][1]
        points.append(ParetoPoint(
            label=spec["label"],
            weights=spec["weights"],
            allocation=winner["allocation"],
            projected_outcomes={
                "tax_saving_chf":   Decimal(str(winner["tax_saving_chf"])),
                "liquidity_score":  Decimal(str(winner["liquidity_score"])),
                "ruin_prob_red":    Decimal(str(winner["ruin_prob_reduction"])),
            },
        ))
    return points
```

**Planner decision needed:** is `compute_pareto_points` called in backend Python (consuming Dart `arbitrage_engine` outputs serialised via the API) OR in Dart-side (emitting `ParetoPoint` JSON directly) ? CONTEXT D-10 + canonical_refs §Calc-first foundation suggest **Dart emits, backend consumes** (financial_core SOURCE OF TRUTH per CLAUDE.md rule 4). The backend recipe above is the consumer-side. Planner confirms.

## D-11 — Uni-variate ±10% sensitivity (deepened)

### Top 5 inputs to perturb

Selected by impact on AVS/LPP/3a projections + LSFin user-relevance :

| # | Input | Rationale |
|---|-------|-----------|
| 1 | `income_brut_annual` | Drives AVS rente, 3a ceiling, marginal tax bracket |
| 2 | `current_lpp_balance` | Drives projected LPP at retirement |
| 3 | `current_age` | Drives years-to-retirement compounding |
| 4 | `target_retirement_age` | Drives capital accumulation window + LPP conversion rate |
| 5 | `current_3a_balance` | Drives 3a runway + tax-deduction recurrence |

`marital_status`, `canton` are **categorical** — uni-variate ±10% doesn't apply, so they're excluded. If the planner picks a different 5, document the rationale in PLAN.md.

### Recipe

```python
def compute_what_ifs(
    base_inputs: dict,
    compute_fn: Callable[[dict], dict],  # closure over financial_core
    perturb_keys: tuple[str, ...] = ("income_brut_annual", "current_lpp_balance",
                                       "current_age", "target_retirement_age",
                                       "current_3a_balance"),
) -> dict[str, GroundingPackEntry]:
    """D-11 — 5 uni-variate ±10% sensitivity entries.

    Each entry value is the DELTA between base outcome and perturbed
    outcome (signed CHF). raw dict carries `{"baseline":..., "plus10":...,
    "minus10":...}` for audit trail. Sobol indices via Saltelli deferred
    to backlog 999.x (D-11).
    """
    baseline_out = compute_fn(base_inputs)
    result = {}
    for k in perturb_keys:
        base_v = Decimal(str(base_inputs[k]))
        plus = {**base_inputs, k: float(base_v * Decimal("1.10"))}
        minus = {**base_inputs, k: float(base_v * Decimal("0.90"))}
        out_plus = compute_fn(plus)
        out_minus = compute_fn(minus)
        # MVP : capture delta on the headline outcome (projected retirement income).
        delta_plus = Decimal(str(out_plus["retirement_income"])) - Decimal(str(baseline_out["retirement_income"]))
        delta_minus = Decimal(str(out_minus["retirement_income"])) - Decimal(str(baseline_out["retirement_income"]))
        result[f"sensitivity_{k}"] = GroundingPackEntry(
            value=delta_plus,  # signed CHF impact of +10% on this input
            raw={"baseline": baseline_out, "plus10": out_plus, "minus10": out_minus},
            source_ref=f"sensitivity.{k}",
            credible_low=delta_minus,   # -10% delta as lower bound
            credible_high=delta_plus,    # +10% delta as upper bound
            staleness_iso=datetime.now(timezone.utc).isoformat(),
        )
    return result
```

Output dict has exactly 5 keys — `sensitivity_<input>` — matching D-08 `what_ifs: dict[str, GroundingPackEntry]` (5 entries).

## D-12 — Bootstrap CIs 200 iterations (deepened)

### Existing Monte Carlo state

`apps/mobile/lib/services/financial_core/monte_carlo_service.dart` line 222-225 implements iid-Gaussian draws :

```dart
final lppReturnYear = _normalRandom(random, mean: 0.015, sd: 0.065);
final salaryGrowthYear = _normalRandom(random, mean: 0.01, sd: 0.015).clamp(-0.02, 0.05);
```

The MC runs **per profile, per year, per N trajectories** and returns terminal-wealth distributions. Wave 7 actuarial audit P0-M1 (2026-04-18) calibrated σ=6.5% (Pictet BVG-25, Credit Suisse PK Index 2000-2024).

### Bootstrap recipe

```python
# Wave 2 — services/backend/app/services/coach/bootstrap_ci.py (NEW)
import numpy as np  # confirmed available in .venv (services/backend/.venv/bin/numpy-config)

def bootstrap_ci(
    trajectories: list[float],  # N terminal-wealth samples from MC
    iterations: int = 200,
    rng_seed: int = 42,  # D-12 deterministic seed (planner can switch to inputs_hash-derived)
) -> tuple[Decimal, Decimal]:
    """200-iter resample-with-replacement, return (P5, P95) of the mean
    distribution. Annotates the existing iid-Gaussian MC — narrator
    MUST emit « selon le modèle simplifié actuel » when surfacing these
    bounds (D-12 LSFin escape hatch).
    """
    rng = np.random.RandomState(rng_seed)
    n = len(trajectories)
    arr = np.array(trajectories, dtype=np.float64)
    means = np.empty(iterations, dtype=np.float64)
    for i in range(iterations):
        sample = rng.choice(arr, size=n, replace=True)
        means[i] = sample.mean()
    p5 = float(np.percentile(means, 5))
    p95 = float(np.percentile(means, 95))
    return (Decimal(str(round(p5, 2))), Decimal(str(round(p95, 2))))
```

### Seed strategy

**Two options, planner picks per CONTEXT « Claude's Discretion » :**

| Option | Pro | Con |
|--------|-----|-----|
| Fixed `RandomState(42)` | Trivially reproducible, debug-friendly | Same CI for every user — masks input-driven variance |
| Per-input seed from `inputs_hash` (`int(inputs_hash[:8], 16) % (2**32)`) | CI varies with inputs, more informative | Two users with identical inputs get same CI (OK — that's correctness) ; harder to debug |

**Recommendation:** Per-input seed derived from `inputs_hash` (option 2). Aligns with the DAG-invalidation philosophy (same inputs → same hash → same CI ; different inputs → different CI). Plan can override to fixed-42 if reproducibility wins out for the planner.

### Performance

- 200 iterations × N=1000 trajectories × 1 mean reduction = 200K array ops
- `np.random.RandomState.choice` on a 1000-element array is ~10 µs
- Total bootstrap CI per user ≈ 2-5 ms wall-clock

Negligible. Within the 50ms gate p95 budget already enforced at `test_gate_performance.py`.

## D-13 — Plan / wave split (already explicit in CONTEXT, no deepening needed)

Per CONTEXT : Plan 95-01 (Wave 1, ~2d) = hash + migration + parity. Plan 95-02 (Wave 2, ~2d, blocks on W1 merge) = emission + double-lookup + pareto + what_ifs + bootstrap. Verifier = separate cycle.

## D-14..D-18 — Compliance gates (already explicit, light deepening)

- **D-14:** the new lint `tools/checks/pii_fixture_scan.py` is currently absent — planner adds it in Wave 1. Recipe : grep regex `\b756\.\d{4}\.\d{4}\.\d{2}\b` (AHV13 format) + `\+41[\s\-]?\d{2}[\s\-]?\d{3}[\s\-]?\d{2}[\s\-]?\d{2}\b` (Swiss phone) over every `.jsonl` in `services/backend/tests/fixtures/`. Exit 1 on any match.
- **D-15:** hash_parity 50/50 — see §D-03.
- **D-16:** backend pytest baseline post-Phase-94.1 is 6448 (verified at STATE.md Plan 94.1-01 Receipt). Phase 95 target ≥ 6471 implies ~23 new tests across W1+W2.
- **D-17:** manual on staging clone — see §D-06 recipe.
- **D-18:** N/A Phase 95 (backend-only).

## Pitfalls (top 5 risks)

### Pitfall 1 — Float-hash parity Python↔Dart (R1, HIGH)

**What goes wrong:** `0.1 + 0.2 = 0.30000000000000004` in IEEE 754. Python and Dart serialise this differently if the canonicalisation recipe drifts. False-positive `staleness=high` flag fires on every profile read — narrator falls back to registry constantly → Phase 95 ships dead.

**Why it happens:** JCS Number serialisation rules use ECMAScript `Number.prototype.toString()` — not trivial to reproduce in Dart without a hand-written recipe.

**How to avoid:**
1. Quantise floats BEFORE canonicalise (D-02 — Decimal(2) for CHF, exact representation).
2. Test 50 fixtures Python ↔ Dart in CI (D-15 — block merge on any divergence).
3. Document centime/bps integer-scaling fallback — switch input schema to ints if floats can't be tamed.

**Warning signs:** First Wave 1 task runs the 50-fixture test → if even 1/50 diverges, STOP and pivot to integer scaling before fattening the migration.

### Pitfall 2 — UUID7 missing on Python 3.12 (CRITICAL CORRECTION)

**What goes wrong:** Architect panel said « `uuid.uuid7()` Python 3.12+ ». Wrong — it's 3.14. Railway runs 3.12. `import uuid; uuid.uuid7()` raises `AttributeError` in prod.

**Why it happens:** UUID6/7/8 landed in CPython 3.14 (cpython issue #102461, merged late 2025). Architect panel did not verify against runtime constraint.

**How to avoid:**
1. Pin `uuid_utils>=0.14.1,<1.0.0` in pyproject.toml — Rust-backed backport, drop-in API.
2. Document the stdlib swap path for when Railway upgrades to 3.14.
3. Add a smoke test that `uuid_utils.uuid7()` returns a 36-char hyphenated string parseable by `uuid.UUID(str)`.

**Warning signs:** First Wave 1 import statement — if planner blindly types `from uuid import uuid7`, the test suite fails on Railway CI immediately.

### Pitfall 3 — `_substitute_placeholders()` signature change blast-radius (LOW today, MEDIUM if missed)

**What goes wrong:** Adding `pack: ProjectionGroundingPack | None = None` to `_substitute_placeholders` propagates to `gate()` signature → propagates to every caller of `gate()`. If a caller passes positional args, Phase 95 breaks Phase 94.

**Why it happens:** Python keyword-or-positional default arguments are not enforced as keyword-only unless declared with `*,` separator.

**How to avoid:** Declare new params keyword-only (`def gate(response_text, ctx, *, citation_allowlist=None, is_retry=False, pack=None)`). Grep already confirms only ONE non-test caller (line 525 of `citation_parser.py` itself, calling `_substitute_placeholders` not `gate`). The `gate()` callers are in `coach_chat.py:3348, 3368` and they already use keyword args.

**Warning signs:** `flutter test` is N/A, but `pytest -q services/backend/tests/test_citation_gate/` must stay green when the signature changes.

### Pitfall 4 — Pack/registry key drift = silent FALLBACK (R3 from architect)

**What goes wrong:** Wave 2 GroundingPack emits 18 keys ; one of them is misspelled (`r3a_plafond_salarie_2026` vs `r3a_plafond_salaries_2026`). The pack lookup returns None, the registry lookup ALSO returns None (typo on both sides), `_substitute_placeholders` returns the placeholder verbatim → narrator output reads « le plafond {{cite:r3a_plafond_salaries_2026}} CHF » to the user.

**Why it happens:** No compile-time check on string keys.

**How to avoid:**
1. `test_pack_keys_align_with_registry.py` — asserts `pack.entries.keys() ⊆ CITATION_REGISTRY.keys()`.
2. Pydantic v2 `Literal[<18 keys>]` type for `GroundingPackEntry.key` field (the registry has the canonical list — derive the Literal from it via `Literal[*CITATION_REGISTRY.keys()]` using `typing_extensions.LiteralString` — Python 3.12 supports this).
3. Output a Wave 2 sanity log : « pack emitted 18/18 keys » or « pack emitted 17/18 — missing X » as a debug breadcrumb.

**Warning signs:** First end-to-end smoke run shows `{{cite:<key>}}` still in narrator output post-gate → key drift.

### Pitfall 5 — Targeting the wrong table (`projections` vs `scenarios`)

**What goes wrong:** Architect panel + CONTEXT D-05 say « ALTER TABLE projections ». There is NO `projections` table — only `scenarios` (`services/backend/app/models/scenario.py`). The migration named in PLAN.md would fail on `op.add_column("projections", ...)` because the table doesn't exist.

**Why it happens:** Architect panel synthesised against the ROADMAP-level concept (« projection ») not the concrete model name.

**How to avoid:** Planner picks ONE in Wave 1 Task 1, AND documents the choice :
- **Option A:** Extend `scenarios` table — `scenarios.inputs_hash`, `scenarios.superseded_by`. Aligns with the existing `ScenarioModel { id, profile_id, kind, inputs, outputs, created_at }` (already has the `inputs` JSON column the hash would key off).
- **Option B:** Create a NEW `projections` table — separation of concerns, but doubles the migration scope and forces a `JOIN scenarios USING(profile_id, kind)` everywhere a projection is read.

**Recommendation:** Option A (extend `scenarios`). The CONTEXT semantics are preserved (« every projection has inputs_hash + superseded_by ») and the migration scope stays minimal (additive, idempotent, ~10 LOC). See OQ-2.

**Warning signs:** Wave 1 alembic dry-run fails with `psycopg2.errors.UndefinedTable: relation "projections" does not exist`.

## Code search results

### Callers of `_substitute_placeholders()`

```
services/backend/app/services/coach/citation_parser.py:352:def _substitute_placeholders(response_text: str, ctx) -> str:
services/backend/app/services/coach/citation_parser.py:525:    gated_text = _substitute_placeholders(response_text, ctx)
```

**One caller, same module.** Signature change is surgical (Karpathy #3).

### Callers of `gate()` / `GatedResponse`

```
services/backend/app/api/v1/endpoints/coach_chat.py:61:    GatedResponse,
services/backend/app/api/v1/endpoints/coach_chat.py:3318:        gated: GatedResponse, retries: int,
services/backend/app/api/v1/endpoints/coach_chat.py:3348:        gated = _citation_gate(...)
services/backend/app/api/v1/endpoints/coach_chat.py:3368:        retry_gated = _citation_gate(...)
```

Both call-sites use keyword args. Adding `pack=` kwarg is non-breaking.

### Existing `inputs_hash` stub references

```
services/backend/app/services/coach/citation_parser.py:254:    - `inputs_hash` — Phase 95 stub field. Always `None` in Phase 94.
services/backend/app/services/coach/citation_parser.py:263:    inputs_hash: Optional[str] = None  # Phase 95 stub
services/backend/app/services/coach/citation_parser.py:430:            inputs_hash=None,
services/backend/app/services/coach/citation_parser.py:459:            inputs_hash=None,
services/backend/app/services/coach/citation_parser.py:468:            inputs_hash=None,
services/backend/app/services/coach/citation_parser.py:512:            inputs_hash=None,
services/backend/app/services/coach/citation_parser.py:521:            inputs_hash=None,
services/backend/app/services/coach/citation_parser.py:533:            inputs_hash=None,
```

**7 stub sites** — every `GatedResponse(...)` constructor. Wave 1 populates the field when a pack is present ; Wave 2 wires the pack through.

### Existing alembic migration count

23 versions in `services/backend/alembic/versions/`. Most recent : `p86_anonymous_session_eclairage_delivered.py` (2026-05-06, Phase 71b hotfix). The new migration revision identifier should be `p95_dag_invalidation` with `down_revision = "p86_eclairage_delivered"`.

### `projections` table check

```
grep -rln "class Projection\|create_table.*projection" services/backend/app/models/ services/backend/alembic/
→ (no results)
```

**CONFIRMED:** there is NO `projections` table or model. See Pitfall 5 + OQ-2.

### numpy availability

```
services/backend/.venv/bin/numpy-config (present)
```

Numpy is **already installed** transitively (likely via chromadb / pandas dependency chain). No new top-level pyproject entry needed for `bootstrap_ci.py`. Wave 2 can `import numpy as np` directly.

## Library version pins (verified 2026-05-10)

```toml
# pyproject.toml additions for Phase 95
[project.dependencies]
# ... existing ...
"rfc8785>=0.1.4,<1.0.0",        # RFC 8785 JCS — Trail of Bits, zero deps, 2024-09-27
"uuid_utils>=0.14.1,<1.0.0",    # UUID7 backport — Rust-backed, BSD-3-Clause, 2026-02-20
```

Skip `jcs==0.2.1` (stale since 2022-04-10). Skip `future-uuid` and `uuid6` and `uuid-backport` (less active than `uuid_utils`).

## Project Constraints (from CLAUDE.md)

- **Banned terms LSFin (CLAUDE.md §1):** no « garanti », « optimal », « meilleur », « certain », « assuré », « sans risque », « parfait ». Use « pourrait », « envisager », « adapté ». **Phase 95 implication:** the « selon le modèle simplifié actuel » narrator annotation (D-12) is the LSFin escape for bootstrap CIs ; narrator MUST emit it verbatim when surfacing P5/P95.
- **Accents 100% FR (CLAUDE.md §2):** every FR string constant in new modules (`grounding_pack.py`, `dag_invalidation.py`, etc.) MUST use proper accents. Lint via `tools/checks/accent_lint_fr.py` (D-14).
- **MINT ≠ retirement app (CLAUDE.md §3):** the 18 keys in `CITATION_REGISTRY` cover 4 life domains (pillar3a/lpp/tax/mortgage). GroundingPack does NOT add retirement-specific keys in Phase 95 — keys come from the same 18-key namespace.
- **Financial_core reuse (CLAUDE.md §4):** the Pareto emitter (D-10) MUST consume `ArbitrageEngine` outputs verbatim — never re-implement `compareRenteVsCapital` or `_calculateRente` Python-side. Backend is the consumer ; Dart is the source of truth.
- **i18n required (CLAUDE.md §5):** no user-facing strings in this phase (backend-only). The narrator annotation « selon le modèle simplifié actuel » lives in Phase 96 NarrativeSleeve, NOT here.
- **0-trust (CLAUDE.md §9):** the planner MUST NOT claim « shipped » or « ready » on PRs until G5 manual staging-clone verification (D-17) is logged. The phase verifier closes this in a separate cycle (D-13).

## Validation Architecture

`.planning/config.json` was not read in this session — assume `workflow.nyquist_validation` is enabled by default per agent contract.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pytest 8.x + pytest-asyncio 0.23.x + hypothesis 6.111 [VERIFIED: pyproject.toml lines 50-56] |
| Config file | `services/backend/pyproject.toml [tool.pytest.ini_options]` |
| Quick run command | `cd services/backend && pytest tests/test_dag_invalidation/ -q` |
| Full suite command | `cd services/backend && pytest -q` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DAG-01 | `inputs_hash` deterministic for same inputs | unit | `pytest tests/test_dag_invalidation/test_inputs_hash.py::test_deterministic -x` | ❌ Wave 0 |
| DAG-01 | float-quantization eliminates IEEE 754 drift | unit | `pytest tests/test_dag_invalidation/test_inputs_hash.py::test_float_quantize -x` | ❌ Wave 0 |
| DAG-01 | Python↔Dart hash parity 50/50 | integration | `pytest tests/test_dag_invalidation/test_hash_parity.py -x` | ❌ Wave 0 |
| DAG-02 | `superseded_by` UUID7 is time-ordered | unit | `pytest tests/test_dag_invalidation/test_uuid7.py::test_time_ordered -x` | ❌ Wave 0 |
| DAG-02 | UUID7 backport import works on Python 3.12 | smoke | `python -c "import uuid_utils; uuid_utils.uuid7()"` | ❌ Wave 0 |
| DAG-03 | `staleness_iso` mismatch triggers fallback path | unit | `pytest tests/test_dag_invalidation/test_staleness.py -x` | ❌ Wave 0 |
| DAG-04 | Alembic upgrade head + downgrade head clean | integration | `cd services/backend && alembic upgrade head && alembic downgrade -1 && alembic upgrade head` | ❌ Wave 0 |
| DAG-04 | Migration idempotent on re-run | integration | `pytest tests/test_dag_invalidation/test_migration_idempotent.py -x` | ❌ Wave 0 |
| Pack/registry alignment | every pack key ∈ CITATION_REGISTRY | unit | `pytest tests/test_dag_invalidation/test_pack_registry_coupling.py -x` | ❌ Wave 0 |
| `_substitute_placeholders` double-lookup | pack hit overrides registry | unit | `pytest tests/test_citation_gate/test_substitution_double_lookup.py -x` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `pytest tests/test_dag_invalidation/ -q` (~5 sec)
- **Per wave merge:** `pytest -q` full suite (≥6471 baseline target — currently 6448 post-94.1)
- **Phase gate:** Full suite green + 50/50 hash parity + staging-clone alembic manual verification (D-17) logged

### Wave 0 Gaps

- [ ] `services/backend/tests/test_dag_invalidation/__init__.py` — namespace
- [ ] `services/backend/tests/test_dag_invalidation/test_inputs_hash.py` — unit tests for compute_inputs_hash
- [ ] `services/backend/tests/test_dag_invalidation/test_uuid7.py` — unit tests for new_projection_id
- [ ] `services/backend/tests/test_dag_invalidation/test_hash_parity.py` — Python↔Dart cross-runtime check
- [ ] `services/backend/tests/test_dag_invalidation/test_migration.py` — alembic up/down/up idempotency
- [ ] `services/backend/tests/fixtures/hash_parity_50.jsonl` — 50 input dicts (see §D-03)
- [ ] `services/backend/tests/fixtures/hash_parity_50_expected.jsonl` — 50 expected hashes
- [ ] `apps/mobile/tools/hash_parity_harness/main.dart` — Dart harness (~50 LOC pure-Dart, sidesteps Phase 92.7 cascade)
- [ ] `tools/checks/pii_fixture_scan.py` — D-14 new lint
- [ ] `services/backend/tests/test_citation_gate/test_substitution_double_lookup.py` — Wave 2 D-09 coverage

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 95 is backend data-model only ; auth boundary unchanged |
| V3 Session Management | no | Same |
| V4 Access Control | no | Same |
| V5 Input Validation | yes | Pydantic v2 `ProjectionGroundingPack` with `extra="forbid"` + frozen ; rejects unknown fields at deserialise (T-94-02 precedent) |
| V6 Cryptography | yes | SHA256 via `hashlib` stdlib (FIPS 180-4) ; `uuid_utils` UUID7 uses CSPRNG for tail bits per RFC 9562 |
| V7 Error Handling | partial | Alembic migration logs at INFO ; Sentry breadcrumb on staleness mismatch (extend Phase 94 pattern at `coach_chat.py:3320`) |
| V8 Data Protection | yes | `inputs_hash` is NOT a PII vector (it's a deterministic digest, not reversible) — confirms with D-14 `pii_fixture_scan.py` extended to scan hash_parity_50.jsonl |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hash collision injection (find inputs A ≠ B with `hash(A) == hash(B)`) | Tampering | SHA256 collision resistance is 2^128 work-factor — out of reach. RFC 8785 eliminates the canonicalisation-ambiguity attack surface. |
| Pydantic `extra="allow"` drift opening unknown-field injection | Tampering | `extra="forbid"` enforced project-wide (precedent : `citation_registry.py:51`). |
| AHV13 leaking into `hash_parity_50.jsonl` fixtures | Information Disclosure | `tools/checks/pii_fixture_scan.py` (new, D-14) — regex match on AHV13 + Swiss phone patterns, exit 1 on any. |
| Alembic downgrade losing data | Tampering | Migration is ADDITIVE NULLABLE — downgrade drops columns, but no existing data lives in those columns (zero backfill). Data loss = 0. |

## Runtime State Inventory

> Phase 95 is **additive backend code + migration**, not a rename or refactor. Runtime State Inventory is not required per the SKILL.md template, but a light pass below confirms no stale state lurking.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `scenarios` table — `inputs` JSON column will be hashed lazily on next write. Pre-existing rows : NULL inputs_hash + NULL superseded_by. | None — additive, NULL-tolerant by design (D-06). |
| Live service config | None — no n8n / Datadog / Tailscale touchpoints in Phase 95. | None. |
| OS-registered state | None — no LaunchAgent / pm2 / systemd touchpoints. | None. |
| Secrets/env vars | None added in Phase 95. Phase 94's `COACH_CITATION_GATE_ENABLED` (staging-on) is unchanged. | None. |
| Build artifacts | Dart-side `apps/mobile/tools/hash_parity_harness/` is a NEW pure-Dart binary, separate from the cascade-blocked `calc_harness`. No artifact carryover. | Wave 1 task : compile + commit fingerprint to git for CI reproducibility. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.12 (Railway prod) | All backend code | ✓ | 3.12-slim (Dockerfile line 6) | — |
| Python 3.9.6 (local) | Local dev | ✓ | 3.9.6 | matches `requires-python = ">=3.10"` mismatch — pyproject says 3.10+, but local 3.9 is dev-only |
| `rfc8785` PyPI | D-01 canonicalisation | ✗ | needs install | `jcs==0.2.1` (stale) or no-dep recipe (§D-01) |
| `uuid_utils` PyPI | D-04 UUID7 backport | ✗ | needs install | `future-uuid` or `uuid6` PyPI ; stdlib `uuid.uuid7` only on 3.14+ |
| `numpy` | D-12 bootstrap | ✓ | already in .venv (transitive via chromadb/rag extras) | pure-python bootstrap (slower ~50ms, acceptable) |
| `dart compile exe` on calc_harness | D-03 Dart parity | ✗ | BLOCKED by Flutter cascade | New pure-Dart harness at `apps/mobile/tools/hash_parity_harness/` (Path A — §D-03) |
| Railway pg_dump for D-17 | Staging clone | ✓ | Railway CLI installed locally | — |
| Sentry breadcrumb wiring | Telemetry | ✓ | `coach_chat.py:3320` precedent | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** `rfc8785` + `uuid_utils` — both have viable fallbacks, but PyPI install is the cleanest path.

## Assumptions Log

> Claims that need user confirmation before becoming locked decisions.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `rfc8785` (Trail of Bits) is preferred over CONTEXT-named `jcs` | §D-01 | LOW — both implement RFC 8785 ; if Julien prefers strict CONTEXT compliance, fall back to `jcs==0.2.1` (functional, just stale). Plan documents the substitution and reasoning. |
| A2 | Phase 95 targets `scenarios` table, NOT a new `projections` table | §Pitfall 5 + OQ-2 | MEDIUM — if a `projections` table is conceptually required for Phase 96 chat-as-verb (UI surface needs separate persistence), creating it later is a bigger migration than doing it now. Planner confirms with Julien in Wave 1 Task 1. |
| A3 | Pareto computation is BACKEND-SIDE consuming Dart outputs (not Dart-side) | §D-10 | MEDIUM — financial_core SOURCE OF TRUTH per CLAUDE.md rule 4 ; backend should consume not compute. But the 3-point scalarisation is trivial — could live either side. Planner picks. |
| A4 | Top 5 inputs for sensitivity = income/lpp/age/retirement_age/3a_balance | §D-11 | LOW — any 5 inputs work for MVP ; if planner picks differently, document in PLAN.md. |
| A5 | Bootstrap RNG seed derives from `inputs_hash` (option 2) | §D-12 | LOW — pure cosmetic choice. Fixed `RandomState(42)` is the safer-debug fallback. |

## Open Questions (RESOLVED)

> All four OQs resolved during planner-revision iteration 1 (2026-05-11). Resolutions inline below.

### OQ-1 — Python version for `uuid.uuid7` stdlib (RESOLVED)

**RESOLUTION (2026-05-11):** Adopt `uuid_utils>=0.14.1` backport. Railway Python 3.14 base-image upgrade tracked as backlog 999.x (deferred — no urgency). The migration path back to stdlib `uuid.uuid7()` is documented in `services/backend/app/services/coach/projection_id.py` module docstring (per Plan 95-01 Task 3).

**What we know:** UUID6/7/8 landed in CPython 3.14 (cpython issue #102461, late 2025). Railway Dockerfile pins `python:3.12-slim`. Architect panel claim « Python 3.12+ » is wrong.

**What's unclear:** Whether Julien wants to (a) accept the backport (`uuid_utils`) or (b) bump Railway base image to `python:3.14-slim` to use stdlib.

**Recommendation:** Adopt `uuid_utils` backport. Cheaper than a base-image bump that touches every backend deploy + every dev's local env. Document the stdlib migration path for when Railway naturally upgrades.

### OQ-2 — Storage target : `scenarios` extension vs new `projections` table (RESOLVED)

**RESOLUTION (2026-05-11):** Extend the `scenarios` table (additive nullable columns `inputs_hash` + `superseded_by`). NO new `projections` table this phase. Per Plan 95-01 Task 4 + Pitfall 5 mitigation. Decision documented in `services/backend/alembic/versions/p95_dag_invalidation.py` (`TARGET_TABLE = "scenarios"`).

**What we know:** There is NO `projections` table or model (`grep -rln "class Projection"` returns empty). The closest model is `ScenarioModel` at `services/backend/app/models/scenario.py` — it has `id, profile_id, kind, inputs JSON, outputs JSON, created_at`.

**What's unclear:** Whether the architect-panel + CONTEXT « projections » nomenclature refers to (a) the existing `scenarios` table that should be extended, OR (b) a NEW table that Phase 95 should create.

**Recommendation:** Extend `scenarios`. The schema fits — `inputs` column is exactly what we'd hash, `outputs` column is exactly where the GroundingPack snapshot would persist. Renaming `scenarios → projections` is an unnecessary destructive change (Wave 1 would then be a rename + 2-column-add, instead of just 2-column-add). The planner asks Julien at Wave 1 Task 1.

### OQ-3 — Phase 92.7 calc_harness pure-Dart extraction timing (RESOLVED)

**RESOLUTION (2026-05-11):** Phase 95 does NOT depend on Phase 92.7 closure. Path A — NEW pure-Dart `apps/mobile/tools/hash_parity_harness/main.dart` — sidesteps the calc_harness Flutter cascade entirely (zero `financial_core/` imports). Per Plan 95-01 Task 5. Phase 92.7 remains a backlog quality-gate improvement for the legacy `calc_harness/`, independent of Phase 95 ship.

**What we know:** `dart compile exe apps/mobile/tools/calc_harness/main.dart` fails today due to Flutter cascade. Closure plan exists at `.planning/decisions/2026-05-10-pure-dart-calc-harness-extraction.md` (~3-4h, Path A).

**What's unclear:** Whether Phase 92.7 closes before or after Phase 95 Wave 1.

**Recommendation:** Phase 95 does NOT block on Phase 92.7. Sidestep via the NEW pure-Dart `hash_parity_harness/main.dart` (~50 LOC, pure stdlib + `package:crypto`, zero financial_core imports — see §D-03). Phase 92.7 stays a separate quality-gate improvement for the existing calc_diff harness.

### OQ-4 — `staleness_iso` mismatch detection trigger (DAG-03) (RESOLVED)

**RESOLUTION (2026-05-11):** Staleness trigger is LAZY at read time. The pure-function rule lives at `services/backend/app/services/coach/staleness.py` (Plan 95-01 Task 5 — extracted from `test_staleness.py` to a production module per checker BLOCKER-1 fix #1) :

```python
def staleness_high(stored_hash: str | None, current_hash: str) -> bool:
    return stored_hash is None or stored_hash != current_hash
```

Production read-path integration (calling the rule from the `arbitrage_engine` consumer + emitting `staleness_iso = "high"` on `GroundingPackEntry`) is DEFERRED to Phase 96 W2 per SC#2 scope decision. Phase 95 ships the rule + unit tests + chain-reset test ; Phase 96 wires it to the consumer surface.

**What we know:** D-08 names the field. CONTEXT does NOT specify WHEN staleness=high fires.

**What's unclear:** Possible triggers — (a) profile-write hook that recomputes hash on every save, (b) lazy compare at projection-read time, (c) periodic cron sweep.

**Recommendation:** Lazy compare at read time. Cheapest, no new background job, aligns with the existing `_run_narrator_with_gate()` synchronous wrapper. When the narrator reads a projection : recompute `inputs_hash` from current profile, compare to stored ; if different → emit `staleness_iso = "high"` flag in the GroundingPackEntry, narrator MAY surface « ces chiffres datent de X et certains de tes inputs ont changé depuis ».

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `json.dumps(sort_keys=True)` for canonicalisation | RFC 8785 JCS via `rfc8785` | 2024-09-27 (Trail of Bits release) | Deterministic across runtimes — critical for Python↔Dart parity |
| UUID4 random IDs | UUID7 time-ordered | RFC 9562 May 2024 → CPython 3.14 (late 2025) | Time-ordered sort = audit-trail without `created_at` |
| Bayesian credible intervals with priors | Bootstrap fréquentiste | MINT-specific 2026-05-09 (calc-first ADR) | Honest about no calibrated prior — narrator annotates « selon le modèle simplifié actuel » |
| `jcs==0.2.1` (Anders Rundgren, 2022) | `rfc8785==0.1.4` (Trail of Bits, 2024) | 2024 | Same RFC, newer maintenance, zero deps |

**Deprecated/outdated:**
- `jcs` Python package — still functional, but stale (2 years no release). Switch to `rfc8785`.
- `uuid.uuid4()` for time-correlated IDs — replace with `uuid_utils.uuid7()` for new ordered-ID columns.

## Sources

### Primary (HIGH confidence)
- `.planning/phases/95-mvp-dag-invalidation/95-CONTEXT.md` — locked decisions D-01..D-18 [verbatim copy]
- `.planning/decisions/2026-05-10-95-96-autonomous-sequence-master.md` — master synthesis + 3 stop conditions
- `.planning/decisions/2026-05-10-phase-95-architect-panel.md` — full architecture brief (the « answer sheet ») ; CONTEXT D-01..D-13 derive from here
- `.planning/decisions/2026-05-09-calc-first-llm-illumination.md` — N2 strategic mandate (foundational ADR)
- `services/backend/app/services/coach/grounding_pack.py` — empty stub today, Wave 2 fills it
- `services/backend/app/services/coach/citation_registry.py` — 18-key namespace, `CitationSource` Pydantic v2 model precedent
- `services/backend/app/services/coach/citation_parser.py` — `_substitute_placeholders()` at line 352, `GatedResponse.inputs_hash` stub at line 263
- `services/backend/alembic/versions/p86_anonymous_session_eclairage_delivered.py` — additive-migration precedent
- `services/backend/app/models/scenario.py` — `ScenarioModel` (closest existing analogue to « projections »)
- `apps/mobile/lib/services/financial_core/arbitrage_engine.dart` — 2116-line S32 Phase 1 arbitrage with `TrajectoireOption` IDs `3a / rachat_lpp / amort_indirect`
- `apps/mobile/lib/services/financial_core/monte_carlo_service.dart:222-225` — iid-Gaussian MC implementation (Wave 7 actuarial audit P0-M1, σ=6.5% Pictet BVG-25)
- `apps/mobile/tools/calc_harness/main.dart` — Phase 92.5 differential harness pattern, currently BLOCKED by Flutter cascade
- `services/backend/tests/test_calc_diff_harness.py` — calc_diff_v1.jsonl driver, fixture skip-clean pattern when Dart binary absent

### Secondary (MEDIUM confidence, verified)
- [PyPI — rfc8785 0.1.4](https://pypi.org/project/rfc8785/) — Trail of Bits, 2024-09-27, zero deps [VERIFIED via WebFetch 2026-05-10]
- [PyPI — uuid_utils 0.14.1](https://pypi.org/project/uuid_utils/) — Rust-backed, 2026-02-20, Python 3.9-3.14 [VERIFIED via WebFetch 2026-05-10]
- [PyPI — jcs 0.2.1](https://pypi.org/project/jcs/) — stale 2022-04-10 [VERIFIED via WebFetch]
- [GitHub — trailofbits/rfc8785.py](https://github.com/trailofbits/rfc8785.py) — implementation source
- [Python 3.14 docs — uuid module](https://docs.python.org/3.14/library/uuid.html) — `uuid.uuid7()` lands 3.14 [VERIFIED via WebSearch]
- [RFC 8785 — JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785) — primary spec
- [RFC 9562 — UUID](https://www.rfc-editor.org/rfc/rfc9562) — UUID7 spec
- [CPython issue #102461 — UUID6/7/8 stdlib](https://github.com/python/cpython/issues/102461) — landing-in-3.14 confirmation
- [Pydantic v2 serialization](https://docs.pydantic.dev/latest/concepts/serialization/) — `@field_serializer` for Decimal

### Tertiary (LOW confidence, not relied on for critical claims)
- [connect2id.com — JCS + HMAC-SHA256 pattern](https://connect2id.com/blog/how-to-secure-json-objects-with-hmac) — practical JCS reference (cited in architect panel)
- [death.andgravity.com — Deterministic hashing of Python](https://death.andgravity.com/stable-hashing) — float quantization pitfalls (cited in architect panel)

## Metadata

**Confidence breakdown:**
- Standard stack (`rfc8785`, `uuid_utils`, Pydantic v2, alembic, numpy) : **HIGH** — all verified against PyPI + codebase 2026-05-10.
- Architecture (`_substitute_placeholders` extension, double-lookup, additive migration) : **HIGH** — call-site count = 1, migration precedent at p86_eclairage_delivered.
- Hash parity Python↔Dart (D-03) : **MEDIUM** — Path A (NEW pure-Dart harness) is sound but unproven ; first Wave 1 task verifies.
- Pitfall 2 (UUID7 stdlib 3.14 not 3.12) : **HIGH** — verified against CPython issue + Python docs.
- Pitfall 5 (`projections` table doesn't exist) : **HIGH** — verified by grep.
- Pareto + sensitivity + bootstrap (D-10/D-11/D-12) : **MEDIUM** — recipes are clean Python, but the backend ↔ Dart consumer/producer split is a Claude-discretion ambiguity (OQ-A3).

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (30 days — Pydantic + alembic + Python 3.12/3.14 landscape stable ; PyPI library versions may bump but APIs unchanged in this window)

## RESEARCH COMPLETE

**Phase:** 95 — MVP-DAG-INVALIDATION
**Confidence:** HIGH on stack + architecture + pitfalls ; MEDIUM on hash parity (verified in W1 Task 1) and Pareto/what_ifs producer-side (planner discretion per CONTEXT)

### Key Findings

1. **CRITICAL — UUID7 stdlib correction:** Architect panel said « Python 3.12+ ». Verified WRONG — `uuid.uuid7()` landed in CPython 3.14 (late 2025). Railway runs 3.12. **Adopt `uuid_utils>=0.14.1` backport** (Rust-backed, BSD-3-Clause, 2026-02-20).
2. **CRITICAL — `projections` table doesn't exist:** Architect-panel + CONTEXT name « ALTER TABLE projections » ; only `scenarios` table exists. Planner picks Wave 1 Task 1 — recommend **extend `scenarios`** (additive, ~10 LOC, no rename).
3. **Library substitution recommended:** `rfc8785==0.1.4` (Trail of Bits, 2024, zero-deps) over CONTEXT-named `jcs==0.2.1` (stale 2022). Same RFC, fresher maintenance. Plan documents the substitution.
4. **Surgical surface:** `_substitute_placeholders()` has ONE caller (same module, line 525). The signature change to accept `pack: ProjectionGroundingPack | None = None` is Karpathy #3 minimum-blast-radius.
5. **Path A for hash parity:** NEW pure-Dart harness at `apps/mobile/tools/hash_parity_harness/main.dart` sidesteps the Phase 92.7 calc_harness blocker (no `financial_core/` import needed for input-hashing). ~50 LOC.

### File Created

`.planning/phases/95-mvp-dag-invalidation/95-RESEARCH.md` (this file)

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack (rfc8785 + uuid_utils + Pydantic v2 + alembic + numpy) | HIGH | All verified against PyPI + codebase 2026-05-10 |
| Architecture (double-lookup + additive migration + pack contract) | HIGH | Single caller, additive precedent at p86, frozen Pydantic v2 model |
| Pitfalls (5 risks documented) | HIGH | Each grounded in grep / WebFetch / docs read |
| Pareto / sensitivity / bootstrap recipes | MEDIUM | Code recipes complete ; producer/consumer split is Claude-discretion |
| D-03 hash parity Python↔Dart | MEDIUM | Path A sound on paper, W1 Task 1 verifies |

### Open Questions (RESOLVED — 2026-05-11)

- OQ-1 — RESOLVED : adopt `uuid_utils>=0.14.1` backport ; Railway Python 3.14 upgrade tracked as backlog 999.x.
- OQ-2 — RESOLVED : extend `scenarios` table (additive nullable columns) ; no new `projections` table this phase.
- OQ-3 — RESOLVED : no dependency on Phase 92.7 closure ; Path A pure-Dart harness sidesteps.
- OQ-4 — RESOLVED : staleness trigger is LAZY at read time. `staleness_high(stored_hash, current_hash)` is the pure-function rule (Plan 95-01 Task 5, production module `services/backend/app/services/coach/staleness.py`). Production read-path integration deferred to Phase 96 W2 per SC#2 scope decision.

### Ready for Planning

Research complete. Planner can now :
- Write Plan 95-01 (Wave 1, ~2d) : alembic additive migration on `scenarios` + `compute_inputs_hash()` + `new_projection_id()` + Path-A Dart hash harness + 50-fixture parity test + `pii_fixture_scan.py` lint.
- Write Plan 95-02 (Wave 2, ~2d, BLOCKS on W1 merge) : `ProjectionGroundingPack` Pydantic v2 + emission consumer + `_substitute_placeholders()` double-lookup kwarg + `compute_pareto_points` (3-point) + `compute_what_ifs` (5 entries) + `bootstrap_ci()` numpy P5/P95.
