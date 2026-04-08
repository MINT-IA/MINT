# Regional Voice Validators — Coordination Protocol

> MINT v2.2 "La Beauté de Mint" — Phase 6 L1.4 Voix Régionale VS/ZH/TI
> REQ REGIONAL-06 — native validator sign-off coordinated with Phase 11 Krippendorff tester pool
> Companion to: `docs/VOICE_PASS_LAYER1.md` Phase 6 Regional Sign-off section, `CLAUDE.md` §7 Regional Swiss Voice Identity

---

## 1. Purpose

Before Phase 6 ships the ~90 regional microcopy strings (≈30 keys × VS/ZH/TI), each canton's strings MUST be signed off by at least one native speaker of that canton. The validator's single job: confirm the regional flavor reads as a **subtle inside joke a local would smile at**, not a **cosplay caricature a local would cringe at**.

Per audit fix B2, Phase 6 does **NOT** run its own recruitment stream. It piggybacks the Phase 11 Krippendorff tester pool (VOICE-05, 15 testers recruited under ACCESS-01 budget). One pool, multiple tasks, zero duplicate outreach, zero duplicate compensation.

This document is the single source of truth for: (a) pool coordination, (b) the native validator review rubric, (c) the sign-off protocol, (d) the anti-caricature red lines, (e) the failure path when a canton has no native.

---

## 2. Pool coordination

**Principle:** one tester pool, multiple tasks. The Phase 11 pool already exists for Krippendorff inter-rater validation of the voice cursor (VOICE-05). Phase 6 adds a second task for the subset of that pool who are natives of VS, ZH, or TI.

**Requirements on the Phase 11 pool:**

- **At least 1 VS native** (Romand, ideally Valaisan·ne — FR/VS/JU/NE acceptable as Romande proxies per `_CANTON_TO_PRIMARY` mapping, but Valais preferred for VS-specific tonal nuance).
- **At least 1 ZH native** (Deutschschweizer·in — ZH/BE/LU/AG/ZG/SG acceptable as Deutschschweiz proxies; Zürich preferred for urban finance-savvy tone).
- **At least 1 TI native** (Ticinese — native Italian-Swiss, lake/grotto cultural fluency).

**Recruiter responsibility.** During Phase 1 ACCESS-01 kickoff (the Phase 11 recruitment wave), the recruiter (Julien or assignee) flags the VS/ZH/TI native requirement to Phase 11 recruitment intake. The same tester signs off on both:

1. Their Krippendorff phrase-rating batch (Phase 11 VOICE-05 task), and
2. The 30 regional strings for their home canton (Phase 6 REGIONAL-06 task).

**Compensation.** Bundled into the Phase 11 CHF 800–2'000 envelope under ACCESS-01. No separate Phase 6 line item. A validator doing both tasks is not double-paid — the rate covers both tasks as one sitting.

**Tracking.** See §5 Tracker below. Mirrors the `ACCESSIBILITY_TEST_LAYER1.md` ACCESS-01 recruitment tracker pattern exactly.

---

## 3. Review rubric

This rubric is the checklist the native validator fills in per canton. Plan 06-03 Task 3 (checkpoint) copies this rubric verbatim into its human-verify block.

For each of the ~30 regional strings, the validator marks **one** of:

- **PASS** — sounds naturally local. A local would read it and feel seen, not performed-at.
- **SOFTEN** — in the right direction but dialed too high. Tone it down 1–2 notches.
- **REPLACE** — wrong register or wrong vibe. Suggest a native alternative.
- **REMOVE** — nothing regional about this string lands naturally. Drop the override; fall back to base ARB.

On top of the per-string verdicts, the validator answers these **5 global questions** per canton:

1. **Naturalness** — Does the set of strings sound like the way people from this canton actually talk when they want to be warm, dry, or precise — or does it sound like an app pretending to be local?
2. **Inside-joke test** — Would a local read one of these strings, smile, and think "OK, this app actually knows my region"? Or would they think "this is cosplay"?
3. **Caricature check** — Is any expression a stereotype a local would cringe at? (See §4 red lines.)
4. **Anti-shame check** — Does any string shame speakers of **other** regions, or assume the user of this canton holds superiority over other Swiss? (Per CLAUDE.md §7 and the MINT anti-shame doctrine — a ZH string must never mock Romands, a TI string must never mock Alemanni, a VS string must never mock Genevois, etc.)
5. **Voice cursor compatibility** — Phase 6 targets voice cursor level N3 (default intensity). Does each regional string still feel correct at N3 — not too flat (would need N4), not too spicy (would need N2)?

And these **2 compliance gates** (hard fail if either is "no"):

6. **Banned terms** — Does any string contain a CLAUDE.md §6 banned term ("garanti", "meilleur", "optimal", "sans risque", "conseiller", etc.)?
7. **Prescriptive advice** — Does any string give a specific product recommendation, tell the user what to do imperatively, or violate the protection-first read-only posture?

Any "yes" on 6 or 7 = automatic REMOVE on that string, no discussion.

**Job boundary.** The validator judges **only their own canton's strings**. They are never asked to grade VS strings if they're Ticinese, or ZH strings if they're Romand. This is the anti-shame doctrine applied to the validators themselves: we do not put a Valaisan in a position of judging what's "right" for Zürich.

---

## 4. Anti-caricature red lines

Explicit examples of what a validator must reject (REPLACE or REMOVE). Non-exhaustive, but these are the patterns seen in caricature-prone regional copy and MUST be flagged:

**VS (Romande / Valais)**
- "Salut chef, ça va?" as a default greeting — cosplay montagnard stereotype.
- "Chez nous, en Valais…" as a superior marker — violates anti-shame doctrine.
- Heavy use of "septante/nonante" when the string is already natively Romand — the numbers are a tell only when they land contextually, not sprinkled for flavor.
- Any reference to raclette, fondue, or mountains as tone-setters in non-food strings.
- Any caricature of the "honest mountain peasant" persona.

**ZH (Deutschschweiz)**
- Heavy Mundart/Schwyzerdütsch in an ARB whose base language is de-CH Hochdeutsch. D-04 locks base = de-CH. Regional tone is a light coloring, not a dialect swap. Mundart belongs in TTS (Phase 4), not in ARB keys.
- "Grüezi, wie goht's?" as a greeting if the rest of the string is standard Hochdeutsch — register clash.
- Stereotyped "Zürich finance-bro" phrasing ("Bro, dein Portfolio…") — violates CLAUDE.md §6 tone requirements.
- Any reference to punctuality, thrift, or rule-following as tone-setters — these are stereotypes, not regional voice.
- "Znüni" used outside of an actual morning context.

**TI (Svizzera Italiana)**
- Italian food/family stereotypes in **every other string**. A single grotto reference in one empty-state is charming; grotto/nonna/famiglia references across the 30 keys is cringe.
- "Ciao bello/bella" as an opening line — cosplay Mediterraneo.
- Pasta, vino, or lake references injected where the string is about retirement, tax, or LPP — register clash.
- Any "come diciamo noi in Ticino…" superior marker.
- Conflating Italian-Italian idioms with Swiss-Italian register — the TI voice is Swiss first, Italian-flavored second.

**Cross-canton (applies to all three)**
- Any "chez nous on dit…" / "bei uns sagt man…" / "da noi si dice…" superior-marker phrasing. The regional voice colors; it does not flag belonging.
- Any string that only makes sense if the user already identifies with the region — regional voice must remain comprehensible to a non-local reading it.
- Any emoji or emoji-substitute used to signal regional belonging (flags, mountains, gondolas, etc.).
- Any joke that mocks another canton or linguistic region.

---

## 5. Sign-off protocol

Step-by-step. The recruiter or Plan 06-03 Task 3 executor runs this.

1. **Extract** the final list of the 30 regional keys for one canton from `apps/mobile/lib/l10n_regional/app_regional_{vs|zh|ti}.arb`. Produce a plain-text or Markdown list of `key → override string` pairs.
2. **Send** the list to the named validator via email or the agreed secure channel. Include: this rubric (§3), the red lines (§4), and the compliance gates.
3. **Validator annotates** each string with PASS / SOFTEN / REPLACE / REMOVE plus a free-text comment where needed. Validator answers the 5 global questions and 2 compliance gates.
4. **Validator signs off** by replying with their full name and ISO date (`YYYY-MM-DD`). That reply is the canonical record.
5. **Append** the signature line to `docs/VOICE_PASS_LAYER1.md` under `## Phase 6 Regional Sign-off`, format:
   `- VS: <name>, <YYYY-MM-DD>, <n>/30 PASS, <n> SOFTEN, <n> REPLACE, <n> REMOVE`
6. **Iterate** on any SOFTEN or REPLACE verdict. Re-run the string through the validator **once** if the iteration is non-trivial. Avoid infinite ping-pong — if after one iteration the validator still isn't satisfied, REMOVE the string and fall back to the base ARB key.
7. **Apply** REMOVE verdicts directly: delete the override key from the regional ARB. Base ARB fallback per D-04 handles it silently.
8. **Hard gate.** If by the time Plan 06-03 Task 3 is ready to ship, a canton has **no native** in the Phase 11 pool **or** no sign-off received:
   - Ship that canton's ARB with a `// UNVALIDATED — Phase 6 v2.2` header comment on line 2 (after the locale-lock line).
   - Carry REQ REGIONAL-06 to v2.3 for that specific canton.
   - Escalate to the user (Julien) before merging Plan 06-03 — do NOT silently ship unvalidated regional voice. Never fake a sign-off.

---

## 6. Tracker

Mirrors `docs/ACCESSIBILITY_TEST_LAYER1.md` ACCESS-01 tracker. Filled in as Phase 11 recruitment lands and Phase 6 sign-offs come back.

| # | Canton | Pool source | Validator name | Contact | Date sent | Review received | Disposition | VOICE_PASS_LAYER1 line |
|---|--------|-------------|----------------|---------|-----------|-----------------|-------------|------------------------|
| 1 | VS     | Phase 11 Krippendorff pool | —              | —       | —         | —               | PENDING     | — |
| 2 | ZH     | Phase 11 Krippendorff pool | —              | —       | —         | —               | PENDING     | — |
| 3 | TI     | Phase 11 Krippendorff pool | —              | —       | —         | —               | PENDING     | — |

**Disposition values:** PENDING → SENT → REVIEWED → SIGNED-OFF (or UNVALIDATED if hard gate triggers).

**Instructions for Julien / recruiter:**
1. When Phase 11 ACCESS-01 recruitment confirms a VS/ZH/TI native, fill the corresponding row's `Validator name` and `Contact` columns.
2. When Plan 06-03 sends the 30-string list for review, set `Date sent` (ISO) and flip disposition to `SENT`.
3. When the validator replies, set `Review received` and flip to `REVIEWED`.
4. After iteration and final sign-off, flip to `SIGNED-OFF` and paste the line from `VOICE_PASS_LAYER1.md` into the last column.
5. If the hard gate triggers for a canton, flip to `UNVALIDATED` and escalate to Julien before merging Plan 06-03.

---

## 7. Recruitment email template

Use when flagging the VS/ZH/TI native requirement to Phase 11 recruitment intake, or when reaching out directly to a candidate already in the pool. Three variants: French (VS), German (ZH), Italian (TI).

### FR (VS)

> Bonjour <Prénom>,
>
> Merci d'avoir accepté de participer au panel MINT (validation Phase 11). En plus de la tâche principale (notation de phrases pour mesurer la cohérence du curseur de voix), on aimerait te solliciter pour une **deuxième micro-tâche**, incluse dans la même rémunération.
>
> MINT ajoute une coloration régionale très légère à son langage pour les utilisateur·ices des cantons VS, ZH et TI. On a besoin d'une personne native du Valais pour **relire ~30 phrases** et nous dire, pour chacune : est-ce que ça sonne comme un·e Valaisan·ne le dirait, ou est-ce que c'est du cosplay montagnard ? Temps estimé : 30 à 45 minutes.
>
> La grille de lecture, les "lignes rouges" (ce qu'on veut éviter), et le protocole de sign-off sont dans un document court qu'on te transmet avec les phrases.
>
> Tu juges uniquement les phrases VS, jamais celles des autres régions. Si tu es d'accord, réponds juste "OK + Phase 6 VS" et on t'envoie la liste dès que Plan 06-03 est prêt.
>
> Merci beaucoup — Mint

### DE (ZH)

> Hallo <Vorname>,
>
> Danke, dass du beim MINT-Panel (Phase 11 Validierung) mitmachst. Zusätzlich zur Hauptaufgabe (Sätze bewerten, um die Konsistenz des Voice-Cursors zu messen) möchten wir dich für eine **zweite Mikro-Aufgabe** anfragen, die in der gleichen Vergütung enthalten ist.
>
> MINT fügt für Nutzer·innen aus VS, ZH und TI eine sehr leichte regionale Färbung hinzu. Wir brauchen eine Person aus dem Raum Zürich / Deutschschweiz, um **~30 Sätze durchzulesen** und uns pro Satz zu sagen: klingt das wie jemand aus der Deutschschweiz es sagen würde, oder klingt es wie eine App, die so tut als ob? Geschätzter Aufwand: 30 bis 45 Minuten.
>
> Die Bewertungsgrille, die "roten Linien" (was wir unbedingt vermeiden wollen) und das Sign-off-Protokoll sind in einem kurzen Dokument, das wir dir mit den Sätzen zusenden.
>
> Du beurteilst nur die ZH-Sätze, niemals die der anderen Regionen. Wenn das für dich passt, antworte einfach "OK + Phase 6 ZH" — sobald Plan 06-03 bereit ist, schicken wir dir die Liste.
>
> Danke dir — Mint

### IT (TI)

> Ciao <Nome>,
>
> Grazie per aver accettato di partecipare al panel MINT (validazione Fase 11). Oltre al compito principale (valutazione di frasi per misurare la coerenza del cursore vocale), vorremmo chiederti un **secondo micro-compito**, incluso nella stessa compensazione.
>
> MINT aggiunge una leggerissima colorazione regionale per chi vive in VS, ZH o TI. Ci serve una persona ticinese per **rileggere ~30 frasi** e dirci, per ciascuna: suona come lo direbbe davvero qualcuno del Ticino, o sembra un'app che fa finta? Tempo stimato: 30–45 minuti.
>
> La griglia di valutazione, le "linee rosse" (quello che vogliamo assolutamente evitare) e il protocollo di sign-off sono in un breve documento che ti mandiamo assieme alle frasi.
>
> Valuti solo le frasi TI, mai quelle delle altre regioni. Se ti va bene, rispondi semplicemente "OK + Phase 6 TI" e ti mandiamo la lista appena Plan 06-03 è pronto.
>
> Grazie mille — Mint

---

## 8. Failure path — `// UNVALIDATED` marker

If any canton has no native validator sign-off by the end of Phase 8b (hard deadline per ROADMAP):

1. The canton's ARB file receives a `// UNVALIDATED — Phase 6 v2.2` header comment on line 2 (immediately after the `// LOCALE-LOCKED: <base-lang>` header required by D-01).
2. The canton's entry in the `## Phase 6 Regional Sign-off` section of `docs/VOICE_PASS_LAYER1.md` is written as `- <CANTON>: UNVALIDATED, carried to v2.3, see REGIONAL_VOICE_VALIDATORS.md §8`.
3. REQ REGIONAL-06 is marked partial in `REQUIREMENTS.md` and the specific canton is carried to v2.3.
4. Julien is escalated to **before** Plan 06-03 merges. The decision to ship unvalidated is explicit, not silent. Julien decides: ship unvalidated, delay Plan 06-03, or drop that canton from v1 entirely.

Never fake a sign-off. Never write a placeholder name. Never auto-approve from Claude's side — the whole point of this protocol is an actual human native confirming the voice doesn't caricature their region.

---

## 9. Links

- `docs/VOICE_PASS_LAYER1.md` — Phase 6 Regional Sign-off section (where sign-off lines land)
- `docs/ACCESSIBILITY_TEST_LAYER1.md` — ACCESS-01 recruitment tracker pattern (this doc mirrors it)
- `CLAUDE.md` §7 — Regional Swiss Voice Identity (doctrine this protocol enforces)
- `CLAUDE.md` §6 — Compliance rules (banned terms, no-advice, no-ranking)
- `.planning/phases/06-l1.4-voix-regionale/CONTEXT.md` — Phase 6 locked decisions, notably D-08 (pool coordination) and D-10 (anti-shame / anti-caricature)
- `.planning/phases/11-.../` — Phase 11 VOICE-05 Krippendorff pool (the pool this piggybacks on)
- `feedback_regional_voice_identity.md` (MEMORY) — "subtle like an inside joke between locals, never caricature"
- `feedback_anti_shame_situated_learning.md` (MEMORY) — anti-shame doctrine applied to validators themselves

---

*Created: 2026-04-07 — Phase 6 Plan 06-04, REQ REGIONAL-06.*
