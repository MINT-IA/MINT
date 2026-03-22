# P3-A — pgvector Production Vector Store (NOT ChromaDB)

> DIRECTIVE: Use pgvector on Railway PostgreSQL. NOT ChromaDB.
> ChromaDB is dev/CI only. pgvector is production-ready, scalable, already paid for.
> The migration SQL is ALREADY WRITTEN. Execute the plan, don't invent a new one.

---

## CONTEXT — Read these files FIRST

```
# The migration (READY — just execute it)
services/backend/migrations/003_pgvector.sql

# The activation plan (FOLLOW THIS)
docs/P3_READINESS_TRACKER.md

# The existing RAG pipeline (you're upgrading this)
services/backend/app/services/rag/faq_service.py       # Current keyword search — you're replacing this
services/backend/app/services/rag/retriever.py          # MintRetriever — calls FaqService
services/backend/app/services/rag/orchestrator.py       # RAGOrchestrator — calls retriever
services/backend/app/services/rag/vector_store.py       # ChromaDB store (DEV ONLY — keep for CI fallback)

# The corpus to embed
education/inserts/                                       # 40 educational concept files
services/backend/app/services/rag/faq_service.py         # 58 FAQ entries (inline)
legal/                                                   # 5 legal documents

# Constants and rules
CLAUDE.md
services/backend/app/constants/social_insurance.py
```

---

## STEP 1 — Database migration

Execute `services/backend/migrations/003_pgvector.sql` on Railway PostgreSQL.

This creates:
- `document_embeddings` table with `vector(1536)` column
- IVFFlat cosine index (lists=10 for ~100 docs)
- FTS index on content (French tokenizer)
- doc_type enum: concept, faq, canton, legal, memory

If Railway PostgreSQL doesn't have pgvector enabled yet:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```
This is available on Railway PostgreSQL by default (Postgres 15+).

---

## STEP 2 — Embedding pipeline script

Create `services/backend/scripts/embed_corpus.py`:

```python
"""
Embed the MINT knowledge corpus into pgvector.

Usage:
    cd services/backend
    python scripts/embed_corpus.py

Requires:
    - OPENAI_API_KEY env var (for text-embedding-3-small)
    - DATABASE_URL env var (Railway PostgreSQL)
    - pgvector extension installed (Step 1)

Cost: ~$0.001 for 103 documents (~50K tokens at $0.02/1M tokens)
"""
```

### Corpus sources (103 documents):

1. **Education inserts** (40 docs): Read each `.md` file from `education/inserts/`.
   - `doc_id`: filename without extension (e.g. `avs_rente_calcul`)
   - `doc_type`: `concept`
   - `title`: first H1 or H2 heading
   - `content`: full markdown text
   - `metadata`: `{"source": "education/inserts/<filename>", "tags": [extracted from content]}`

2. **FAQ entries** (58 docs): Extract from `FaqService._ALL_FAQS` in `faq_service.py`.
   - `doc_id`: `faq_<id>` (e.g. `faq_avs_age_reference`)
   - `doc_type`: `faq`
   - `title`: question text
   - `content`: `question + "\n\n" + answer`
   - `metadata`: `{"category": category.name, "legal_refs": legal_refs, "tags": tags}`

3. **Legal documents** (5 docs): Read from `legal/` directory.
   - `doc_id`: filename without extension
   - `doc_type`: `legal`
   - `title`: first heading
   - `content`: full text

### Embedding:

```python
import openai

client = openai.OpenAI()  # reads OPENAI_API_KEY from env

def embed_text(text: str) -> list[float]:
    """Embed a single text using text-embedding-3-small (1536 dims)."""
    response = client.embeddings.create(
        model="text-embedding-3-small",
        input=text[:8191],  # max input tokens
    )
    return response.data[0].embedding
```

### Database insertion:

```python
import psycopg2

def insert_document(conn, doc_id, doc_type, title, content, embedding, metadata):
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO document_embeddings (doc_id, doc_type, title, content, embedding, metadata)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (doc_id) DO UPDATE SET
                content = EXCLUDED.content,
                embedding = EXCLUDED.embedding,
                metadata = EXCLUDED.metadata,
                updated_at = NOW()
        """, (doc_id, doc_type, title, content, embedding, json.dumps(metadata)))
    conn.commit()
```

### Script must:
- Be idempotent (ON CONFLICT DO UPDATE)
- Log progress: `Embedded 1/103: avs_rente_calcul (1536 dims)`
- Report total cost estimate at the end
- Handle errors per-document (skip and log, don't abort)
- Accept `--dry-run` flag that counts docs without embedding

---

## STEP 3 — HybridSearchService

Create `services/backend/app/services/rag/hybrid_search_service.py`:

```python
"""
HybridSearchService — combines pgvector similarity + PostgreSQL FTS.

Architecture:
    1. Vector similarity: cosine distance on embeddings
    2. Keyword FTS: PostgreSQL ts_rank on content
    3. Score fusion: weighted combination (0.7 vector + 0.3 keyword)
    4. Fallback: keyword-only when pgvector is unavailable

This replaces FaqService.search() as the primary retrieval method.
FaqService remains as fallback when no database connection is available
(e.g., CI tests without PostgreSQL).
"""
```

### Interface:

```python
class HybridSearchService:
    def __init__(self, db_url: str):
        ...

    async def search(
        self,
        query: str,
        n_results: int = 5,
        doc_types: list[str] | None = None,  # filter by type
        min_score: float = 0.3,
    ) -> list[SearchResult]:
        """Search using hybrid vector + keyword scoring."""
        ...

    async def is_available(self) -> bool:
        """Check if pgvector is accessible."""
        ...
```

### SearchResult:

```python
@dataclass
class SearchResult:
    doc_id: str
    doc_type: str
    title: str
    content: str
    score: float           # fused score 0-1
    vector_score: float    # cosine similarity
    keyword_score: float   # FTS rank
    metadata: dict
```

### SQL for hybrid search:

```sql
-- Vector similarity (cosine distance → similarity)
WITH vector_results AS (
    SELECT doc_id, title, content, metadata, doc_type,
           1 - (embedding <=> $1::vector) AS vector_score
    FROM document_embeddings
    WHERE doc_type = ANY($3)  -- optional type filter
    ORDER BY embedding <=> $1::vector
    LIMIT $2
),
-- Keyword FTS
keyword_results AS (
    SELECT doc_id, title, content, metadata, doc_type,
           ts_rank(to_tsvector('french', content), plainto_tsquery('french', $4)) AS keyword_score
    FROM document_embeddings
    WHERE to_tsvector('french', content) @@ plainto_tsquery('french', $4)
      AND ($3 IS NULL OR doc_type = ANY($3))
    LIMIT $2
)
-- Fusion: combine both result sets
SELECT COALESCE(v.doc_id, k.doc_id) AS doc_id,
       COALESCE(v.title, k.title) AS title,
       COALESCE(v.content, k.content) AS content,
       COALESCE(v.metadata, k.metadata) AS metadata,
       COALESCE(v.doc_type, k.doc_type) AS doc_type,
       COALESCE(v.vector_score, 0) AS vector_score,
       COALESCE(k.keyword_score, 0) AS keyword_score,
       (0.7 * COALESCE(v.vector_score, 0) + 0.3 * COALESCE(k.keyword_score, 0)) AS fused_score
FROM vector_results v
FULL OUTER JOIN keyword_results k ON v.doc_id = k.doc_id
ORDER BY fused_score DESC
LIMIT $2;
```

### Query embedding:
The service must embed the user's query using the same `text-embedding-3-small` model before searching. Cache the OpenAI client instance.

---

## STEP 4 — Wire into RAG pipeline

In `services/backend/app/services/rag/retriever.py`:

```python
class MintRetriever:
    def __init__(self, vector_store=None, hybrid_search=None):
        self._hybrid = hybrid_search  # HybridSearchService (pgvector)
        self._vector_store = vector_store  # ChromaDB (fallback/dev)

    def retrieve(self, query, profile_context=None, n_results=5, language="fr"):
        # Priority: HybridSearchService (pgvector) > ChromaDB > empty
        if self._hybrid and await self._hybrid.is_available():
            results = await self._hybrid.search(query, n_results=n_results)
            return [{"text": r.content, "source": r.metadata} for r in results]

        # Fallback: ChromaDB (dev/CI)
        if self._vector_store:
            return self._vector_store.query(query, n_results=n_results)

        return []
```

In `services/backend/app/services/rag/orchestrator.py`:
- `RAGOrchestrator.__init__` accepts optional `hybrid_search` parameter
- Passes it to `MintRetriever`

In `services/backend/app/api/v1/endpoints/coach_chat.py`:
- `_get_orchestrator()` creates `HybridSearchService(db_url=DATABASE_URL)` when `DATABASE_URL` is set
- Falls back to ChromaDB-only when no DATABASE_URL (CI/dev)

### FAQ fallback preserved:
The orchestrator's FAQ fallback (< 2 vector results → search FaqService) remains unchanged.
HybridSearchService replaces the primary retrieval, not the fallback.

---

## STEP 5 — Tests

### Minimum 15 tests in `services/backend/tests/test_hybrid_search.py`:

```
1.  search returns results for known concept query ("pilier 3a")
2.  search returns results for FAQ query ("taux de conversion LPP")
3.  search with doc_type filter returns only matching types
4.  search with min_score filters low-relevance results
5.  fused_score = 0.7 * vector + 0.3 * keyword (verify formula)
6.  empty query returns empty results (not error)
7.  is_available returns True when pgvector is accessible
8.  is_available returns False when database is unavailable
9.  fallback to keyword-only when embedding API fails
10. SearchResult contains all required fields
11. Results ordered by fused_score descending
12. Duplicate doc_id across vector/keyword merged correctly
13. French FTS tokenizer handles accents (prévoyance, retraite, décès)
14. Large content truncated before embedding (max 8191 tokens)
15. ON CONFLICT DO UPDATE works for re-embedding
```

### Integration test:
One test that runs the full pipeline: embed → insert → search → verify result matches.
Use a test PostgreSQL instance or mock the database connection.

---

## STEP 6 — Monitoring

Add to `faq_service.py` (or HybridSearchService):
```python
logger.info(
    "hybrid_search query=%r results=%d top_fused=%.3f top_vector=%.3f top_keyword=%.3f",
    query[:50], len(results),
    results[0].score if results else 0,
    results[0].vector_score if results else 0,
    results[0].keyword_score if results else 0,
)
```

After deployment, monitor for 2 weeks:
- `top_fused < 0.3` → query not well served
- `vector_score >> keyword_score` → vector adding value
- `keyword_score >> vector_score` → vector not helping (check embeddings)

---

## CONSTRAINTS

- **DATABASE_URL from environment.** Never hardcode connection strings.
- **OPENAI_API_KEY for embeddings only.** Never use it for chat (BYOK model).
- **ChromaDB stays for dev/CI.** Tests that don't have PostgreSQL use ChromaDB.
- **FaqService stays as ultimate fallback.** If both pgvector and ChromaDB fail, inline FAQ works.
- **No PII in embeddings.** Only educational content, FAQ, and legal docs. Never user data.
- **French FTS.** Use `'french'` tokenizer, not `'english'`.
- **Idempotent embedding script.** Safe to re-run (ON CONFLICT DO UPDATE).

## EXECUTION CHECKLIST

```
[ ] Read 003_pgvector.sql and P3_READINESS_TRACKER.md
[ ] Verify Railway PostgreSQL has pgvector (CREATE EXTENSION vector)
[ ] Execute 003_pgvector.sql
[ ] Create embed_corpus.py
[ ] Run embedding (103 docs, ~$0.001)
[ ] Create HybridSearchService
[ ] Wire into retriever.py + orchestrator.py + coach_chat.py
[ ] Tests (15 minimum)
[ ] pytest green
[ ] Update P3_READINESS_TRACKER.md status
[ ] Commit
```
