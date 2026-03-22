-- P3-A: Vector store migration for Railway PostgreSQL.
--
-- DO NOT EXECUTE until the P3-A trigger fires:
--   - Corpus exceeds ~100 documents, OR
--   - faq_search top_score < 0.5 on > 20% of queries (check logs)
--
-- Prerequisites:
--   - Railway PostgreSQL with pgvector extension available
--   - text-embedding-3-small API access (OpenAI, ~$0.001 for 100 docs)
--
-- After execution:
--   1. Run the embedding pipeline (services/backend/scripts/embed_corpus.py)
--   2. Switch FaqService.search() to HybridSearchService.search()
--   3. Monitor recall_relevance for 2 weeks before removing keyword fallback
--
-- References:
--   - https://github.com/pgvector/pgvector
--   - docs/ROADMAP_V2.md P3-A
--   - .claude/prompts/agentic-architecture-sprint.md

-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Document embeddings table
CREATE TABLE IF NOT EXISTS document_embeddings (
    id SERIAL PRIMARY KEY,

    -- Document identity
    doc_id VARCHAR(100) NOT NULL UNIQUE,
    doc_type VARCHAR(20) NOT NULL CHECK (doc_type IN ('concept', 'faq', 'canton', 'legal', 'memory')),

    -- Content
    title VARCHAR(200),
    content TEXT NOT NULL,

    -- Embedding vector (text-embedding-3-small = 1536 dimensions)
    embedding vector(1536),

    -- Metadata (source file, legal refs, tags, etc.)
    metadata JSONB DEFAULT '{}',

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Approximate nearest neighbor index (IVFFlat)
-- lists = sqrt(n_docs) is the rule of thumb:
--   ~100 docs → lists = 10
--   ~500 docs → lists = 22
--   ~5000 docs → lists = 70
CREATE INDEX IF NOT EXISTS idx_embeddings_vector
    ON document_embeddings USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 10);

-- Type filter index for scoped searches
CREATE INDEX IF NOT EXISTS idx_embeddings_doc_type
    ON document_embeddings (doc_type);

-- Full-text search index on content (hybrid keyword + vector)
CREATE INDEX IF NOT EXISTS idx_embeddings_content_fts
    ON document_embeddings USING gin (to_tsvector('french', content));
