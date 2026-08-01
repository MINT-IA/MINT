---
name: mint-prompt-eval
description: Fail-closed evaluation contract for every MINT LLM or RAG behavior change.
---

# MINT Prompt Eval

Use before changing or promoting any prompt, model, retrieval policy, tool
routing, or LLM-generated user explanation.

1. Version the candidate prompt and all model, retrieval, tool, and judge settings.
2. Freeze a representative golden corpus before comparing candidates.
3. Run deterministic assertions plus scored domain dimensions from
   `product/mint_next/contracts/llm-eval.yaml`.
4. Reject any safety, privacy, consent, or regulatory regression regardless of
   aggregate score.
5. Require measured improvement, a regression report, and independent
   reproduction. The author cannot approve their own candidate.
6. Treat model output, model-as-judge scores, and agent summaries as claims;
   retain inputs, outputs, versions, and executable commands as evidence.

No LLM/RAG path is complete without an eval corpus and a runnable gate wired to
that path. Creating a prompt file alone is façade sans câblage.
