#!/usr/bin/env python3
"""Apply Phase 11-01 phrase rewrites to ARB × 6 locales + update mining JSON.

Plan 11-01 / VOICE-04. Reads REWRITES (defined below) and:
1. Updates each ARB key in app_{fr,en,de,es,it,pt}.arb in place.
2. Adds @meta sibling with `level` field. If a @meta sibling already exists,
   inserts the `level` field into it.
3. Updates tools/voice_corpus/phrase_mining_report.json with proposed_level,
   proposed_rewrite_fr, checkpoints (6 booleans + verdict).

Run: python3 tools/voice_corpus/apply_rewrites.py
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ARB_DIR = ROOT / "apps/mobile/lib/l10n"
LOCALES = ["fr", "en", "de", "es", "it", "pt"]
REPORT = ROOT / "tools/voice_corpus/phrase_mining_report.json"

# ----------------------------------------------------------------------------
# Rewrite payload
# ----------------------------------------------------------------------------
# Each entry: key -> {
#   level: "N1".."N5",
#   verdict: "rewrite" | "keep",
#   checkpoints: [bool*6]  # checkpoints 1..6
#   reason: short rationale
#   fr/en/de/es/it/pt: new strings (None if verdict=="keep" — no edit applied)
# }
#
# Anti-shame checkpoints (VOICE_CURSOR_SPEC §"anti-shame"):
# 1. No comparison to other users (past self only)
# 2. No data request without insight repayment
# 3. No injunctive verbs (2nd person) without conditional softening
# 4. No concept explanation before personal stake
# 5. No more than 2 screens between intent and first insight (flow proxy)
# 6. No error/empty state implying user "should" have something
#
# Sensitive topics (debt/death/divorce/job loss/illness) cap at N3 — none of
# the 30 mined phrases live inside a sensitive context, so no N3 cap applies.

REWRITES: dict[str, dict] = {
    # ── 1-6: intent chips (insight_opener / transition) ─────────────────────
    "intentChip3a": {
        "level": "N2", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Subject becomes the user's situation, not a sales-y framing. MINT will respond from the user's stake, not the offer's.",
        "fr": "On vient de me parler d'un 3a",
        "en": "Someone just brought up a 3a with me",
        "de": "Jemand hat gerade mit mir über eine 3a gesprochen",
        "es": "Alguien acaba de hablarme de un 3a",
        "it": "Qualcuno mi ha appena parlato di un 3a",
        "pt": "Alguém acabou de me falar de um 3a",
    },
    "intentChipFiscalite": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "'Bêtement' is mild self-deprecation that risks reading as shame. Replaced with a neutral, situated phrasing that keeps the directness without the self-blame.",
        "fr": "Mes impôts, j'aimerais y voir clair",
        "en": "I want to see clearly through my taxes",
        "de": "Bei meinen Steuern möchte ich klar sehen",
        "es": "Quiero ver claro en mis impuestos",
        "it": "Vorrei vederci chiaro sulle mie tasse",
        "pt": "Quero ver com clareza nos meus impostos",
    },
    "intentChipProjet": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Three-word user-voiced intent chip. No injunction, no comparison, no shame. Passes all checkpoints as-is.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "intentChipChangement": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Three-word user-voiced intent chip. Neutral, factual self-statement. No rewrite needed.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "intentChipAutre": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word fallback chip. Cannot carry shame. Passes trivially.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "intentChipPremierEmploi": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Three-word user-voiced intent chip. Names a life event without judgment.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },

    # ── 7-12: suggest questions (question category) ─────────────────────────
    "coachSuggestDeductions": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Original is fine but the verb 'récupérer' implies certainty. Conditional softening added to keep N3 register without absolutes.",
        "fr": "Combien je pourrais récupérer cette année\u00a0?",
        "en": "How much could I get back this year?",
        "de": "Wie viel könnte ich dieses Jahr zurückholen?",
        "es": "¿Cuánto podría recuperar este año?",
        "it": "Quanto potrei recuperare quest'anno?",
        "pt": "Quanto poderia recuperar este ano?",
    },
    "coachSuggestFitness": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "'Par rapport à mon objectif' is fine but the comparison frame can drift. Reframed to past-self, not absolute target.",
        "fr": "Je suis où, par rapport à ce que je m'étais dit\u00a0?",
        "en": "Where am I, compared to what I'd told myself?",
        "de": "Wo stehe ich im Vergleich zu dem, was ich mir vorgenommen hatte?",
        "es": "¿Dónde estoy, en comparación con lo que me había dicho?",
        "it": "A che punto sono, rispetto a quello che mi ero detto?",
        "pt": "Onde estou, em relação ao que tinha dito a mim mesmo?",
    },
    "coachSuggestRetirement": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "'Assez pour vivre' carries an implicit standard. Reframed as a question MINT can answer with the user's own data, without invoking a comparative threshold.",
        "fr": "À la retraite, il me restera quoi chaque mois\u00a0?",
        "en": "At retirement, what will I have left each month?",
        "de": "Im Ruhestand, was bleibt mir jeden Monat?",
        "es": "En la jubilación, ¿qué me quedará cada mes?",
        "it": "In pensione, cosa mi resterà ogni mese?",
        "pt": "Na reforma, o que me restará todos os meses?",
    },
    "coachSuggestSimulate3a": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Original mentions 'le max' which subtly implies 'you should'. Reframed as a neutral simulation request, keeping the same intent without the should-vector.",
        "fr": "Si je verse plus sur mon 3a, ça change quoi\u00a0?",
        "en": "If I put more into my 3a, what changes?",
        "de": "Wenn ich mehr in meine 3a einzahle, was ändert sich?",
        "es": "Si aporto más a mi 3a, ¿qué cambia?",
        "it": "Se verso di più sul mio 3a, cosa cambia?",
        "pt": "Se contribuir mais para o meu 3a, o que muda?",
    },
    "coachSilentOpenerQuestion": {
        "level": "N1", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Original is fine but adds MINT-as-subject framing to anchor the silent opener as a soft posture, not a demand.",
        "fr": "Mint est là quand tu veux en parler.",
        "en": "Mint is here whenever you want to talk about it.",
        "de": "Mint ist da, wann immer du darüber sprechen willst.",
        "es": "Mint está aquí cuando quieras hablar de ello.",
        "it": "Mint è qui quando vuoi parlarne.",
        "pt": "Mint está aqui quando quiseres falar disso.",
    },
    "coachSuggestScenarios": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "'Qu'est-ce qui me convient' invites a verdict from MINT, which is prescriptive. Reframed as a side-by-side comparison request — the doctrine permits arbitrage display, never ranking.",
        "fr": "Rente ou capital — montre-moi les deux côte à côte",
        "en": "Pension or capital — show me both side by side",
        "de": "Rente oder Kapital — zeig mir beide nebeneinander",
        "es": "Renta o capital — muéstrame los dos lado a lado",
        "it": "Rendita o capitale — mostrameli affiancati",
        "pt": "Renda ou capital — mostra-me ambos lado a lado",
    },

    # ── 13: input hint (greetings) ──────────────────────────────────────────
    "coachInputHint": {
        "level": "N2", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Open question is fine but slightly generic. Reframed with MINT-as-listener posture, no demand for a specific topic.",
        "fr": "Dis-moi ce qui te trotte dans la tête.",
        "en": "Tell me what's on your mind.",
        "de": "Sag mir, was dir durch den Kopf geht.",
        "es": "Dime qué te ronda por la cabeza.",
        "it": "Dimmi cosa ti passa per la testa.",
        "pt": "Diz-me o que te anda na cabeça.",
    },

    # ── 14-17: gate / sources (closing) — micro-labels ──────────────────────
    "coachGateSubtitle": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Factual feature label. No imperative, no shame vector. Passes.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachGateTitle": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Factual feature label.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachGateUnlock": {
        "level": "N2", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word CTA. No injunction toward the user — describes the action the button performs.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachSources": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Section label. Neutral.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },

    # ── 18-19: error_fallback ───────────────────────────────────────────────
    "coachBadgeFallback": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Status badge. Describes the system state, not the user.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachBriefingFallbackGreeting": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word fallback greeting. Cannot carry a shame vector.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },

    # ── 20-22: greetings + transition opener ────────────────────────────────
    "coachGreetingDefault": {
        "level": "N2", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Original is good but adopts MINT-as-subject phrasing more cleanly and removes the 'dis-moi' imperative in favor of a softer invitation.",
        "fr": "Salut {name}. Mint regarde tes chiffres tranquillement — quand tu veux, on en parle.{scoreSuffix}",
        "en": "Hi {name}. Mint is looking through your numbers calmly — whenever you want, we can talk about it.{scoreSuffix}",
        "de": "Hallo {name}. Mint schaut sich deine Zahlen in Ruhe an — wann immer du willst, sprechen wir darüber.{scoreSuffix}",
        "es": "Hola {name}. Mint mira tus cifras con calma — cuando quieras, hablamos de ello.{scoreSuffix}",
        "it": "Ciao {name}. Mint guarda i tuoi numeri con calma — quando vuoi, ne parliamo.{scoreSuffix}",
        "pt": "Olá {name}. Mint está a olhar para os teus números com calma — quando quiseres, falamos disso.{scoreSuffix}",
    },
    "greetingMorning": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word greeting.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachOpenerIntentChangement": {
        "level": "N2", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "MINT-as-subject phrasing reinforced. Conditional 'aurait' removes any implicit verdict on what was found.",
        "fr": "Tu vis un changement\u00a0— Mint a regardé ce que ça pourrait toucher, sans rien décider à ta place.",
        "en": "You're going through a change — Mint has looked at what it might touch, without deciding anything for you.",
        "de": "Du machst eine Veränderung durch — Mint hat geschaut, was sie betreffen könnte, ohne etwas für dich zu entscheiden.",
        "es": "Estás viviendo un cambio — Mint ha mirado lo que podría afectar, sin decidir nada por ti.",
        "it": "Stai vivendo un cambiamento — Mint ha guardato cosa potrebbe toccare, senza decidere nulla al posto tuo.",
        "pt": "Estás a viver uma mudança — Mint olhou para o que pode tocar, sem decidir nada por ti.",
    },

    # ── 23-26: badges (validation) — micro-labels ───────────────────────────
    "coachBadgeByok": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word system badge.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachBadgeSlm": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word system badge.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachBriefingBadge": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Single-word badge.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },
    "coachBriefingBadgeLlm": {
        "level": "N1", "verdict": "keep",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Two-word system badge.",
        "fr": None, "en": None, "de": None, "es": None, "it": None, "pt": None,
    },

    # ── 27: warning — CRITICAL — contains banned term 'garantie' ────────────
    "coachInterruptFullCapitalRisk": {
        "level": "N4", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "P0 fix: original contained banned term 'garanti' (CLAUDE.md §6). Rewritten as MINT-as-subject factual observation, hedged with conditional, no absolutes, no shame vector. N4 because it's a verified-fact warning (the user has already chosen 100% capital).",
        "fr": "Mint observe\u00a0: 100\u00a0% en capital, c'est zéro rente mensuelle à vie. Tu veux qu'on regarde ce que ça implique\u00a0?",
        "en": "Mint notices: 100% as capital means no monthly pension for life. Want to look at what that implies?",
        "de": "Mint bemerkt: 100\u00a0% als Kapital bedeutet keine monatliche Rente auf Lebenszeit. Möchtest du anschauen, was das bedeutet?",
        "es": "Mint observa: 100\u00a0% en capital significa cero renta mensual de por vida. ¿Quieres que veamos qué implica?",
        "it": "Mint osserva: 100\u00a0% in capitale significa zero rendita mensile a vita. Vuoi che guardiamo cosa implica?",
        "pt": "Mint observa: 100\u00a0% em capital significa zero renda mensal para toda a vida. Queres que vejamos o que isso implica?",
    },

    # ── 28: greeting — check-in welcome ─────────────────────────────────────
    "coachCheckInWelcome": {
        "level": "N2", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Original is good. Strengthened with MINT-as-subject and removed the implicit 'on' that obscures who is leading. Invitation, not demand.",
        "fr": "Salut\u00a0! Mint est là. Quand tu veux, on regarde ensemble ce qui compte ce mois-ci.",
        "en": "Hi! Mint is here. Whenever you want, we look together at what matters this month.",
        "de": "Hallo! Mint ist da. Wann immer du willst, schauen wir gemeinsam, was diesen Monat zählt.",
        "es": "¡Hola! Mint está aquí. Cuando quieras, miramos juntos lo que importa este mes.",
        "it": "Ciao! Mint è qui. Quando vuoi, guardiamo insieme cosa conta questo mese.",
        "pt": "Olá! Mint está aqui. Quando quiseres, olhamos juntos para o que importa este mês.",
    },

    # ── 29-30: disclaimers (warning) ────────────────────────────────────────
    "coachDisclaimer": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Compliance content kept verbatim per LSFin art. 3, but reframed with MINT-as-subject opening to make the disclaimer feel like Mint's posture rather than a legal-bottom-of-page boilerplate.",
        "fr": "Mint éclaire, Mint n'avise pas. Les réponses ici sont éducatives et ne constituent pas un conseil financier au sens de la LSFin (art. 3). Pour une décision importante, parle à un·e spécialiste.",
        "en": "Mint sheds light, Mint does not advise. Answers here are educational and do not constitute financial advice under FinSA (art. 3). For an important decision, talk to a specialist.",
        "de": "Mint erhellt, Mint berät nicht. Die Antworten hier sind bildend und stellen keine Finanzberatung im Sinne des FIDLEG (Art. 3) dar. Für wichtige Entscheidungen, sprich mit einer Fachperson.",
        "es": "Mint aclara, Mint no aconseja. Las respuestas aquí son educativas y no constituyen asesoramiento financiero en el sentido de la LSFin (art. 3). Para una decisión importante, habla con un·a especialista.",
        "it": "Mint illumina, Mint non consiglia. Le risposte qui sono educative e non costituiscono consulenza finanziaria ai sensi della LSerFi (art. 3). Per una decisione importante, parla con un·a specialista.",
        "pt": "Mint esclarece, Mint não aconselha. As respostas aqui são educativas e não constituem aconselhamento financeiro no sentido da LSFin (art. 3). Para uma decisão importante, fala com um·a especialista.",
    },
    "coachPulseDisclaimer": {
        "level": "N3", "verdict": "rewrite",
        "checkpoints": [True, True, True, True, True, True],
        "reason": "Same MINT-as-subject reframing as the main disclaimer. Compliance content (LSFin, past returns warning) preserved verbatim.",
        "fr": "Mint éclaire, Mint ne promet rien. Les estimations ici sont éducatives et ne constituent pas un conseil financier. Les rendements passés ne présagent pas des rendements futurs. Pour un plan personnalisé, parle à un·e spécialiste. LSFin.",
        "en": "Mint sheds light, Mint promises nothing. Estimates here are educational and do not constitute financial advice. Past returns do not predict future returns. For a personalized plan, talk to a specialist. FinSA.",
        "de": "Mint erhellt, Mint verspricht nichts. Die Schätzungen hier sind bildend und stellen keine Finanzberatung dar. Vergangene Renditen sind kein Indikator für zukünftige Renditen. Für einen personalisierten Plan, sprich mit einer Fachperson. FIDLEG.",
        "es": "Mint aclara, Mint no promete nada. Las estimaciones aquí son educativas y no constituyen asesoramiento financiero. Los rendimientos pasados no presuponen rendimientos futuros. Para un plan personalizado, habla con un·a especialista. LSFin.",
        "it": "Mint illumina, Mint non promette nulla. Le stime qui sono educative e non costituiscono consulenza finanziaria. I rendimenti passati non sono indicativi di quelli futuri. Per un piano personalizzato, parla con un·a specialista. LSerFi.",
        "pt": "Mint esclarece, Mint não promete nada. As estimativas aqui são educativas e não constituem aconselhamento financeiro. Os rendimentos passados não pressupõem rendimentos futuros. Para um plano personalizado, fala com um·a especialista. LSFin.",
    },
}


# ----------------------------------------------------------------------------
# ARB editor
# ----------------------------------------------------------------------------

def update_arb(locale: str) -> tuple[int, int]:
    """Update one ARB file. Returns (values_replaced, meta_inserted)."""
    path = ARB_DIR / f"app_{locale}.arb"
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    new_lines: list[str] = []
    values_replaced = 0
    meta_inserted = 0
    skip_existing_meta_for: dict[str, str] = {}  # key -> level (for keys with existing @meta block)

    # First pass: locate existing @meta blocks for our keys, prepare to inject `level`
    keys_with_existing_meta: dict[str, tuple[int, int]] = {}  # key -> (start_idx, end_idx)
    for i, line in enumerate(lines):
        for k in REWRITES:
            if line.lstrip().startswith(f'"@{k}"'):
                # find end of this object: balance braces from this line
                depth = 0
                for j in range(i, len(lines)):
                    depth += lines[j].count("{") - lines[j].count("}")
                    if depth == 0 and j > i:
                        keys_with_existing_meta[k] = (i, j)
                        break
                break

    # Second pass: rewrite the file
    i = 0
    while i < len(lines):
        line = lines[i]
        matched_key = None
        matched_value = None
        # Try to match a value line for any of our keys
        for k, payload in REWRITES.items():
            new_val = payload.get(locale)
            if new_val is None:
                continue  # keep — no value rewrite
            # Match: leading spaces "key": "....",
            m = re.match(rf'^(\s*)"{re.escape(k)}"\s*:\s*"((?:[^"\\]|\\.)*)"(\s*,?\s*)$', line)
            if m:
                matched_key = k
                indent = m.group(1)
                trailing = m.group(3)
                # Re-encode JSON string (escape backslashes, quotes, newlines)
                escaped = json.dumps(new_val, ensure_ascii=False)  # adds quotes
                line = f'{indent}"{k}": {escaped}{trailing}'
                values_replaced += 1
                break

        new_lines.append(line)

        # After writing the value line, check if we need to insert @meta sibling
        if matched_key and matched_key not in keys_with_existing_meta:
            level = REWRITES[matched_key]["level"]
            # Determine if next non-blank line already starts with @key
            next_idx = i + 1
            already = False
            if next_idx < len(lines):
                if lines[next_idx].lstrip().startswith(f'"@{matched_key}"'):
                    already = True
            if not already:
                indent = re.match(r"^(\s*)", line).group(1)
                meta_block = (
                    f'{indent}"@{matched_key}": {{\n'
                    f'{indent}  "x-mint-meta": {{ "level": "{level}", "phase": "11-01" }}\n'
                    f'{indent}}},\n'
                )
                new_lines.append(meta_block)
                meta_inserted += 1
        i += 1

    # For keys with existing @meta, we need to inject "x-mint-meta" inside.
    # Re-scan our buffer and patch.
    final_text = "".join(new_lines)
    for k, _ in keys_with_existing_meta.items():
        if k not in REWRITES:
            continue
        level = REWRITES[k]["level"]
        # Inject "x-mint-meta" right after the opening brace of "@k": {
        pattern = re.compile(rf'("@{re.escape(k)}"\s*:\s*\{{)(\s*\n)', re.MULTILINE)
        replacement = (
            rf'\1\2'
            + f'    "x-mint-meta": {{ "level": "{level}", "phase": "11-01" }},\n'
        )
        new_text, n = pattern.subn(replacement, final_text, count=1)
        if n:
            final_text = new_text
            meta_inserted += 1

    # Also add @meta for KEEP entries (level annotation only — no value change happened)
    # We need to find their value lines and inject @meta after, if not already present.
    for k, payload in REWRITES.items():
        if payload["verdict"] != "keep":
            continue
        if k in keys_with_existing_meta:
            level = payload["level"]
            pattern = re.compile(rf'("@{re.escape(k)}"\s*:\s*\{{)(\s*\n)(?!\s*"x-mint-meta")', re.MULTILINE)
            new_text, n = pattern.subn(
                rf'\1\2    "x-mint-meta": {{ "level": "{level}", "phase": "11-01" }},\n',
                final_text, count=1,
            )
            if n:
                final_text = new_text
                meta_inserted += 1
            continue
        # Find the value line, inject @meta sibling after it
        level = payload["level"]
        # Match the standalone value line, then check if @key already follows
        value_re = re.compile(
            rf'(^(\s*)"{re.escape(k)}"\s*:\s*"(?:[^"\\]|\\.)*"\s*,?\s*\n)((?!\s*"@{re.escape(k)}")|)',
            re.MULTILINE,
        )
        # Simpler approach: find the value line, capture indent, inject if not followed by @key
        m = re.search(
            rf'^(?P<indent>\s*)"{re.escape(k)}"\s*:\s*"(?:[^"\\]|\\.)*"\s*,?\s*\n',
            final_text, re.MULTILINE,
        )
        if not m:
            continue
        end = m.end()
        # Check next line
        next_chunk = final_text[end:end + 200]
        if next_chunk.lstrip().startswith(f'"@{k}"'):
            continue
        indent = m.group("indent")
        injection = (
            f'{indent}"@{k}": {{\n'
            f'{indent}  "x-mint-meta": {{ "level": "{level}", "phase": "11-01" }}\n'
            f'{indent}}},\n'
        )
        final_text = final_text[:end] + injection + final_text[end:]
        meta_inserted += 1

    path.write_text(final_text, encoding="utf-8")
    return values_replaced, meta_inserted


def update_report():
    """Patch phrase_mining_report.json with the rewrites."""
    data = json.loads(REPORT.read_text(encoding="utf-8"))
    for entry in data["phrases"]:
        rw = REWRITES.get(entry["id"])
        if not rw:
            continue
        entry["proposed_level"] = rw["level"]
        entry["verdict"] = rw["verdict"]
        entry["proposed_rewrite_fr"] = rw.get("fr") if rw["verdict"] == "rewrite" else entry["current_fr"]
        entry["checkpoints"] = {
            "1_no_user_comparison": rw["checkpoints"][0],
            "2_insight_repayment": rw["checkpoints"][1],
            "3_conditional_softening": rw["checkpoints"][2],
            "4_personal_stake_first": rw["checkpoints"][3],
            "5_intent_to_insight_proximity": rw["checkpoints"][4],
            "6_no_should_in_empty_state": rw["checkpoints"][5],
            "overall_pass": all(rw["checkpoints"]),
        }
        entry["reason"] = rw["reason"]
    REPORT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    print("Updating ARBs...")
    for loc in LOCALES:
        v, m = update_arb(loc)
        print(f"  {loc}: replaced {v} values, inserted {m} @meta blocks")
    print("Updating mining report...")
    update_report()
    print("Done.")


if __name__ == "__main__":
    main()
