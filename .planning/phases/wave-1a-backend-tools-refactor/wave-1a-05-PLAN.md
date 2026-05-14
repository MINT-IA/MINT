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
autonomous: true
requirements: [WAVE1A-06, WAVE1A-09, WAVE1A-10]
must_haves:
  truths:
    - "Karpathy-wiki-pattern memory retrieval — BM25 over (insight.summary + insight.topic) for the user's CoachInsightRecord rows + ProfileModel.data fallback"
    - "NO vector embedding, NO LLM call (per memory project_user_profile_wiki — wiki, not RAG)"
    - "Score floor 0.3, top-k=5, results SQL-filtered WHERE user_id = ? so retrieval cannot leak across users"
    - "When flag OFF, dispatcher falls back to existing _handle_retrieve_memories(topic, memory_block, user_id, db) — byte-identical legacy contract"
  artifacts:
    - path: "services/backend/app/services/memory/bm25.py"
      provides: "retrieve(topic, user_id, db, k=5) -> list[InsightHit] using rank_bm25"
      contains: "def retrieve"
    - path: "services/backend/app/services/memory/__init__.py"
      provides: "Module init + re-export"
      contains: "retrieve"
    - path: "services/backend/pyproject.toml"
      provides: "rank_bm25 dependency added"
      contains: "rank_bm25"
    - path: "services/backend/tests/test_memory_bm25.py"
      provides: "≥10 unit tests covering BM25 ranking + score floor + user_id isolation + empty corpus fallback"
      contains: "def test_"
    - path: "services/backend/app/api/v1/endpoints/coach_chat.py"
      provides: "_compute_retrieve_memories sibling + flag-gated dispatcher branch"
      contains: "_compute_retrieve_memories"
    - path: "services/backend/app/core/config.py"
      provides: "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED setting"
      contains: "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED"
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
      via: "retrieve(topic, user_id, db, k=5) inside _compute_retrieve_memories"
      pattern: "from app.services.memory"
---

<objective>
Replace the inline `_handle_retrieve_memories(topic, memory_block, max_results, user_id, db)` legacy handler with a formal `app.services.memory.bm25.retrieve(topic, user_id, db, k=5)` wrapper backed by `rank_bm25.BM25Okapi`. Per CONTEXT D-07 + memory `project_user_profile_wiki` (Julien 2026-05-13): the user variable library is a Karpathy LLM Wiki, NOT vector-RAG. BM25 ranking over `(CoachInsightRecord.summary + topic_tags)` per user, score floor 0.3, top-k=5.

The retrieved insights serve as the LLM's recall surface when the `retrieve_memories` tool is invoked. Wave 1a moves this from `memory_block` (a fuzzy argument passed in by the caller) to a SQL-filtered DB read that cannot leak across users.

Purpose: structural anti-hallucination for memory recall — eliminates the « LLM cites a memory that belongs to another user / a stale session » risk; gives plan-08 (close-out) a deterministic surface to test.
Output: NEW Python service `app.services.memory` + ≥10 unit tests + dispatcher path + flag.
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
@CLAUDE.md

<interfaces>
<!-- Contracts the executor MUST follow. -->

CoachInsightRecord schema (read-only — source: services/backend/app/models/coach_insight.py):
```python
class CoachInsightRecord(Base):
    __tablename__ = "coach_insights"
    id = Column(String, primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    topic = Column(String, nullable=False)
    summary = Column(Text, nullable=False)
    insight_type = Column(String, nullable=False, default="fact")
    created_at = Column(DateTime, ...)
    updated_at = Column(DateTime, ...)
```

Legacy handler (PRESERVE — Wave 1a does NOT delete it, the dispatcher's `_compute_retrieve_memories` falls back to it when flag OFF):
File services/backend/app/api/v1/endpoints/coach_chat.py — `_handle_retrieve_memories(topic, memory_block, max_results, user_id, db)` already exists in the dispatcher branch at line ~1898-1910.

Existing dispatcher call (REPLACE WRAPPER, not the helper):
File services/backend/app/api/v1/endpoints/coach_chat.py line ~1898-1910:
```python
if name == "retrieve_memories":
    import re
    raw_topic = tool_input.get("topic", "")
    safe_topic = raw_topic if re.match(r'^[\w\s\-\.]{1,100}$', raw_topic, re.UNICODE) else ""
    return _handle_retrieve_memories(
        topic=safe_topic,
        memory_block=memory_block,
        max_results=min(tool_input.get("max_results", 3), 10),
        user_id=user_id,
        db=db,
    )
```

Replacement uses `_compute_retrieve_memories(safe_topic, user_id, db, max_results, memory_block)` which checks the flag and either (a) calls the new `app.services.memory.retrieve(topic, user_id, db, k)` and formats the InsightHit list as text OR (b) falls back to `_handle_retrieve_memories(...)`.

rank_bm25 library:
- Package: `rank_bm25>=0.2.2,<1.0.0` — pure Python, no native deps, Railway-compat.
- API: `BM25Okapi(corpus: list[list[str]])` then `bm25.get_scores(query_tokens: list[str]) -> np.array`.

Settings flag:
```python
COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED: bool = False
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add rank_bm25 dependency + app.services.memory.bm25 module + 10 RED-GREEN unit tests</name>
  <read_first>
    - services/backend/app/models/coach_insight.py (FULL — confirm exact schema)
    - services/backend/app/models/profile_model.py (FULL — confirm `data` is a JSON dict for fallback)
    - services/backend/app/api/v1/endpoints/coach_chat.py — `_handle_retrieve_memories` body (legacy behavior to preserve via fallback)
    - services/backend/pyproject.toml (to add `rank_bm25` to dependencies block)
    - services/backend/tests/conftest.py (test fixtures pattern + DB session)
  </read_first>
  <files>
    - services/backend/pyproject.toml (modify — add rank_bm25)
    - services/backend/app/services/memory/__init__.py (create)
    - services/backend/app/services/memory/bm25.py (create)
    - services/backend/tests/test_memory_bm25.py (create)
    - services/backend/app/core/config.py (modify — add flag)
  </files>
  <behavior>
    - Test 1: `retrieve(topic="3a", user_id="user_a", db=test_db, k=5)` with 3 inserted insights for user_a — `(topic="3a", summary="J'ai versé 5000 CHF en 3a")`, `(topic="lpp", summary="LPP avoir 95k")`, `(topic="3a", summary="Plafond 7258 CHF salarié")` → returns 2 hits, both 3a, ordered by BM25 score desc, top hit's `summary` contains "3a".
    - Test 2: `retrieve("3a", user_id="user_a", db=test_db, k=5)` returns 0 hits when CoachInsightRecord table empty for user_a → falls back to ProfileModel.data: if `profile.data["recent_insights"]` exists and contains entries whose `topic == "3a"`, those are returned. If neither exists, returns empty list.
    - Test 3: USER ISOLATION — insert 1 insight for user_a (`topic="3a"`) and 1 for user_b (`topic="3a"`); `retrieve("3a", user_id="user_a", db=test_db, k=5)` returns ONLY user_a's insight (assert `hit.record.user_id == "user_a"` for every returned hit).
    - Test 4: SCORE FLOOR — query "totally_unrelated_topic" against the 3 user_a insights → returns 0 hits (scores all below 0.3 floor).
    - Test 5: TOP-K — insert 8 insights for user_a all containing "3a"; `retrieve("3a", user_id="user_a", db=test_db, k=5)` returns exactly 5 hits.
    - Test 6: TOPIC TAGS RANKING — insight with `topic="3a"` should outrank an insight with `summary` mentioning "3a" but `topic="generic"`, given the query "3a" (asserts the BM25 corpus includes topic as a query-relevant field).
    - Test 7: NORMALIZATION — query "3A" (uppercase) matches insights with summary "3a" (case-insensitive tokenization via `.lower().split()`).
    - Test 8: EMPTY TOPIC — `retrieve(topic="", user_id="user_a", db=test_db, k=5)` returns empty list (no scoring on empty query).
    - Test 9: DETERMINISM — calling `retrieve` twice with the same args returns identical ranked results.
    - Test 10: FALLBACK BEHAVIOR when `db is None` → returns empty list (no crash). Mirrors legacy graceful degradation.
  </behavior>
  <action>
    Step A — `services/backend/pyproject.toml` add `"rank_bm25>=0.2.2,<1.0.0",` to the `dependencies = [...]` block (alphabetical placement after `psycopg2-binary`).

    Step B — Create `services/backend/app/services/memory/__init__.py`:
    ```python
    """Wave 1a D-07 — Karpathy-wiki memory retrieval.

    Per Julien 2026-05-13 memory project_user_profile_wiki :
    « the user variable library is a Karpathy LLM Wiki, not vector-RAG.
    Per-user pages, BM25 lookup over (topic + insight body), NO vector
    embedding. »
    """
    from app.services.memory.bm25 import retrieve, InsightHit

    __all__ = ["retrieve", "InsightHit"]
    ```

    Step C — Create `services/backend/app/services/memory/bm25.py`:
    ```python
    """Wave 1a D-07 — BM25 ranking over CoachInsightRecord rows.

    Score floor: 0.3 (BM25Okapi default scale; tune in Wave 1c if recall
    insufficient). Top-k: 5 (matches legacy max_results=3..10 envelope).
    User isolation: WHERE user_id = ? at the SQL layer — no cross-user
    leakage possible at this surface.
    """
    from __future__ import annotations
    from dataclasses import dataclass
    from typing import Optional

    from rank_bm25 import BM25Okapi

    _SCORE_FLOOR: float = 0.3
    _MAX_CORPUS_ROWS: int = 500  # bound memory; user with >500 insights
                                  # gets ranked over the 500 most recent
    _DEFAULT_K: int = 5


    @dataclass(frozen=True)
    class InsightHit:
        record_id: str
        user_id: str
        topic: str
        summary: str
        score: float


    def _tokenize(text: str) -> list[str]:
        """Lowercase + whitespace tokenization. No stemming (FR + EN mix)."""
        return text.lower().split()


    def retrieve(
        topic: str,
        user_id: str,
        db,
        k: int = _DEFAULT_K,
    ) -> list[InsightHit]:
        """Return top-k InsightHits for the user, filtered by BM25 score.

        Args:
            topic: free-text query. Empty string returns [].
            user_id: WHERE clause — cross-user isolation guarantee.
            db: SQLAlchemy session. If None, returns [].
            k: max results.

        Returns:
            list[InsightHit] ordered by BM25 score desc, score >= 0.3.
            Empty list if no insights match OR the user has no
            CoachInsightRecord rows AND no ProfileModel.data recent_insights.
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

        # Corpus = topic + " " + summary so the BM25 vocabulary covers both.
        corpus = [_tokenize(f"{r.topic} {r.summary}") for r in rows]
        bm25 = BM25Okapi(corpus)
        scores = bm25.get_scores(_tokenize(topic))
        ranked = sorted(zip(rows, scores), key=lambda x: -x[1])
        hits: list[InsightHit] = []
        for r, s in ranked[:k]:
            if s < _SCORE_FLOOR:
                continue
            hits.append(InsightHit(
                record_id=r.id,
                user_id=r.user_id,
                topic=r.topic,
                summary=r.summary,
                score=float(s),
            ))
        return hits


    def _profile_fallback(topic: str, user_id: str, db, k: int) -> list[InsightHit]:
        """Fallback: scan ProfileModel.data['recent_insights'] for topic match."""
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
        topic_tokens = set(_tokenize(topic))
        hits: list[InsightHit] = []
        for entry in recent:
            entry_topic = (entry.get("topic") or "").lower()
            if any(t in entry_topic for t in topic_tokens):
                hits.append(InsightHit(
                    record_id=f"profile_recent_{entry.get('created_at', '')}",
                    user_id=user_id,
                    topic=entry.get("topic", ""),
                    summary=entry.get("summary", ""),
                    score=1.0,  # exact topic match — bypass BM25
                ))
                if len(hits) >= k:
                    break
        return hits
    ```

    Step D — Flag verification (plan-00 added all 6 flags; plan-05 only READS `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED`). Verify:
    ```bash
    grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/core/config.py
    # Expected: 1
    ```

    Step E — Create `services/backend/tests/test_memory_bm25.py` with Tests 1-10. Use the existing pytest DB session fixture from `services/backend/tests/conftest.py`. Insert `CoachInsightRecord` rows via `db.add(...)` + `db.commit()`. For Test 2 fallback, insert a `ProfileModel` with `data={"recent_insights": [...]}`. For Test 10 (`db is None`), call `retrieve("3a", "user_a", None, 5)` directly.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; pip install -e . &amp;&amp; python3 -m pytest tests/test_memory_bm25.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "rank_bm25" services/backend/pyproject.toml` returns ≥1.
    - `python3 -c "from app.services.memory import retrieve, InsightHit; print('ok')"` exits 0 after `pip install -e services/backend`.
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/core/config.py` returns ≥1.
    - `grep -c "WHERE\|filter(.*user_id" services/backend/app/services/memory/bm25.py` returns ≥1 (SQL-layer isolation).
    - `pytest services/backend/tests/test_memory_bm25.py -q` exits 0 with ≥10 tests collected.
    - `grep -c "_SCORE_FLOOR" services/backend/app/services/memory/bm25.py` returns ≥1 with value `0.3`.
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py` exits 0.
  </acceptance_criteria>
  <done>
    rank_bm25 installed; module + 10 tests green; user isolation enforced at SQL layer.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire _compute_retrieve_memories + dispatcher + ≥5 dispatcher tests</name>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py lines 1898-1915 (dispatcher entry — keep `_handle_retrieve_memories` helper as fallback)
    - services/backend/app/services/memory/bm25.py (just created in Task 1)
    - services/backend/app/services/coach/turn_cap.py lines 95-120 (breadcrumb pattern)
  </read_first>
  <files>
    - services/backend/app/api/v1/endpoints/coach_chat.py (modify)
    - services/backend/tests/test_coach_tools/test_retrieve_memories.py (create)
  </files>
  <behavior>
    - Test 1: dispatcher with flag OFF calls `_handle_retrieve_memories(...)` legacy and returns its output unchanged.
    - Test 2: dispatcher with flag ON + non-empty corpus returns a formatted FR string listing top-k insights with `topic: summary` pairs (verbatim format from legacy `_handle_retrieve_memories` if possible — copy the string template from the legacy body).
    - Test 3: dispatcher with flag ON + empty corpus + empty ProfileModel.data returns the legacy fallback string (graceful degradation).
    - Test 4: dispatcher with flag ON + topic not matching anything (BM25 floor reject) → returns the same fallback string as Test 3.
    - Test 5: dispatcher with flag ON cross-user isolation — user_b query MUST NOT see user_a insights (asserts via inserted fixtures).
    - Test 6: emit_coach_tool_breadcrumb is called with tool_name="retrieve_memories" + all 5 D-15 kwargs (inputs_hash, profile_id_hashed, elapsed_ms, flag_state — NEVER raw user_id, NEVER summary text). Use `unittest.mock.patch("app.api.v1.endpoints.coach_chat.emit_coach_tool_breadcrumb")` and assert the call kwargs match. profile_id_hashed must be the 16-char hash of user_id.
  </behavior>
  <action>
    Step A — In `services/backend/app/api/v1/endpoints/coach_chat.py`, ADD function `_compute_retrieve_memories(topic, user_id, db, max_results, memory_block)` ABOVE the dispatcher entry. The function checks the flag, calls `app.services.memory.retrieve` when ON, formats the returned `list[InsightHit]` into a FR string by copying the legacy `_handle_retrieve_memories` formatting (read its body and replicate verbatim). Falls back to `_handle_retrieve_memories(topic, memory_block, max_results, user_id, db)` when flag OFF or hits empty.

    Step B — Replace the dispatcher branch at line ~1898:
    ```python
        if name == "retrieve_memories":
            import re
            raw_topic = tool_input.get("topic", "")
            safe_topic = raw_topic if re.match(r'^[\w\s\-\.]{1,100}$', raw_topic, re.UNICODE) else ""
            return _compute_retrieve_memories(
                topic=safe_topic,
                user_id=user_id,
                db=db,
                max_results=min(tool_input.get("max_results", 3), 10),
                memory_block=memory_block,
            )
    ```

    Step C — Sentry breadcrumb via the plan-00 helper (D-15 uniform payload). For retrieve_memories, the operation is keyed on user_id (not profile_id) and there is no Pydantic response with an `inputs_hash` field — so the executor computes inputs_hash from the (topic, user_id, k) query slice and reuses `hash_profile_id` on user_id (the helper is name-neutral: it hashes any string identifier to a 16-char SHA-256 prefix).

    ```python
    import time
    from app.observability.coach_breadcrumbs import emit_coach_tool_breadcrumb
    from app.utils.hashing import hash_profile_id
    from app.services.coach.inputs_hash import compute_inputs_hash

    # At function entry (after flag check passes):
    _t0 = time.perf_counter()

    # ... call retrieve(topic, user_id, db, k) and format the result ...

    # Before returning, emit the D-15 breadcrumb:
    elapsed_ms = int((time.perf_counter() - _t0) * 1000)
    query_inputs_hash = compute_inputs_hash({"topic": topic, "user_id": user_id or "", "k": max_results})
    emit_coach_tool_breadcrumb(
        tool_name="retrieve_memories",
        inputs_hash=query_inputs_hash,
        profile_id_hashed=hash_profile_id(user_id) if user_id else "anonymous_00000",
        elapsed_ms=elapsed_ms,
        flag_state="on",
    )
    ```

    NOTE on `hits_count` — D-15 mandates a uniform 5-kwarg payload across plans 01-05 (no extra fields per-tool). If hits_count visibility is needed for ops dashboards, attach it as a follow-up breadcrumb after `coach.tool.retrieve_memories` with category `coach.tool.retrieve_memories.hits` and `data={"hits_count": len(hits)}` — separate breadcrumb, separate concern.

    Step D — Create `services/backend/tests/test_coach_tools/test_retrieve_memories.py` with Tests 1-6.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_memory_bm25.py tests/test_coach_tools/test_retrieve_memories.py -q &amp;&amp; python3 tools/checks/banned_terms_python.py services/backend/app/services/memory/bm25.py services/backend/app/api/v1/endpoints/coach_chat.py &amp;&amp; python3 tools/checks/accent_lint_fr.py services/backend/app/services/memory/bm25.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "_compute_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3.
    - `grep -c "_handle_retrieve_memories" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥3 (legacy preserved + fallback calls).
    - `grep -c "COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `pytest services/backend/tests/test_memory_bm25.py tests/test_coach_tools/test_retrieve_memories.py -q` exits 0 with ≥16 total tests (10 + 6).
    - `grep -E "tool_name=\"retrieve_memories\"" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1.
    - `grep -c "emit_coach_tool_breadcrumb(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥5 (plans 01 + 02 + 03 + 04 + this).
    - `grep -E "elapsed_ms\s*=\s*int\(" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥5.
    - `grep -c "hash_profile_id(user_id)" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1 (user_id hashed through the D-15 helper, NOT raw).
    - `grep "user_id=user_id\|user_id=user_a\|user_id == user_a" services/backend/tests/test_coach_tools/test_retrieve_memories.py` returns ≥1 (cross-user test asserts isolation).
    - `python3 tools/checks/banned_terms_python.py <touched files>` exits 0.
  </acceptance_criteria>
  <done>
    Dispatcher routes through BM25 wrapper; ≥16 tests green; cross-user isolation enforced; Sentry payload non-PII.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1A-05-01 | T | Legacy `_handle_retrieve_memories` regression when flag OFF | mitigate | Task-2 Test 1 asserts byte-identity passthrough. |
| T-WAVE1A-05-02 | I | LSFin banned-terms leak in formatter output | mitigate | Formatter copies FR strings from legacy handler verbatim; `banned_terms_python.py` enforces. |
| T-WAVE1A-05-03 | I | PII leak in Sentry breadcrumb (raw user_id) | mitigate | Payload uses `hashlib.sha256(user_id)[:16]` — irreversible 16-char prefix; `hits_count` is integer; no `summary` text. |
| T-WAVE1A-05-04 | I (BM25-specific) | retrieve_memories returns insights from wrong user_id | mitigate | SQL filter `WHERE user_id = ?` at the query layer (not post-filter); Task-1 Test 3 asserts cross-user isolation with 2-user fixture; Task-2 Test 5 cross-user dispatcher test. |
| T-WAVE1A-05-05 | E (Elevation of privilege) | adversarial topic injection (e.g. `"' OR 1=1; --"`) | mitigate | The existing dispatcher regex `^[\w\s\-\.]{1,100}$` upstream of `_compute_retrieve_memories` blocks SQL-meaningful characters BEFORE the topic reaches BM25 tokenization. SQLAlchemy parameterized queries used throughout. |
</threat_model>

<verification>
- `pytest tests/test_memory_bm25.py tests/test_coach_tools/test_retrieve_memories.py -q` exits 0 with ≥16 tests.
- `pytest services/backend/ -q` full suite — zero regressions.
- `banned_terms_python.py` + `accent_lint_fr.py` green.
- `rank_bm25` dependency installs cleanly on Railway CI (pure-Python, no native deps).
- Cross-user isolation test (Test 3 in Task 1, Test 5 in Task 2) demonstrably PASSES — assert `hit.record.user_id == "user_a"` for every returned hit when query was for user_a.
</verification>

<success_criteria>
- WAVE1A-06 satisfied: formal `app.services.memory.bm25.retrieve` exists, BM25-based, NO vector embedding, NO LLM call.
- WAVE1A-09 satisfied: dispatcher emits structured InsightHit list serialized via the formatter (Pydantic-equivalent surface).
- WAVE1A-10 satisfied: `COACH_TOOL_SERVER_SIDE_RETRIEVE_MEMORIES_ENABLED` flag exists, default False.
- ≥16 new backend tests (10 BM25 + 6 dispatcher), lints green.
- 0 cross-user leak — SQL-filter assertion present and tested.
</success_criteria>

<output>
After completion, create `.planning/phases/wave-1a-backend-tools-refactor/wave-1a-05-SUMMARY.md` with files, tests, lints, BM25 ranking sanity check (top-1 score for "3a" query on a Julien fixture cited), 0-trust self-check.
</output>
