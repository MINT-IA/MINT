# P3 Readiness Tracker — Vector Store & Multi-Agent

> This document tracks the trigger conditions and preparation state for P3-A (Vector Store)
> and P3-B (Multi-Agent). Check it at every sprint planning to decide if activation is warranted.
>
> Last updated: 2026-03-22

---

## P3-A — Vector Store (pgvector)

### Trigger conditions (activate when ANY is true)

| Condition | Threshold | How to check | Current value |
|-----------|-----------|-------------|---------------|
| Corpus size | > 100 documents | Count education + FAQ + legal | **103** (AT THRESHOLD) |
| Keyword recall quality | top_score < 0.5 on > 20% queries | `grep "faq_search" logs \| awk` | Not yet measured (logging added) |

### Preparation state

| Item | Status | File |
|------|--------|------|
| Migration SQL ready | DONE | `services/backend/migrations/003_pgvector.sql` |
| faq_search recall logging | DONE | `services/backend/app/services/rag/faq_service.py` |
| Corpus inventory | DONE | 40 inserts + 58 FAQ + 5 legal = 103 |
| HybridSearchService interface | SPEC ONLY | See architecture in `agentic-architecture-sprint.md` |
| Embedding pipeline script | NOT STARTED | `services/backend/scripts/embed_corpus.py` (to create) |

### Day-J checklist

```
[ ] Railway PostgreSQL: CREATE EXTENSION vector
[ ] Execute migrations/003_pgvector.sql
[ ] Create embed_corpus.py (text-embedding-3-small, batch 100 docs)
[ ] Embed 103+ documents
[ ] Create HybridSearchService (keyword + vector + score fusion)
[ ] Replace FaqService.search() in retriever.py
[ ] Keep FaqService as fallback when pgvector unavailable
[ ] Tests: keyword-only, vector-only, hybrid, fallback
[ ] Monitor recall for 2 weeks
[ ] Update this document
```

### Cost estimate
- Embedding: ~$0.001 (50K tokens at $0.02/1M)
- pgvector on Railway: included in PostgreSQL plan
- Ongoing: re-embed on corpus changes (~$0.0001/update)

---

## P3-B — Multi-Agent (Prompt Routing)

### Trigger conditions (activate when ANY is true)

| Condition | Threshold | How to check | Current value |
|-----------|-----------|-------------|---------------|
| System prompt size | > 3500 tokens estimated | `grep "system_prompt_length" logs` | Not yet measured (logging added) |
| Domain-specific quality | LLM confuses LPP/AVS rules | Manual review of 50 conversations | Not yet assessed |

### Preparation state

| Item | Status | File |
|------|--------|------|
| System prompt length logging | DONE | `services/backend/app/api/v1/endpoints/coach_chat.py` |
| `domain` field on ReasoningOutput | DONE | `services/backend/app/services/coach/structured_reasoning.py` |
| Domain mapping (fact_tag -> domain) | DONE | deficit->budget, 3a->fiscalite, gap->retraite, rachat->retraite |
| Domain prompt blocks (6 domains) | SPEC ONLY | To write when trigger fires |
| DOMAIN_TOOL_SETS | SPEC ONLY | To implement when trigger fires |
| PromptSelector | SPEC ONLY | To implement when trigger fires |

### Domain taxonomy (decided)

| Domain | fact_tags | Legal context | Tool subset |
|--------|-----------|---------------|-------------|
| `budget` | deficit | Charges, marge, dette, epargne | show_budget_*, get_budget_status |
| `retraite` | gap_warning, rachat_opportunity | LAVS, LPP, conversion, decaissement | show_retirement_*, get_retirement_projection |
| `fiscalite` | 3a_deadline, 3a_not_maxed | LIFD, deductions, 3a, cantons | show_fact_card, get_cross_pillar_analysis |
| `logement` | (future) | FINMA, hypotheque, EPL, amort | (future) |
| `famille` | (future) | Mariage, divorce, naissance, succession | (future) |
| `travail` | (future) | Chomage, independance, frontalier | (future) |

### Day-J checklist

```
[ ] Write 6 domain prompt blocks (legal context per domain)
[ ] Implement PromptSelector: base + regional + lifecycle + plan + domain[selected]
[ ] Implement DOMAIN_TOOL_SETS (filter tools by domain)
[ ] Wire domain from ReasoningOutput into PromptSelector
[ ] Pass domain to ContextInjectorService (Flutter side)
[ ] A/B test: full prompt vs routed prompt on 100 queries
[ ] Measure: tokens/request, accuracy per domain, fallback rate
[ ] Update this document
```

### Architecture reminder (NON-NEGOTIABLE)

**1 process with 6 modes, NOT 6 separate agents.**
- Same LLM, different system prompt block selected by classifier
- ContextInjectorService already does this for lifecycle/regional
- Adding domain selection is the same pattern
- See memory: `feedback_no_multiagent_premature.md`

---

## Sprint planning integration

At each sprint planning:
1. Check the trigger conditions above
2. If ANY condition is met, add P3-A or P3-B to the sprint
3. Follow the Day-J checklist
4. The prep work is done — activation is a branchement, not a refonte
