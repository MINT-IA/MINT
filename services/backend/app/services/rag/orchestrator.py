"""
RAG orchestrator for MINT.

Coordinates the full RAG pipeline: retrieve, build context, generate, and filter.
"""

from __future__ import annotations

import logging
from typing import Optional

from app.services.rag.faq_service import FaqService
from app.services.rag.guardrails import ComplianceGuardrails
from app.services.rag.llm_client import LLMClient
from app.services.rag.retriever import MintRetriever
from app.services.rag.vector_store import MintVectorStore

logger = logging.getLogger(__name__)


class RAGOrchestrator:
    """Orchestrate the full RAG pipeline."""

    def __init__(self, vector_store: MintVectorStore, hybrid_search=None):
        """
        Initialize the orchestrator.

        Args:
            vector_store: The MintVectorStore (ChromaDB) for dev/CI retrieval.
            hybrid_search: Optional HybridSearchService (pgvector) for production.
                When provided, the retriever uses pgvector first, ChromaDB as fallback.
        """
        self.vector_store = vector_store
        self.retriever = MintRetriever(vector_store, hybrid_search=hybrid_search)
        self.guardrails = ComplianceGuardrails()

    async def query(
        self,
        question: str,
        api_key: str,
        provider: str,
        model: Optional[str] = None,
        profile_context: Optional[dict] = None,
        language: str = "fr",
        n_results: int = 5,
        tools: list[dict] | None = None,
        system_prompt: Optional[str] = None,
    ) -> dict:
        """
        Execute the full RAG pipeline.

        Steps:
            1. Retrieve relevant chunks from the vector store.
            2. Build context from chunks.
            3. Create LLM client with BYOK key.
            4. Generate response with system prompt + compliance filter.
            5. Apply post-generation compliance filter.
            6. Return answer with sources and disclaimers.

        Args:
            question: The user's question.
            api_key: User's API key (BYOK — not stored).
            provider: LLM provider ("claude", "openai", "mistral").
            model: Optional model override.
            profile_context: Optional profile data for personalization.
            language: Language code ("fr", "de", "en", "it").
            n_results: Number of context chunks to retrieve.
            tools: Optional list of tool definitions (Anthropic format).
                   When provided, Claude may return tool_use blocks alongside text.
            system_prompt: Optional override for the system prompt.  When
                   provided, this is used INSTEAD of the generic guardrails
                   prompt.  The caller is responsible for including compliance
                   rules in the override prompt (coach_chat.py does this via
                   build_system_prompt which embeds compliance directives).

        Returns:
            Dict with keys: answer, sources, disclaimers, tokens_used.
            When tool_calls are present: also includes "tool_calls" key.
        """
        # Step 1: Retrieve relevant chunks (async — pgvector or ChromaDB)
        retrieved = await self.retriever.retrieve(
            query=question,
            profile_context=profile_context,
            n_results=n_results,
            language=language,
        )

        # Step 1b: FAQ fallback — if vector store returned few results, enrich with FAQs
        faq_sources: list[dict] = []
        if len(retrieved) < 2:
            faq_results = FaqService.search(question)
            for faq in faq_results[:3]:
                retrieved.append({"text": faq.answer, "source": {}})
                faq_sources.append({"type": "faq", "id": faq.id})

        # Step 2: Build context from chunks
        context_chunks = [r["text"] for r in retrieved if r.get("text")]

        # Step 3: Create LLM client with BYOK key
        llm_client = LLMClient(
            provider=provider,
            api_key=api_key,
            model=model,
        )

        # Step 4: Generate response with system prompt
        # Use the caller-provided system prompt if available (e.g., the coach
        # endpoint builds a rich prompt with lifecycle, regional voice, plan
        # awareness, and structured reasoning).  Fall back to the generic
        # guardrails prompt for other callers (e.g., RAG-only queries).
        if not system_prompt:
            system_prompt = self.guardrails.build_system_prompt(
                language, profile_context=profile_context
            )
        raw_response = await llm_client.generate(
            system_prompt=system_prompt,
            user_message=question,
            context_chunks=context_chunks,
            tools=tools,
        )

        # Step 5: Handle tool_use responses vs plain text
        tool_calls = None
        actual_usage_tokens = None
        if isinstance(raw_response, dict):
            # LLM returned structured response (with tool calls and/or usage)
            response_text = raw_response.get("text", "")
            tool_calls = raw_response.get("tool_calls")
            actual_usage_tokens = raw_response.get("usage_tokens")
        else:
            response_text = raw_response

        # Step 6: Apply post-generation compliance filter
        filtered = self.guardrails.filter_response(response_text, language)

        # Step 7: Build sources list (vector sources + FAQ sources)
        sources = []
        seen_sources = set()
        for r in retrieved:
            source = r.get("source", {})
            source_key = f"{source.get('file', '')}:{source.get('section', '')}"
            if source_key not in seen_sources:
                seen_sources.add(source_key)
                sources.append(source)
        sources.extend(faq_sources)

        # Use actual API token usage when available, fall back to estimation
        if actual_usage_tokens is not None:
            tokens_used = actual_usage_tokens
        else:
            tokens_used = self._estimate_tokens(
                system_prompt, question, context_chunks, filtered["text"]
            )

        result = {
            "answer": filtered["text"],
            "sources": sources,
            "disclaimers": filtered["disclaimers_added"],
            "tokens_used": tokens_used,
        }
        if tool_calls:
            result["tool_calls"] = tool_calls
        return result

    async def query_vision(
        self,
        image_base64: str,
        media_type: str,
        document_type: str,
        api_key: str,
        provider: str,
        model: Optional[str] = None,
        profile_context: Optional[dict] = None,
        language: str = "fr",
    ) -> dict:
        """Execute the vision-augmented RAG pipeline for document extraction.

        Steps:
            1. Build extraction prompt for the target document type.
            2. Create LLM client with BYOK key (vision-capable provider).
            3. Send image + extraction prompt to vision LLM.
            4. Parse structured extraction from LLM response.
            5. Apply compliance filter.
            6. Return extracted fields + raw analysis.

        Args:
            image_base64: Base64-encoded document image.
            media_type: MIME type (image/jpeg, image/png, image/webp).
            document_type: Target type (lpp_certificate, tax_declaration, etc.).
            api_key: User's API key (BYOK — not stored).
            provider: LLM provider ("claude" or "openai").
            model: Optional model override.
            profile_context: Optional profile data for context.
            language: Language code.

        Returns:
            Dict with keys: extracted_fields, document_type_detected,
            raw_analysis, confidence_delta, disclaimers, tokens_used.
        """
        # Step 1: Build extraction prompt
        system_prompt = self._vision_system_prompt(language)
        user_prompt = self._vision_user_prompt(document_type, language)

        # Step 2: Create vision-capable LLM client
        llm_client = LLMClient(
            provider=provider,
            api_key=api_key,
            model=model,
        )

        # Step 3: Call vision API
        raw_analysis = await llm_client.generate_vision(
            image_base64=image_base64,
            media_type=media_type,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
        )

        # Step 4: Parse structured fields from response
        extracted_fields = self._parse_vision_fields(raw_analysis, document_type)

        # Step 5: Apply compliance filter
        filtered = self.guardrails.filter_response(raw_analysis, language)

        # Step 6: Estimate confidence delta
        confidence_delta = self._estimate_confidence_delta(
            document_type, len(extracted_fields)
        )

        tokens_used = self._estimate_tokens(
            system_prompt, user_prompt, [], raw_analysis
        )

        # Ensure compliance disclaimer is always present
        disclaimers = list(filtered.get("disclaimers_added", []))
        mandatory = "Outil educatif, ne constitue pas un conseil financier (LSFin)."
        if not any("LSFin" in d for d in disclaimers):
            disclaimers.append(mandatory)

        return {
            "extracted_fields": extracted_fields,
            "document_type_detected": document_type,
            "raw_analysis": filtered["text"],
            "confidence_delta": confidence_delta,
            "disclaimers": disclaimers,
            "tokens_used": tokens_used,
        }

    def _vision_system_prompt(self, language: str) -> str:
        """Build the system prompt for document vision extraction."""
        return (
            "Tu es un expert en documents financiers suisses. "
            "Tu extrais des donnees structurees depuis des photos de documents. "
            "Reponds TOUJOURS en JSON valide avec le format suivant pour chaque champ:\n"
            '{"fields": [{"field_name": "...", "label": "...", '
            '"value": 123.45, "source_text": "texte original"}]}\n\n'
            "Regles:\n"
            "- Extrais TOUS les champs financiers visibles.\n"
            "- Les montants en CHF: utilise des nombres sans apostrophes.\n"
            "- Les pourcentages: utilise des nombres decimaux (6.8 pas 0.068).\n"
            "- Si un champ n'est pas lisible, ne l'inclus pas.\n"
            "- N'invente AUCUNE valeur. Extrait uniquement ce qui est visible.\n"
            "- Outil educatif, ne constitue pas un conseil financier (LSFin)."
        )

    def _vision_user_prompt(self, document_type: str, language: str) -> str:
        """Build the user prompt for the target document type."""
        prompts = {
            "lpp_certificate": (
                "Extrait les champs suivants de ce certificat de prevoyance LPP:\n"
                "- avoir_vieillesse_total (Avoir de vieillesse total, CHF)\n"
                "- avoir_obligatoire (Part obligatoire, CHF)\n"
                "- avoir_surobligatoire (Part surobligatoire, CHF)\n"
                "- taux_conversion_obligatoire (Taux de conversion obligatoire, %)\n"
                "- taux_conversion_surobligatoire (Taux de conversion surobligatoire, %)\n"
                "- salaire_assure (Salaire assure, CHF)\n"
                "- cotisation_employe (Cotisation employe mensuelle, CHF)\n"
                "- cotisation_employeur (Cotisation employeur mensuelle, CHF)\n"
                "- rachat_maximum (Lacune de rachat / Rachat maximal, CHF)\n"
                "- rente_vieillesse_projetee (Rente projetee a 65, CHF/an)\n"
                "- capital_projete_65 (Capital projete a 65, CHF)\n"
                "- prestation_invalidite (Prestation d'invalidite, CHF/an)\n"
                "- prestation_deces (Prestation de deces, CHF)\n\n"
                "Reponds en JSON."
            ),
            "tax_declaration": (
                "Extrait les champs suivants de cette declaration fiscale "
                "ou avis de taxation:\n"
                "- revenu_imposable (Revenu imposable, CHF)\n"
                "- fortune_imposable (Fortune imposable, CHF)\n"
                "- deductions_effectuees (Total deductions, CHF)\n"
                "- impot_cantonal (Impot cantonal + communal, CHF)\n"
                "- impot_federal (Impot federal direct, CHF)\n"
                "- taux_marginal_effectif (Taux marginal effectif, %)\n\n"
                "Reponds en JSON."
            ),
            "avs_extract": (
                "Extrait les champs suivants de cet extrait de compte "
                "individuel AVS (CI):\n"
                "- annees_cotisation (Nombre d'annees de cotisation)\n"
                "- ramd (Revenu annuel moyen determinant, CHF)\n"
                "- lacunes_cotisation (Nombre d'annees de lacunes)\n"
                "- bonifications_educatives (Nombre d'annees de bonifications)\n\n"
                "Reponds en JSON."
            ),
            "generic": (
                "Analyse ce document financier suisse. Extrait tous les "
                "champs financiers visibles (montants CHF, pourcentages, dates). "
                "Identifie le type de document. Reponds en JSON."
            ),
        }
        return prompts.get(document_type, prompts["generic"])

    def _parse_vision_fields(
        self, raw_response: str, document_type: str
    ) -> list[dict]:
        """Parse structured fields from the vision LLM response.

        Attempts JSON extraction; falls back to empty list on parse failure.
        """
        import json
        import re

        # Try to extract JSON from the response
        # LLMs sometimes wrap JSON in markdown code blocks
        json_match = re.search(r'```(?:json)?\s*([\s\S]*?)```', raw_response)
        json_text = json_match.group(1).strip() if json_match else raw_response.strip()

        # Try direct JSON parse
        try:
            parsed = json.loads(json_text)
        except json.JSONDecodeError:
            # Try to find a JSON object/array in the text
            brace_match = re.search(r'\{[\s\S]*\}', json_text)
            if brace_match:
                try:
                    parsed = json.loads(brace_match.group(0))
                except json.JSONDecodeError:
                    logger.warning("Could not parse vision response as JSON")
                    return []
            else:
                return []

        # Normalize: handle {"fields": [...]} or direct [...]
        fields_list = []
        if isinstance(parsed, dict):
            fields_list = parsed.get("fields", [])
        elif isinstance(parsed, list):
            fields_list = parsed

        # Validate and normalize each field
        result = []
        for field in fields_list:
            if not isinstance(field, dict):
                continue
            field_name = field.get("field_name", "")
            if not field_name:
                continue

            value = field.get("value")
            if isinstance(value, str):
                # Try to parse numeric strings (e.g. "143'287" → 143287)
                cleaned = value.replace("'", "").replace(" ", "").replace(",", ".")
                try:
                    value = float(cleaned)
                except ValueError:
                    value = None

            result.append({
                "field_name": field_name,
                "label": field.get("label", field_name),
                "value": value,
                "text_value": field.get("text_value") or field.get("source_text", ""),
                "confidence": 0.85,
                "source_text": field.get("source_text", ""),
            })

        return result

    @staticmethod
    def _estimate_confidence_delta(document_type: str, fields_count: int) -> int:
        """Estimate confidence score improvement from extracted fields."""
        base_deltas = {
            "lpp_certificate": 27,
            "tax_declaration": 17,
            "avs_extract": 22,
            "generic": 10,
        }
        base = base_deltas.get(document_type, 10)
        # Scale by extraction completeness (assume max ~10 fields)
        if fields_count == 0:
            return 0
        ratio = min(fields_count / 8, 1.0)
        return int(base * ratio)

    def _estimate_tokens(
        self,
        system_prompt: str,
        question: str,
        context_chunks: list[str],
        response: str,
    ) -> int:
        """
        Estimate token usage for the request.

        Uses tiktoken if available, otherwise a rough word-based approximation.
        """
        full_text = system_prompt + question + "".join(context_chunks) + response

        try:
            import tiktoken

            enc = tiktoken.encoding_for_model("gpt-4o")
            return len(enc.encode(full_text))
        except Exception:
            # Rough approximation: ~4 chars per token for European languages
            return len(full_text) // 4
