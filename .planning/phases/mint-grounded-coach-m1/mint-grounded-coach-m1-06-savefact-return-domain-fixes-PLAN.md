---
phase: mint-grounded-coach-m1
plan: 06
type: execute
wave: 5
depends_on:
  - mint-grounded-coach-m1-05-explain-concept-forced-tool
files_modified:
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/app/services/regulatory/registry.py
  - apps/mobile/lib/widgets/coach/widget_renderer.dart
  - apps/mobile/lib/models/coach_profile.dart
  - services/backend/tests/test_coach_chat_savefact_return.py
  - services/backend/tests/test_registry_avs_age.py
  - apps/mobile/test/widgets/coach/savefact_echo_test.dart
autonomous: true
requirements: [WS-D]
must_haves:
  truths:
    - "A fact extracted in chat is echoed back to the mobile client so the local profile can update"
    - "avs.reference_age_women is 64.5 for 2026 (transition value), not the AVS21 endpoint 65"
    - "The mobile widget_renderer applies the save_fact echo to the local CoachProfile"
  artifacts:
    - path: "services/backend/app/services/regulatory/registry.py"
      provides: "Correct 2026 AVS women reference age"
      contains: "reference_age_women"
  key_links:
    - from: "coach_chat.py save_fact"
      to: "flutter_tool_calls echo"
      via: "value returned to mobile"
      pattern: "save_fact"
    - from: "widget_renderer.dart"
      to: "CoachProfile update"
      via: "save_fact echo case"
      pattern: "save_fact"
---

<objective>
Close the minimal split-brain (CONTEXT WS-D — NOT the full event-log cutover, that is M2)
and land the AVS women reference-age domain fix. Today save_fact writes to the backend DB
blob but is filtered out of flutter_tool_calls (INTERNAL_TOOL_NAMES, coach_tools.py:104), so
the "50 ans" said in chat never reaches the local CoachProfile the screens read (audit 04
§1.3 P0-bis, W1 WTF-W1-04). Echo the extracted fact value back to mobile so the local profile
can update. Separately, fix avs.reference_age_women 65.0 → 64.5 for 2026 (audit 01 DET-1).

Purpose: the quick-fix that makes "ça apprend avec toi" partially true now, without the M2
spine rewrite. Scope OUT explicitly: no event-log cutover, no dual-write flag, no new write
endpoint — just echo the value on the HTTP response.
Output: save_fact echo path + mobile apply + AVS age fix; backend + mobile suites green.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md
@.planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md
@./CLAUDE.md

<interfaces>
Exact anchors (read in context — do NOT re-explore):
- coach_chat.py:104 INTERNAL_TOOL_NAMES includes "save_fact" → it is filtered from
  flutter_tool_calls at :4314-4362, so the value never reaches mobile. The minimal fix is
  NOT to make save_fact a normal external tool (it still persists internally) but to ADD a
  lightweight echo: when _persist_extracted_fact (coach_chat.py:2380) succeeds, append a
  forward-safe echo entry to flutter_tool_calls (e.g. a "fact_saved" confirmation carrying
  {key, value}) so the mobile can update its local store. Keep the internal persistence.
- coach_chat.py:2380 _persist_extracted_fact(...) returns ok bool (:2630). The whitelist of
  echo-able keys must match the existing persist whitelist (coach_chat.py:2099 region) — do
  NOT echo PII beyond the already-persisted profile fields. Privacy: unknown fields dropped.
- widget_renderer.dart:62-81 switch — add a case for the echo tool name ("fact_saved") that
  updates CoachProfileProvider/CoachProfile with the {key,value}. The field-key mapping
  already exists at widget_renderer.dart:345-431 (name/age/salaireBrut/avoirLpp/epargne3a/
  canton/...). Reuse it — do not invent a parallel mapping.
- coach_profile.dart — CoachProfile is the local SecureStorage model the screens read.
  Update via the existing provider write path (do not add a new store).
- registry.py:502-512 avs.reference_age_women value=65.0 → 64.5. Update the value and the
  description to note the 2026 transition (born 1962 → 64.5 in 2026, reaches 65 in 2028).
  Keep source fields. This is a pure constant fix — no calc change (NEVER #3).

Scope guard (CONTEXT scope OUT): do NOT introduce FF_FACT_EVENT_DUAL_WRITE, an event-log
write, or a new canonical write endpoint here. Echo-on-response only. The confirmation-UX
card (audit 04 §3.d) is M2 — here the echo updates the local store directly (minimal).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: AVS women reference-age domain fix (2026)</name>
  <files>services/backend/app/services/regulatory/registry.py, services/backend/tests/test_registry_avs_age.py</files>
  <behavior>
    - registry resolve for avs.reference_age_women returns 64.5 (2026 transition value).
    - avs.reference_age_men stays 65.0 (unchanged).
    - description notes the AVS21 transition; source fields preserved.
  </behavior>
  <action>Edit registry.py:503-504 value 65.0 → 64.5 and update the description prose (correct accents, neutral language). Write test_registry_avs_age.py asserting women=64.5, men=65.0, and the description references the 2026 transition. No banned term.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_registry_avs_age.py -q 2>&1 | tail -8</automated>
  </verify>
  <done>Women reference age 64.5 for 2026; men unchanged; test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Echo save_fact value back to mobile (backend)</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py, services/backend/tests/test_coach_chat_savefact_return.py</files>
  <behavior>
    - When _persist_extracted_fact succeeds for a whitelisted key, the HTTP response's
      tool_calls includes a forward-safe "fact_saved" echo entry carrying {key, value}.
    - save_fact still persists internally (no behaviour removed) — the echo is additive.
    - Non-whitelisted / PII keys are NOT echoed (privacy parity with the persist whitelist).
  </behavior>
  <action>In coach_chat.py, after a successful _persist_extracted_fact (:2592/:2630 paths), append a "fact_saved" echo to flutter_tool_calls with the same key/value, gated by the existing persist whitelist (:2099 region). Keep save_fact in INTERNAL_TOOL_NAMES (internal persistence intact) — the echo is a separate forward-safe confirmation entry, not un-internalising save_fact. Write test_coach_chat_savefact_return.py: a declared age yields a fact_saved echo with {age, value} in tool_calls; a non-whitelisted field is not echoed; internal persistence still occurs.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_chat_savefact_return.py -q 2>&1 | tail -10</automated>
  </verify>
  <done>Whitelisted facts echoed to mobile; PII not echoed; internal persistence intact; test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Apply the echo to the local CoachProfile (mobile)</name>
  <files>apps/mobile/lib/widgets/coach/widget_renderer.dart, apps/mobile/lib/models/coach_profile.dart, apps/mobile/test/widgets/coach/savefact_echo_test.dart</files>
  <behavior>
    - widget_renderer handles the "fact_saved" echo: it maps {key,value} via the existing
      field-key mapping (:345-431) and updates the local CoachProfile through the provider.
    - An age echo of "50" updates the local profile age to 50 (the W1 WTF-W1-04 fix: what
      Marc tells the coach now feeds the profile the simulators read).
    - An unknown key is ignored (no crash).
  </behavior>
  <action>Add a "fact_saved" case to the widget_renderer.dart:62 switch that reuses the existing field-key mapping to write to CoachProfile via the provider. Do not add a new store; route through the existing SecureStorage write. Write savefact_echo_test.dart: age echo updates profile, unknown key no-ops, no new hardcoded user-facing string introduced (if a confirmation string is shown, it must use AppLocalizations — CLAUDE.md rule 5).</action>
  <verify>
    <automated>cd apps/mobile && flutter test test/widgets/coach/savefact_echo_test.dart 2>&1 | tail -12</automated>
  </verify>
  <done>Echo updates local CoachProfile; chat-stated age now reaches the profile store; test green.</done>
</task>

<task type="auto">
  <name>Task 4: Suites + analyze + ARB parity (if any string added)</name>
  <files>services/backend, apps/mobile</files>
  <action>Run full backend suite + flutter analyze. If Task 3 introduced any user-facing confirmation string, add the key to all 6 ARB files + run flutter gen-l10n + validate_arb_parity; otherwise note "no new ARB keys". Confirm accent lint clean on edited Dart/Python prose.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -5 && cd /Users/julienbattaglia/Desktop/MINT.nosync/apps/mobile && flutter analyze 2>&1 | tail -5</automated>
  </verify>
  <done>Backend suite green; flutter analyze clean; ARB parity status noted in SUMMARY.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| save_fact echo → mobile local store | Extracted profile value crossing back to the client store |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-06-01 | Information disclosure (PII over-echo) | save_fact echo whitelist | mitigate | Echo gated by the existing persist whitelist; non-whitelisted keys dropped |
| T-m1-06-02 | Tampering (wrong domain constant) | avs.reference_age_women=65 | mitigate | Correct to 64.5 for 2026; regression test pins it |
| T-m1-06-SC | Tampering | pip/pub installs | accept | No new packages; existing runners only |
</threat_model>

<verification>
- `grep -n "reference_age_women" services/backend/app/services/regulatory/registry.py` then confirm value 64.5.
- `grep -n "fact_saved\|save_fact" services/backend/app/api/v1/endpoints/coach_chat.py` shows the echo append.
- `grep -n "fact_saved" apps/mobile/lib/widgets/coach/widget_renderer.dart` shows the apply case.
- `cd services/backend && python3 -m pytest tests/ -q` exits 0; `cd apps/mobile && flutter test test/widgets/coach/savefact_echo_test.dart` exits 0.
</verification>

<success_criteria>
A fact stated in chat is echoed to the mobile client and updates the local CoachProfile, the
AVS women reference age is 64.5 for 2026, no PII is over-echoed, and backend + mobile suites
are green — without any event-log cutover (M2 scope preserved).
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-06-SUMMARY.md` when done.
</output>
