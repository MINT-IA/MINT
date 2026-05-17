---
phase: wave-1a
plan: 05
type: tdd
wave: 1
depends_on: [wave-1a-00]
files_modified:
  - services/backend/pyproject.toml
  - services/backend/app/services/memory/__init__.py
  - services/backend/app/services/memory/bm25.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_memory_bm25.py
  - services/backend/tests/test_coach_tools_retrieve_memories.py
autonomous: true
requirements: [WAVE1A-06, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Karpathy-wiki-pattern memory retrieval — BM25 over (CoachInsightRecord.topic + CoachInsightRecord.summary) for the user's rows, ProfileModel.data fallback when no insights row exists"
    - "NO vector embedding, NO LLM call (per memory project_user_profile_wiki — wiki, not RAG)"
    - "Score floor 0.3, top-k=5, results SQL-filtered WHERE user_id = ? so retrieval cannot leak across users"
    - "When COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED is OFF, dispatcher falls back to existing _handle_retrieve_memories(topic, memory_block, max_results, user_id, db) byte-identical legacy contract"
    - "Sentry breadcrumb coach.tool.retrieve_memories.invoked fires with D-15 5-kwarg payload (tool_name=retrieve_memories, inputs_hash, profile_id_hashed, elapsed_ms, flag_state); profile_id_hashed is hash_profile_id(user_id) — NEVER raw user_id"
  artifacts:
    - path: "services/backend/app/services/memory/bm25.py"
      provides: "retrieve(topic, user_id, db, k=5) -> list[InsightHit] using rank_bm25; _profile_fallback when CoachInsightRecord rows empty"
      contains: "def retrieve"
    - path: "services/backend/app/services/memory/__init__.py"
      provides: "Module init + re-export of retrieve + InsightHit (plan-00 left this as docstring marker — plan-05 fills it)"
      contains: "retrieve"
    - path: "services/backend/pyproject.toml"
      provides: "rank_bm25 dependency added to the project.dependencies list"
      contains: "rank_bm25"
    - path: "services/backend/tests/test_memory_bm25.py"
      provides: "≥10 unit tests covering BM25 ranking + score floor 0.3 + user_id SQL isolation + empty-corpus fallback + db None graceful"
      contains: "def test_"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_retrieve_memories sibling above _handle_retrieve_memories + flag-gated dispatcher branch (inside markers shipped by plan-00 at lines 1902-1916)"
      contains: "_compute_retrieve_memories"
  key_links:
    - from: "services/backend/app/services/memory/bm25.py"
      to: "services/backend/app/models/coach_insight.py"
      via: "CoachInsightRecord SQLAlchemy query filtered WHERE user_id = ?"
      pattern: "CoachInsightRecord"
    - from: "services/backend/app/services/memory/bm25.py"
      to: "services/backend/app/models/profile_model.py"
      via: "ProfileModel.data fallback when CoachInsightRecord query returns empty"
      pattern: "ProfileModel"
    - from: "services/backend/app/api/v1/endpoints/coach_chat.py"
      to: "services/backend/app/services/memory/bm25.py"
      via: "retrieve(topic, user_id, db, k=max_results) inside _compute_retrieve_memories"
      pattern: "from app.services.memory"
---

<objective>
Replace the inline `_handle_retrieve_memories(topic, memory_block, max_results, user_id, db)` dispatcher call with a flag-gated `_compute_retrieve_memories` that delegates to `app.services.memory.bm25.retrieve(topic, user_id, db, k)` backed by `rank_bm25.BM25Okapi`. Per CONTEXT D-07 + memory `project_user_profile_wiki` (Julien 2026-05-13): the user variable library is a Karpathy LLM Wiki, NOT vector-RAG. BM25 ranking over the user's `CoachInsightRecord` rows, score floor 0.3, top-k=5.

The legacy `_handle_retrieve_memories` (verified at `services/backend/app/api/v1/endpoints/coach_chat.py:910-1025`) already exists and stays UNCHANGED. The dispatcher (verified at `coach_chat.py:1902-1916`) currently calls it directly. Plan-05 inserts a `_compute_retrieve_memories` wrapper that checks the flag and either (a) calls `retrieve(...)` + formats the InsightHit list using the SAME line shape the legacy emits (`f"[{insight_type}] {topic}: {summary}"`) or (b) falls back to `_handle_retrieve_memories(...)`.

**Grep-verified 2026-05-14:** `CoachInsightRecord` columns are EXACTLY `id, user_id, topic, summary, insight_type, created_at, updated_at` (`services/backend/app/models/coach_insight.py:35-57`). There is NO `topic_tags` column and NO `body` column — CONTEXT D-07 mentions of those names are FABRICATIONS (resolved here by reading the actual model file). The BM25 corpus per-row therefore tokenizes `(topic + " " + summary)` only.

**Grep-verified 2026-05-14:** `ProfileModel` lives at `services/backend/app/models/profile_model.py` (NOT `profile.py`). The CONTEXT canonical-refs section listed `services/backend/app/models/profile.py` — the actual file path is `profile_model.py`. This plan uses the verified path.

Purpose: structural anti-hallucination for memory recall — eliminates the « LLM cites a memory that belongs to another user / a stale session » risk; gives plan-08 (close-out) a deterministic SQL-filtered surface to test.
Output: NEW `app.services.memory.bm25` module + ≥10 unit tests + ≥6 dispatcher tests + per-tool flag check (flag from plan-00).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-CONTEXT.md
@.planning/phases/wave-1a-backend-tools-refactor/wave-1a-RESEARCH.md
@services/backend/app/api/v1/endpoints/coach_chat.py
@services/backend/app/models/coach_insight.py
@services/backend/app/models/profile_model.py
@services/backend/app/services/coach/inputs_hash.py
@services/backend/pyproject.toml
@services/backend/tests/conftest.py
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. Every symbol below was grep-verified 2026-05-14. -->

== CoachInsightRecord schema (READ-ONLY — source of truth) ==

File `services/backend/app/models/coach_insight.py` lines 23-61:
```python
class CoachInsightRecord(Base):
    __tablename__ = "coach_insights"
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))             # line 37
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)                                     # line 38-43
    topic = Column(String, nullable=False)            # "revenu", "canton", "3a"     # line 44
    summary = Column(Text, nullable=False)            # "Salaire ~120k CHF/an"       # line 45
    insight_type = Column(String, nullable=False, default="fact")                    # line 46 ("fact"|"decision"|"preference")
    created_at = Column(DateTime, default=...)                                       # line 49
    updated_at = Column(DateTime, default=..., onupdate=...)                         # line 52
    __table_args__ = (Index("ix_coach_insights_user_topic", "user_id", "topic"),)   # line 60
```

**Confirmed columns:** `id`, `user_id`, `topic`, `summary`, `insight_type`, `created_at`, `updated_at`. No `topic_tags`, no `body`, no `tags`. The BM25 corpus reads `(row.topic, row.summary)`. There is an existing `(user_id, topic)` index — query plan stays efficient even with the WHERE user_id = ? filter.

== ProfileModel.data shape (READ-ONLY) ==

File `services/backend/app/models/profile_model.py` lines 31-43:
```python
class ProfileModel(Base):
    __tablename__ = "profiles"
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"),
                     index=True, nullable=True)
    data = Column(MutableDict.as_mutable(JSONEncodedDict), nullable=False)
    created_at = Column(DateTime, default=...)
    updated_at = Column(DateTime, default=..., onupdate=...)
```
`data` is a JSON dict (MutableDict). Wave 1a does NOT prescribe a specific key for fallback insights — the fallback path inspects `profile.data.get("recent_insights")` if present (defensive — graceful return of [] if absent). NO new schema introduced.

== Legacy handler (PRESERVE — flag OFF path delegates to it) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 910-1025: `_handle_retrieve_memories(topic, memory_block, max_results, user_id, db) -> str`. The relevant DB-side logic at lines 952-969:
```python
db_matches: list[str] = []
if user_id and db:
    try:
        from app.models.coach_insight import CoachInsightRecord
        insights = (
            db.query(CoachInsightRecord)
            .filter(CoachInsightRecord.user_id == user_id)
            .order_by(CoachInsightRecord.updated_at.desc())
            .limit(10)
            .all()
        )
        for ins in insights:
            if (topic_lower in (ins.topic or "").lower()
                    or topic_lower in (ins.summary or "").lower()):
                db_matches.append(f"[{ins.insight_type}] {ins.topic}: {ins.summary}")
    except Exception as exc:
        logger.warning("Could not search DB insights: %s", exc)
```
The legacy line format `f"[{insight_type}] {topic}: {summary}"` (line 967) is the FR-string contract Wave 1a must preserve byte-identically when the new BM25 path returns hits. Empty-corpus / no-match fallback strings (lines 947, 973, 1019) MUST also remain byte-identical — `_compute_retrieve_memories` delegates to `_handle_retrieve_memories(...)` in those cases.

== Existing dispatcher (REPLACE inside markers shipped by plan-00) ==

File `services/backend/app/api/v1/endpoints/coach_chat.py` lines 1902-1916 (verified 2026-05-14):
```python
    # >>> dispatch: retrieve_memories
    if name == "retrieve_memories":
        import re
        raw_topic = tool_input.get("topic", "")
        # BUG-B fix: sanitize topic to prevent prompt injection via LLM tool_use.
        # Only allow word chars, spaces, hyphens, dots (Unicode-aware).
        safe_topic = raw_topic if re.match(r'^[\w\s\-\.]{1,100}$', raw_topic, re.UNICODE) else ""
        return _handle_retrieve_memories(
            topic=safe_topic,
            memory_block=memory_block,
            max_results=min(tool_input.get("max_results", 3), 10),
            user_id=user_id,
            db=db,
        )
    # <<< dispatch: retrieve_memories
```

The replacement routes through `_compute_retrieve_memories` but preserves (a) the regex sanitization (BUG-B fix — protects against prompt-injection via tool_use), (b) the `max_results` clamp, (c) the `memory_block` passthrough (used by the legacy fallback path which scans the system-prompt-injected memory block in addition to the DB).

== rank_bm25 library ==

Package: `rank_bm25>=0.2.2,<1.0.0`. Pure-Python, NO native deps (Railway-compat).

API:
- `BM25Okapi(corpus: list[list[str]])` — fits index on a list of pre-tokenized documents.
- `bm25.get_scores(query: list[str]) -> np.ndarray` — returns a score vector (one per corpus document).

Implication: no numpy import needed at our level — `rank_bm25` already depends on numpy transitively; iterating via Python `enumerate()` works on the ndarray.

== Pre-existing scaffolding (DO NOT redeclare) ==

Confirmed 2026-05-14:
- `services/backend/app/core/config.py:101` — `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED: bool = False` (plan-00).
- `services/backend/app/services/memory/__init__.py` — empty package marker docstring-only (plan-00).
- `services/backend/app/observability/coach_breadcrumbs.py:26` — `def emit_coach_tool_breadcrumb(tool_name, inputs_hash, profile_id_hashed, elapsed_ms, flag_state)`.
- `services/backend/app/utils/hashing.py:12` — `def hash_profile_id(profile_id: str) -> str` (16-char hex).
- `services/backend/app/services/coach/inputs_hash.py:58` — `def compute_inputs_hash(inputs: dict) -> str` (64-char hex).
- `services/backend/app/api/v1/endpoints/coach_chat.py:1834` — dispatcher signature uses `user_id`, NOT `profile_id`.

== pyproject.toml dependency declaration shape ==

File `services/backend/pyproject.toml` lines 5-52. The dependency list lives in `dependencies = [...]` under `[project]`. Verified entries use the form `"<name>>=<min>,<<max>",`. The new line follows the same form — placed alphabetically after `pyyaml` and before `redis` (line 41-42 region).

== Plan-01/02 dispatcher pattern reference (post-rewrite, shipped) ==

`services/backend/app/api/v1/endpoints/coach_chat.py:2286-2388` (_compute_budget_status) and lines `2390-2470` (_compute_retirement_projection). Both follow the same shape: import-time check of settings flag, defensive user_id+db check, try/except broad-Exception fallback, D-15 5-kwarg breadcrumb. Plan-05 mirrors this with one specificity: the breadcrumb's `inputs_hash` is computed from the (topic, user_id, k) QUERY slice (not a profile slice) because retrieve_memories is a query, not a profile compute.

</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add rank_bm25 dependency + bm25.retrieve module + ≥10 RED-GREEN unit tests</name>
  <read_first>
    - services/backend/app/models/coach_insight.py (FULL 62 lines — confirm columns: id/user_id/topic/summary/insight_type/created_at/updated_at; NO topic_tags, NO body)
    - services/backend/app/models/profile_model.py (FULL 44 lines — confirm `data` JSON column path)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 910-1025 (legacy _handle_retrieve_memories body — preserved unchanged, contract reference)
    - services/backend/pyproject.toml lines 1-60 (confirm dependency block format and existing entries)
    - services/backend/tests/conftest.py lines 1-130 (confirm pytest DB session fixture: sqlite::memory:, TestingSessionLocal, autoflush=False, autouse cleanup fixture)
    - services/backend/app/services/coach/inputs_hash.py (compute_inputs_hash signature)
    - services/backend/app/services/memory/__init__.py (plan-00 marker — currently empty docstring-only)
  </read_first>
  <files>
    - services/backend/pyproject.toml (modify — add rank_bm25 dependency line)
    - services/backend/app/services/memory/__init__.py (modify — add re-exports)
    - services/backend/app/services/memory/bm25.py (create)
    - services/backend/tests/test_memory_bm25.py (create)
  </files>
  <behavior>
    Note: tests rely on the existing pytest DB session fixture from `services/backend/tests/conftest.py` (sqlite::memory:, TestingSessionLocal). Each test creates `CoachInsightRecord` rows via `db.add(...)` + `db.commit()` then queries `retrieve(topic, user_id, db, k)`.

    - Test 1 (HAPPY): user_a has 3 insights — `(topic="3a", summary="J'ai versé 5000 CHF en 3a")`, `(topic="lpp", summary="LPP avoir 95k")`, `(topic="3a", summary="Plafond 7258 CHF salarié")`. `retrieve("3a", "user_a", db, k=5)` returns ≥2 hits, all `hit.topic == "3a"`, top hit's `summary` contains "3a"-related token. Top hit's `score >= 0.3`.
    - Test 2 (EMPTY CORPUS → FALLBACK): no CoachInsightRecord rows for user_a; `profile.data = {"recent_insights": [{"topic": "3a", "summary": "Plafond 7258 CHF", "created_at": "2026-05-01"}]}`. `retrieve("3a", "user_a", db, k=5)` returns 1 hit with `score=1.0`.
    - Test 3 (USER ISOLATION): insert 1 insight for user_a (`topic="3a"`) and 1 for user_b (`topic="3a"`). `retrieve("3a", "user_a", db, k=5)` returns hits with `hit.user_id == "user_a"` for EVERY entry — none from user_b.
    - Test 4 (SCORE FLOOR): query `"totally_unrelated_xyz123"` against the 3 user_a insights from Test 1 → returns 0 hits.
    - Test 5 (TOP-K): insert 8 insights for user_a all containing "3a" in topic; `retrieve("3a", "user_a", db, k=5)` returns exactly 5 hits.
    - Test 6 (TOPIC + SUMMARY CORPUS): insight A = `(topic="3a", summary="random text")`, insight B = `(topic="generic", summary="3a 3a 3a")`. Query "3a" → both score >0 (proves corpus tokenizes BOTH columns).
    - Test 7 (CASE-INSENSITIVE): query "3A" (uppercase) matches insights with topic "3a" (proves `_tokenize` lowercases).
    - Test 8 (EMPTY TOPIC): `retrieve("", "user_a", db, k=5)` returns empty list.
    - Test 9 (DETERMINISM): calling `retrieve("3a", "user_a", db, 5)` twice returns identical lists.
    - Test 10 (db None → []): `retrieve("3a", "user_a", None, 5)` returns empty list.
    - Test 11 (user_id None → []): `retrieve("3a", None, db, 5)` returns empty list.
    - **Total: 11 tests (target ≥10 satisfied).**
  </behavior>
  <action>
    Step A — `services/backend/pyproject.toml`: insert `"rank_bm25>=0.2.2,<1.0.0",` in the `dependencies = [...]` block. Alphabetical placement: after `"pyyaml>=6.0,<7.0",` and before `"redis>=5.0,<6.0",`.

    After edit:
    ```bash
    grep -c '"rank_bm25' services/backend/pyproject.toml
    # Expected: 1
    cd services/backend && pip install -e .
    ```

    Step B — Modify `services/backend/app/services/memory/__init__.py` (plan-00 left it as a docstring marker — append the re-export):
    ```python
    """Wave 1a D-07 — Karpathy-wiki memory retrieval (per memory project_user_profile_wiki).

    Plan-00 shipped the empty marker; plan-05 fills it. The package is the
    deterministic SQL-filtered surface for BM25 retrieval over the user's
    CoachInsightRecord rows (no vector embedding, no LLM call).
    """
    from app.services.memory.bm25 import retrieve, InsightHit

    __all__ = ["retrieve", "InsightHit"]
    ```

    Step C — Create `services/backend/app/services/memory/bm25.py`:
    ```python
    """Wave 1a D-07 — BM25 ranking over CoachInsightRecord rows.

    Karpathy wiki (per Julien 2026-05-13, memory project_user_profile_wiki):
    « the user variable library is a Karpathy LLM Wiki, not vector-RAG.
    Per-user pages, BM25 lookup over (topic + summary), no vector
    embedding, no LLM call. »

    Schema (verified 2026-05-14 by reading services/backend/app/models/coach_insight.py):
      CoachInsightRecord columns: id, user_id, topic, summary, insight_type,
      created_at, updated_at. No topic_tags. No body. Corpus per row is
      tokenize(topic + " " + summary).

    Score floor: 0.3 (BM25Okapi default scale; tune in Wave 1c if recall insufficient).
    Top-k: 5 (matches legacy max_results=3..10 envelope at coach_chat.py:1912).
    User isolation: WHERE user_id = ? at the SQL layer — no cross-user
      leakage possible at this surface. Uses the existing
      (user_id, topic) composite index (coach_insight.py:60).
    """
    from __future__ import annotations
    from dataclasses import dataclass
    from typing import Optional

    from rank_bm25 import BM25Okapi

    _SCORE_FLOOR: float = 0.3
    _MAX_CORPUS_ROWS: int = 500
    _DEFAULT_K: int = 5


    @dataclass(frozen=True)
    class InsightHit:
        record_id: str
        user_id: str
        topic: str
        summary: str
        insight_type: str
        score: float


    def _tokenize(text: str) -> list[str]:
        """Lowercase + whitespace tokenization. No stemming (FR + EN mix)."""
        return text.lower().split()


    def retrieve(
        topic: str,
        user_id: Optional[str],
        db,
        k: int = _DEFAULT_K,
    ) -> list[InsightHit]:
        """Return top-k InsightHits for the user, BM25-ranked over their insights.

        Args:
            topic: free-text query. Empty string returns [].
            user_id: WHERE clause — cross-user isolation guarantee. None → [].
            db: SQLAlchemy session. None → [].
            k: max results. Hits below _SCORE_FLOOR (0.3) are dropped.

        Returns:
            list[InsightHit] ordered by BM25 score desc, score >= 0.3.
            Empty list if no insights match OR the user has no
            CoachInsightRecord rows AND no ProfileModel.data["recent_insights"].
        """
        if not topic or db is None or not user_id:
            return []
        from app.models.coach_insight import CoachInsightRecord

        rows = (
            db.query(CoachInsightRecord)
            .filter(CoachInsightRecord.user_id == user_id)
            .order_by(CoachInsightRecord.updated_at.desc())
            .limit(_MAX_CORPUS_ROWS)
            .all()
        )
        if not rows:
            return _profile_fallback(topic, user_id, db, k)

        corpus = [_tokenize(f"{(r.topic or '')} {(r.summary or '')}") for r in rows]
        if not any(corpus):
            return []
        bm25 = BM25Okapi(corpus)
        scores = bm25.get_scores(_tokenize(topic))
        paired = list(zip(rows, scores))
        paired.sort(key=lambda x: x[1], reverse=True)
        hits: list[InsightHit] = []
        for r, s in paired[:k]:
            score = float(s)
            if score < _SCORE_FLOOR:
                continue
            hits.append(InsightHit(
                record_id=r.id,
                user_id=r.user_id,
                topic=r.topic,
                summary=r.summary,
                insight_type=r.insight_type,
                score=score,
            ))
        return hits


    def _profile_fallback(topic: str, user_id: str, db, k: int) -> list[InsightHit]:
        """Fallback: scan ProfileModel.data['recent_insights'] for topic match.

        ProfileModel.data is a JSON dict (services/backend/app/models/profile_model.py).
        Wave 1a does NOT mandate the 'recent_insights' key — if absent, return [].
        Score=1.0 for exact topic-substring matches (bypass BM25 entirely).
        """
        from app.models.profile_model import ProfileModel
        profile = (
            db.query(ProfileModel)
            .filter(ProfileModel.user_id == user_id)
            .order_by(ProfileModel.updated_at.desc())
            .first()
        )
        if profile is None or not profile.data:
            return []
        recent = profile.data.get("recent_insights") or []
        if not isinstance(recent, list):
            return []
        topic_tokens = set(_tokenize(topic))
        hits: list[InsightHit] = []
        for entry in recent:
            if not isinstance(entry, dict):
                continue
            entry_topic = (entry.get("topic") or "").lower()
            if any(t in entry_topic for t in topic_tokens):
                hits.append(InsightHit(
                    record_id=f"profile_recent_{entry.get('created_at', '')}",
                    user_id=user_id,
                    topic=entry.get("topic", ""),
                    summary=entry.get("summary", ""),
                    insight_type=entry.get("insight_type", "fact"),
                    score=1.0,
                ))
                if len(hits) >= k:
                    break
        return hits
    ```

    Step D — Flag verification (READ-ONLY — plan-00 owns the flag):
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```
    If 0, FAIL — plan-00 has not landed. Do NOT add the flag here.

    Step E — Create `services/backend/tests/test_memory_bm25.py` with the 11 tests from `<behavior>`. Use the existing autouse cleanup fixture from `conftest.py:70-124`. Insert rows via `db.add(CoachInsightRecord(user_id=..., topic=..., summary=..., insight_type="fact"))` + `db.commit()`. For Test 2 (fallback), insert a `ProfileModel(user_id="user_a", data={"recent_insights": [{...}]})`.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; pip install -e . &amp;&amp; python3 -m pytest tests/test_memory_bm25.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c '"rank_bm25' services/backend/pyproject.toml` returns exactly 1.
    - `python3 -c "from app.services.memory import retrieve, InsightHit; print('ok')"` exits 0.
    - `python3 -c "from app.services.memory.bm25 import retrieve, _SCORE_FLOOR; assert _SCORE_FLOOR == 0.3"` exits 0.
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/core/config.py` returns ≥1 (plan-00 invariant).
    - `grep -E "filter\(CoachInsightRecord\.user_id == user_id\)" services/backend/app/services/memory/bm25.py` returns ≥1 (SQL-layer user isolation explicit).
    - `grep -c "topic_tags\|\.body\b" services/backend/app/services/memory/bm25.py` returns 0 (anti-fabrication grep — those columns do NOT exist in the schema).
    - `grep -c "BM25Okapi" services/backend/app/services/memory/bm25.py` returns ≥1.
    - `grep -E "(r\.topic|r\.summary)" services/backend/app/services/memory/bm25.py` returns ≥2 (proves corpus reads the REAL columns).
    - `pytest services/backend/tests/test_memory_bm25.py -q` exits 0 with ≥10 tests collected (plan ships 11).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/memory/bm25.py` exits 0.
  </acceptance_criteria>
  <done>
    rank_bm25 installed; module + ≥11 tests green; user isolation enforced at SQL layer (grep proof); corpus reads actual columns `topic` + `summary` (no fabricated `topic_tags` / `body`).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_retrieve_memories + dispatcher branch (markers preserved) + ≥6 dispatcher tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1902-1916 (dispatcher marker pair from plan-00 — REPLACE branch body, preserve markers)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 910-1025 (legacy _handle_retrieve_memories — preserved unchanged; its line shape is the FR contract)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2286-2388 (shipped _compute_budget_status pattern reference)
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 2390-2470 (shipped _compute_retirement_projection — same pattern)
    - services/backend/app/services/memory/bm25.py (just created in Task 1)
    - services/backend/app/observability/coach_breadcrumbs.py (emit_coach_tool_breadcrumb 5-kwarg signature — locked by plan-00 Test 14)
    - services/backend/app/services/coach/inputs_hash.py (compute_inputs_hash)
    - services/backend/app/utils/hashing.py (hash_profile_id)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify — insert _compute_retrieve_memories above _handle_retrieve_memories; replace dispatcher branch body inside markers)
    - services/backend/tests/test_coach_tools_retrieve_memories.py (create)
  </files>
  <behavior>
    - Test 1 (FLAG OFF passthrough): `monkeypatch.setattr(settings, "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED", False)`; call `_compute_retrieve_memories(topic="3a", user_id="u", db=db, max_results=3, memory_block="some block")` → output byte-identical to `_handle_retrieve_memories(topic="3a", memory_block="some block", max_results=3, user_id="u", db=db)`.
    - Test 2 (FLAG ON + hits): flag ON, insert 1 CoachInsightRecord for user_a `(topic="3a", summary="Plafond 7258 CHF salarié", insight_type="fact")`. Call `_compute_retrieve_memories("3a", "user_a", db, 3, None)` → output contains SUBSTRING `[fact] 3a: Plafond 7258 CHF salarié` (BYTE-IDENTICAL legacy line format).
    - Test 3 (FLAG ON + no BM25 hits + no profile fallback): flag ON, empty CoachInsightRecord table, no ProfileModel → output is byte-identical to the legacy fallback string emitted by `_handle_retrieve_memories` given the same (no rows, no memory_block) inputs.
    - Test 4 (BM25 score floor reject): flag ON, insert 1 CoachInsightRecord with completely unrelated content. Query "totally_unrelated_xyz" → bm25 returns no hits → `_compute_retrieve_memories` falls back to `_handle_retrieve_memories` and returns the legacy fallback string.
    - Test 5 (CROSS-USER ISOLATION): flag ON, insert 1 insight for user_a (`topic="3a"`) and 1 for user_b (`topic="3a"`). Call `_compute_retrieve_memories("3a", "user_b", db, 3, None)`. Output contains user_b's summary, MUST NOT contain user_a's summary (substring check).
    - Test 6 (D-15 BREADCRUMB): flag ON, hits returned. Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` and assert called once with EXACT kwargs `tool_name="retrieve_memories"`, `inputs_hash` is 64-char hex, `profile_id_hashed` is 16-char hex AND `profile_id_hashed != user_id` (proves hash applied), `elapsed_ms` is int ≥0, `flag_state="on"`.
    - Test 7 (db None passthrough): flag ON, `db=None` → falls back to `_handle_retrieve_memories(... db=None)`. No exception.
    - **Total: 7 tests (target ≥6 satisfied).**
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, INSERT `_compute_retrieve_memories` ABOVE the existing `_handle_retrieve_memories` function (at approximately line 909 — just before `_handle_retrieve_memories`):

    ```python
    def _compute_retrieve_memories(
        topic: str,
        user_id: Optional[str],
        db: Optional[Session],
        max_results: int,
        memory_block: Optional[str],
    ) -> str:
        """Wave 1a D-07 server-side path for retrieve_memories.

        Routes through `app.services.memory.bm25.retrieve` when flag ON; falls
        back to legacy `_handle_retrieve_memories` when:
          - settings flag is OFF, OR
          - user_id is None / db is None, OR
          - BM25 retrieve returns 0 hits, OR
          - retrieve raises ANY Exception (defensive — user-facing text never
            breaks the coach loop).

        Output shape: when flag ON + hits found, returns a newline-joined
        FR string of `[insight_type] topic: summary` lines (byte-identical
        to the legacy line format at coach_chat.py:967), truncated to
        max_results.
        """
        import time
        import logging
        from app.core.config import settings

        if not settings.COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED:
            return _handle_retrieve_memories(
                topic=topic, memory_block=memory_block,
                max_results=max_results, user_id=user_id, db=db,
            )
        if not user_id or db is None:
            return _handle_retrieve_memories(
                topic=topic, memory_block=memory_block,
                max_results=max_results, user_id=user_id, db=db,
            )

        _t0 = time.perf_counter()
        try:
            from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
            from app.services.coach.inputs_hash import compute_inputs_hash
            from app.services.memory.bm25 import retrieve as _bm25_retrieve
            from app.utils.hashing import hash_profile_id

            k = min(max(1, max_results), 5)
            hits = _bm25_retrieve(topic=topic, user_id=user_id, db=db, k=k)
            if not hits:
                return _handle_retrieve_memories(
                    topic=topic, memory_block=memory_block,
                    max_results=max_results, user_id=user_id, db=db,
                )

            lines = [
                f"[{h.insight_type}] {h.topic}: {h.summary}"
                for h in hits
            ]
            result_text = "\n".join(lines[:max_results])

            elapsed_ms = int((time.perf_counter() - _t0) * 1000)
            query_slice = {"topic": topic, "user_id": user_id, "k": k}
            emit_coach_tool_breadcrumb(
                tool_name="retrieve_memories",
                inputs_hash=compute_inputs_hash(query_slice),
                profile_id_hashed=hash_profile_id(user_id),
                elapsed_ms=elapsed_ms,
                flag_state="on",
            )
            return result_text
        except Exception as exc:
            logging.getLogger(__name__).warning(
                "compute_retrieve_memories failed, falling back to legacy: %s", exc
            )
            return _handle_retrieve_memories(
                topic=topic, memory_block=memory_block,
                max_results=max_results, user_id=user_id, db=db,
            )
    ```

    Notes:
    - Place ABOVE `_handle_retrieve_memories` (the forward-reference is intentional — Python resolves at call time).
    - `Optional[Session]` uses the existing `from sqlalchemy.orm import Session` import. No new top-of-file imports required.

    Step B — Replace the dispatcher branch body INSIDE the marker pair shipped by plan-00 (lines 1902-1916). Locate the EXACT block and replace WITH (markers preserved, BUG-B regex preserved, only call target changes):
    ```python
        # >>> dispatch: retrieve_memories
        if name == "retrieve_memories":
            import re
            raw_topic = tool_input.get("topic", "")
            # BUG-B fix: sanitize topic to prevent prompt injection via LLM tool_use.
            # Only allow word chars, spaces, hyphens, dots (Unicode-aware).
            safe_topic = raw_topic if re.match(r'^[\w\s\-\.]{1,100}$', raw_topic, re.UNICODE) else ""
            return _compute_retrieve_memories(
                topic=safe_topic,
                user_id=user_id,
                db=db,
                max_results=min(tool_input.get("max_results", 3), 10),
                memory_block=memory_block,
            )
        # <<< dispatch: retrieve_memories
    ```
    Acceptance after edit: `grep -c "# >>> dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1 AND `grep -c "# <<< dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1. The BUG-B comment MUST remain.

    Step C — Create `services/backend/tests/test_coach_tools_retrieve_memories.py` with Tests 1-7. Use `monkeypatch.setattr(settings, ...)`. Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` for Test 6.

    Step D — Sentry payload non-PII assertion (Test 6 detail):
    ```python
    call_kwargs = mock_breadcrumb.call_args.kwargs
    assert call_kwargs["tool_name"] == "retrieve_memories"
    assert len(call_kwargs["inputs_hash"]) == 64
    assert len(call_kwargs["profile_id_hashed"]) == 16
    assert call_kwargs["profile_id_hashed"] != "user_a"  # proves hash applied
    assert isinstance(call_kwargs["elapsed_ms"], int)
    assert call_kwargs["elapsed_ms"] >= 0
    assert call_kwargs["flag_state"] == "on"
    assert set(call_kwargs.keys()) == {"tool_name", "inputs_hash", "profile_id_hashed", "elapsed_ms", "flag_state"}
    ```
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_memory_bm25.py tests/test_coach_tools_retrieve_memories.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/memory/bm25.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def _compute_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -c "_compute_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (def + dispatcher call + at least one self-reference in comments/docstring).
    - `grep -c "_handle_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥5 (legacy def + 4 fallback calls from _compute_retrieve_memories).
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_memory_bm25.py tests/test_coach_tools_retrieve_memories.py -q` exits 0 with ≥17 total tests (11 BM25 + 7 dispatcher = 18).
    - `grep "tool_name=\"retrieve_memories\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep "hash_profile_id(user_id)" services/backend/app/api/v1/endpoints/coach_chat.py` count strictly increases vs the pre-plan-05 baseline (user_id is hashed through the D-15 helper, NOT raw).
    - `grep -c "# >>> dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -c "# <<< dispatch: retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns exactly 1.
    - `grep -c "BUG-B fix" services/backend/app/api/v1/endpoints/coach_chat.py` count unchanged (regex sanitization preserved).
    - `grep "user_id == \"user_a\"\|user_b" services/backend/tests/test_coach_tools_retrieve_memories.py` returns ≥1 (cross-user isolation test present).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py services/backend/app/api/v1/endpoints/coach_chat.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/memory/bm25.py` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through BM25 wrapper when flag ON; ≥18 tests green (11 BM25 + 7 dispatcher); cross-user isolation enforced (SQL filter + test); Sentry payload non-PII per D-15 (16-char hashed user_id, 64-char inputs_hash, 5-kwarg lock); BUG-B sanitization preserved.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Coach LLM → retrieve_memories tool input | LLM-emitted `topic` field is untrusted; pre-existing BUG-B regex sanitization at dispatcher entry (coach_chat.py:1908) blocks SQL-meaningful characters BEFORE reaching `_compute_retrieve_memories`. |
| `_compute_retrieve_memories` → DB | user_id passed to WHERE clause is from authenticated session (not LLM); SQLAlchemy parameterized query — no injection surface even if regex had been bypassed. |
| BM25 corpus → returned hits | Corpus content is the user's own CoachInsightRecord rows; no cross-tenant leakage possible at the SQL layer. |
| Sentry breadcrumb → external Sentry project | Outbound telemetry; D-15 payload non-PII by construction (hashes + scalar elapsed + literal flag_state). |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-05-01 | T (Tampering) | Legacy `_handle_retrieve_memories` regression when flag OFF | mitigate | Test 1 asserts byte-identity passthrough. |
| T-WAVE1A-05-02 | I (Information disclosure) | LSFin banned-terms leak in formatter output | mitigate | `_compute_retrieve_memories` emits ONLY `f"[{insight_type}] {topic}: {summary}"` (lines come from the user's own insights, content user-generated) + falls back to legacy when no hits — same FR-string surface; `banned_terms_python.py` enforces no new LSFin claims introduced by the wrapper code. |
| T-WAVE1A-05-03 | I | PII leak in Sentry breadcrumb (raw user_id, raw summary) | mitigate | Payload locked to D-15 5-kwarg contract: `profile_id_hashed = hashlib.sha256(user_id)[:16]` (irreversible), `inputs_hash` = SHA-256 of (topic, user_id, k) query slice, `elapsed_ms` scalar, `flag_state` Literal, `tool_name` literal string. NO `summary` text in payload. Test 6 inspects call kwargs and asserts non-raw user_id. |
| T-WAVE1A-05-04 | I (BM25-specific) | retrieve_memories returns insights from wrong user_id | mitigate | SQL filter `WHERE user_id = ?` at the query layer (NOT post-filter); BM25Okapi runs over already-filtered rows so cross-user contamination is structurally impossible. Test 3 (BM25 unit) + Test 5 (dispatcher) both assert isolation with 2-user fixtures. |
| T-WAVE1A-05-05 | E (Elevation of privilege) | adversarial topic injection (e.g. `"' OR 1=1; --"`) | mitigate | The pre-existing dispatcher regex `^[\w\s\-\.]{1,100}$` (preserved at coach_chat.py:1908) blocks SQL-meaningful characters BEFORE the topic reaches BM25 tokenization. Additionally, SQLAlchemy parameterized queries throughout — `WHERE user_id = ?` does not interpolate the topic string. |
| T-WAVE1A-05-06 | D (Denial of service) | adversarial topic with 1000-token query → BM25 OOM | mitigate | `_MAX_CORPUS_ROWS = 500` bounds the corpus size; tokenization is O(n) on topic length (≤100 chars after regex sanitize at dispatcher); BM25Okapi memory is O(corpus × vocab) which is bounded. Low risk for Wave 1a scale. |
| T-WAVE1A-05-07 | T | rank_bm25 dependency installs fails on Railway base image | mitigate | rank_bm25 is pure-Python with numpy as its only dep — numpy is already transitively present (via sentry-sdk[fastapi] / fastapi). Pre-execution `pip install -e .` in Task 1 verify command exercises this on the local dev box before any PR. |
</threat_model>

<verification>
- `pytest services/backend/tests/test_memory_bm25.py tests/test_coach_tools_retrieve_memories.py -q` exits 0 with ≥17 tests collected.
- `pytest services/backend/ -q` full suite — zero regressions (target ≥6567 baseline + 18 = ≥6585).
- `python3 tools/checks/banned_terms_python.py` green on all touched files.
- `python3 tools/checks/accent_lint_fr.py` green on bm25.py (FR docstring accents preserved).
- `rank_bm25` dependency installs cleanly on local dev (proxy for Railway CI).
- Anti-fabrication grep: `topic_tags` and `.body` references zero in `bm25.py` (proves the port uses the REAL schema, not the fabricated columns from CONTEXT D-07).
- Cross-user isolation: explicit `filter(CoachInsightRecord.user_id == user_id)` present (grep proof) AND tested with 2-user fixture (Task 1 Test 3 + Task 2 Test 5).
- D-15 5-kwarg contract: Test 6 asserts the exact kwarg set on the mocked breadcrumb.
- BUG-B sanitization regex preserved in dispatcher (grep count unchanged).
</verification>

<success_criteria>
- WAVE1A-06 satisfied: formal `app.services.memory.bm25.retrieve` exists, BM25-based, NO vector embedding, NO LLM call, score floor 0.3, top-k=5.
- WAVE1A-09 satisfied: dispatcher emits structured InsightHit list serialized via the legacy line format (byte-identical FR strings — line-format contract preserved).
- WAVE1A-10 satisfied: dispatcher reads `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED` flag from plan-00 scaffolding; OFF default → byte-identical legacy fallback.
- ≥18 new backend tests (11 BM25 unit + 7 dispatcher), lints green.
- 0 cross-user leak — SQL-filter assertion present, tested with 2-user fixture, no post-filter band-aid.
- Anti-fabrication: zero references to non-existent columns `topic_tags` / `body` (grep proof in acceptance criteria).
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-05-SUMMARY.md` with:
- Files created (paths + line counts).
- 18+ tests collected + passed (paste pytest tail).
- accent_lint_fr.py + banned_terms_python.py green outputs.
- Anti-fabrication grep proof: zero `topic_tags` / `.body` references in bm25.py (paste grep output showing 0).
- BM25 ranking sanity check: top-1 score for "3a" query on a Julien-shaped fixture cited.
- Cross-user isolation proof: paste Test 3 (unit) + Test 5 (dispatcher) outputs.
- D-15 5-kwarg breadcrumb contract proof: paste Test 6 captured kwargs.
- BUG-B sanitization preservation proof: paste `grep -c "BUG-B fix" coach_chat.py` showing the count is unchanged from pre-plan-05.
- 0-trust §9 self-check section citing every command output verbatim (G3 pytest exit 0 + G4 regression count baseline+N + G5 lints exit 0).
</output>
