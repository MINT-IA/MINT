---
phase: wave-1b
plan: 06
type: execute
wave: 2
depends_on: [wave-1b-05, wave-1b-07]
files_modified:
  - apps/mobile/lib/widgets/coach/coach_citation_modal.dart
  - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
  - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart
  - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart
autonomous: true
requirements: [WAVE1B-05, WAVE1B-08]
must_haves:
  truths:
    - "New widget showCoachCitationModal(context, chip) exists and opens a showModalBottomSheet matching response_card_widget.dart:490-569 pattern (maxHeight 0.85)"
    - "Modal displays: tool display name (header), inputs_hash truncated to 16 chars (selectable + tap-to-copy), computed_at relative time, ExpansionTile containing pretty-printed JSON viewer, Souviens-toi de cette source CTA"
    - "flag_state badge is NOT rendered in v1 per Q7_DECISION (RESEARCH §3.3 + §9.2 — flag_state always 'on' when chip renders, badge is meaningless)"
    - "Relative-time helper (_relativeTime) reads 4 ARB keys via AppLocalizations (not Dart literals) per Q8_DECISION + CLAUDE.md TOP rule #5"
    - "coach_message_bubble.dart's onChipTap callback (added in Plan 05) now invokes showCoachCitationModal"
    - "Souviens-toi CTA invokes save_insight or equivalent — tap fires a callback exposed by the modal; Plan 06 only wires the UI, persistence is documented as a Wave 2 follow-up"
    - "Modal JSON viewer uses JsonEncoder.withIndent('  ') (Karpathy #2 — no syntax highlight dep)"
    - "Plan 01's modal stubs are unskipped + passing"
    - "Q7 DEVIATION block visible at top of plan: flag_state badge dropped (CONTEXT line 40 deviation) — Julien confirm before exec"
    - "Q8 DEVIATION block visible at top of plan: 4 relative-time ARB keys added (not pre-listed in CONTEXT) — Julien confirm before exec"
  artifacts:
    - path: "apps/mobile/lib/widgets/coach/coach_citation_modal.dart"
      provides: "Modal bottom-sheet showing tool-call provenance + Souviens-toi CTA"
      contains: "showCoachCitationModal|showModalBottomSheet|JsonEncoder.withIndent|ExpansionTile|coachCitationRelative"
    - path: "apps/mobile/lib/widgets/coach/coach_message_bubble.dart"
      provides: "onChipTap wires showCoachCitationModal"
      contains: "showCoachCitationModal"
    - path: "apps/mobile/test/widgets/coach/coach_citation_modal_test.dart"
      provides: "Plan 01 stubs unskipped — 3+ tests"
      contains: "showCoachCitationModal|ExpansionTile|coachCitationModalTitle"
    - path: "apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart"
      provides: "Plan 01 stub unskipped — CTA invokes callback"
      contains: "Souviens-toi|onRememberTap|coachCitationRememberCta"
  key_links:
    - from: "apps/mobile/lib/widgets/coach/coach_message_bubble.dart"
      to: "apps/mobile/lib/widgets/coach/coach_citation_modal.dart"
      via: "onChipTap callback → showCoachCitationModal(context, chip)"
      pattern: "showCoachCitationModal"
---

# Q7_DECISION — flag_state badge dropped in v1 (RESEARCH §3.3 + §9.2 deviation)

**CONTEXT.md line 40 prescribes:** « Chip-tap → modal showing: tool name, inputs_hash, computed_at timestamp, raw JSON response (collapsible), **flag_state badge**, "souviens-toi de cette source" CTA. »

**RESEARCH §3.3 + §9.2 recommend:** Drop the flag_state badge in v1.

**Rationale:**
1. `flag_state` is NOT in the Pydantic response models (verified via `services/backend/app/models/coach_tools/budget_snapshot.py`).
2. `flag_state` only exists in the Sentry breadcrumb at the Python layer (`coach_breadcrumbs.py:31`) — never serialized to Dart.
3. The chip only renders when the response carries `inputs_hash` (i.e. flag=on). When flag=off, there is no `inputs_hash`, hence no chip, hence no modal.
4. **Therefore the badge always reads "on"**. Karpathy #2 simplicity says: drop it.
5. If Wave 2 introduces staged-rollout cohorts or partial flags, the badge becomes meaningful and can be added back.

**Plan adopts the drop.** If Julien rejects this deviation, the alternative is to (a) add a `flag_state` field to all 4-6 Pydantic response models in a Wave 1b backend touch-up, (b) thread it through the chat HTTP response, (c) render a 5th row in the modal. Estimated additional cost: 0.5 plans.

---

# Q8_DECISION — Relative-time strings via ARB (CONTEXT non-prescription)

**Status:** Pending Julien confirm at exec start.
**CONTEXT prescription:** Lines 38-41 list ARB strings for chip label / modal title / JSON viewer label / CTA — **the relative-time strings ("à l'instant", "il y a N min/h/j") are NOT listed**. CONTEXT did not pre-decide because the relative-time helper wasn't surfaced as a separate concern at discuss-phase time.

**Reality:** The modal renders a relative-time string under the `computed_at` row. Per CLAUDE.md TOP rule #5 ("i18n required — all user-facing strings via `AppLocalizations.of(context)!.<key>`"), these strings MUST go through ARB. Dart literals (`'à l\'instant'`, etc.) would ship FR-only to en/de/es/it/pt users — silent regression that ARB-parity gate G5 cannot catch (G5 checks ARB completeness, not Dart-string leakage).

**Recommended (plan adopts):** Add 4 new ARB keys with `Intl.plural` placeholder where needed:
- `coachCitationRelativeJustNow` (no placeholder) — FR: « à l'instant »
- `coachCitationRelativeMinutes` (`{count}` placeholder, plural) — FR: « il y a {count} min »
- `coachCitationRelativeHours` (`{count}` placeholder, plural) — FR: « il y a {count} h »
- `coachCitationRelativeDays` (`{count}` placeholder, plural) — FR: « il y a {count} j »

The `_relativeTime` helper signature changes from `_relativeTime(DateTime)` to `_relativeTime(DateTime, AppLocalizations)` and reads ARB keys instead of returning hard-coded FR strings.

**Plan 07 picks up the 4 new keys** (revised count: 11 frame/tool keys + 4 relative-time keys = **15 keys × 6 locales = 90 entries**, up from 66).

**Alternative:** Ship Dart literals in FR for v1, defer i18n to Wave 2. Rejected because the modal is user-facing surface and TOP rule #5 is strict (silent FR-only string in EN/DE/ES/IT/PT app = bug).

**Plan adopts the 4 ARB keys path.** Julien confirm at exec start required because this expands Plan 07's ARB delta from 66 → 90 entries.

---

<objective>
Create `coach_citation_modal.dart` exposing `showCoachCitationModal(context, chip)` — a `showModalBottomSheet` mirroring the `response_card_widget.dart:490-569` proof-modal pattern. Modal shows:
1. Header: tool display name (e.g. "Source du calcul : Budget actuel").
2. Truncated `inputs_hash` (first 16 chars) with selectable text.
3. Relative `computed_at` time via `AppLocalizations.coachCitationRelative*` keys (Q8_DECISION — 4 ARB keys).
4. Collapsible JSON viewer (ExpansionTile + pretty-printed raw response).
5. "Souviens-toi de cette source" CTA — exposes an optional `onRememberTap` callback; persistence is documented as Wave 2 follow-up (this plan ships UI only).

Modal is READ-ONLY per CONTEXT D-03; no edit/refresh action.

Plan 05's `onChipTap` callback now invokes `showCoachCitationModal`.
</objective>

## Counter-arguments considered

- **Counter-arg 1: hardcode FR literals for v1, defer i18n to Wave 2.** Rejected because CLAUDE.md TOP rule #5 is non-negotiable and the gate (`validate_arb_parity`) doesn't scan Dart literals — a silent FR-only string would ship to 5 locales as bug. The cost of 4 ARB keys is mechanical (90 entries vs 66).
- **Counter-arg 2: use `package:intl` `Intl.message` directly instead of ARB.** Rejected because the project standardizes on `AppLocalizations` (ARB-generated). Mixing two i18n stacks creates split-brain.
- **Counter-arg 3: keep flag_state badge to honor CONTEXT line 40 literally.** Rejected per Q7_DECISION — flag_state is always "on" when the chip renders (chip only appears when inputs_hash is in response, which only happens when flag is on), so the badge has zero information content.
- **Data gap:** No telemetry baseline on modal tap-through rate. Sentry breadcrumb `coach.citation.tool_call_id.<tool>.emitted` (Plan 08) establishes the citation-rendered baseline; the Souviens-toi CTA persistence (Wave 2) will establish the tap-through baseline.

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@apps/mobile/lib/widgets/coach/response_card_widget.dart
@apps/mobile/lib/widgets/coach/coach_message_bubble.dart
@apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart

<interfaces>
showModalBottomSheet precedent (response_card_widget.dart:490-569):
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * 0.85,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => Padding(
    padding: const EdgeInsets.all(MintSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...],
    ),
  ),
);
```

Modal target shape (per RESEARCH §5.5):
```dart
Future<void> showCoachCitationModal(
  BuildContext context,
  ToolCallCitationChip chip, {
  void Function(ToolCallCitationChip)? onRememberTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CoachCitationModalBody(
      chip: chip,
      onRememberTap: onRememberTap,
    ),
  );
}
```

Tool display name lookup is duplicated from CoachCitationChipsSection (Plan 05). Refactor to a shared helper at `apps/mobile/lib/widgets/coach/coach_tool_display_name.dart` OR keep the switch inline in both widgets (Karpathy #2 — duplication of 8-line switch is acceptable for v1). Pick inline duplication.

ARB keys consumed (all from Plan 07):
- `coachCitationModalTitle(toolDisplayName)` — modal header
- `coachCitationJsonViewerLabel` — ExpansionTile header text
- `coachCitationRememberCta` — CTA button text
- `coachCitationRelativeJustNow` — Q8_DECISION
- `coachCitationRelativeMinutes(count)` — Q8_DECISION (plural)
- `coachCitationRelativeHours(count)` — Q8_DECISION (plural)
- `coachCitationRelativeDays(count)` — Q8_DECISION (plural)
- 6 `coachTool*` keys for `_toolDisplayName` lookup

Relative-time formatting via ARB (Q8_DECISION):
```dart
String _relativeTime(DateTime computedAt, AppLocalizations l10n) {
  final delta = DateTime.now().toUtc().difference(computedAt.toUtc());
  if (delta.inMinutes < 1) return l10n.coachCitationRelativeJustNow;
  if (delta.inHours < 1) return l10n.coachCitationRelativeMinutes(delta.inMinutes);
  if (delta.inDays < 1) return l10n.coachCitationRelativeHours(delta.inHours);
  return l10n.coachCitationRelativeDays(delta.inDays);
}
```

JSON pretty-print (Karpathy #2 — no syntax highlight, dart:convert stdlib):
```dart
final json = const JsonEncoder.withIndent('  ').convert(chip.rawResponse);
SelectableText(json, style: MintTextStyles.micro(color: MintColors.textSecondaryAaa));
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Create coach_citation_modal.dart with showCoachCitationModal + _CoachCitationModalBody</name>
  <read_first>
    - apps/mobile/lib/widgets/coach/response_card_widget.dart lines 480-570 (showModalBottomSheet precedent — copy structure)
    - apps/mobile/lib/widgets/coach/coach_citation_chips_section.dart (Plan 05 — match _toolDisplayName lookup)
    - apps/mobile/lib/services/rag_service.dart (ToolCallCitationChip definition from Plan 04)
    - apps/mobile/lib/theme/spacing.dart (MintSpacing tokens)
    - apps/mobile/lib/theme/text_styles.dart (MintTextStyles tokens)
    - apps/mobile/pubspec.yaml (check if package:intl is in deps — needed for ARB plural support in Plan 07)
  </read_first>
  <files>
    - apps/mobile/lib/widgets/coach/coach_citation_modal.dart (create)
  </files>
  <behavior>
    After this task:
    - Top-level function `showCoachCitationModal(BuildContext, ToolCallCitationChip, {void Function(ToolCallCitationChip)? onRememberTap})` exists.
    - Modal renders 5 sections in order: header + inputs_hash + computed_at + collapsible JSON + CTA.
    - JSON is pretty-printed with 2-space indent via `JsonEncoder.withIndent('  ')`.
    - Tap on CTA invokes `onRememberTap?.call(chip)` and closes the modal via `Navigator.of(ctx).pop()`.
    - Modal is fully i18n via AppLocalizations (Plan 07 ARB keys + 4 new relative-time keys per Q8).
    - No flag_state badge (Q7_DECISION).
    - `_relativeTime` reads ARB keys, NOT Dart literals (Q8_DECISION + CLAUDE.md TOP rule #5).
  </behavior>
  <action>
    Create `apps/mobile/lib/widgets/coach/coach_citation_modal.dart`:
    ```dart
    import 'dart:convert';
    import 'package:flutter/material.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/theme/colors.dart';
    import 'package:mint_mobile/theme/spacing.dart';
    import 'package:mint_mobile/theme/text_styles.dart';

    /// Wave 1b — citation modal.
    ///
    /// Opens a bottom-sheet showing the provenance of a server-side tool call:
    /// tool name, inputs_hash (truncated), computed_at (relative, via ARB keys
    /// per Q8_DECISION), raw response (collapsible pretty-printed JSON), and
    /// "Souviens-toi de cette source" CTA.
    ///
    /// Per CONTEXT D-03 — modal is READ-ONLY; no edit/refresh.
    /// Per Q7_DECISION (Plan 06) — flag_state badge dropped in v1.
    /// Per Q8_DECISION (Plan 06) — relative-time strings via 4 ARB keys
    /// (`coachCitationRelativeJustNow`, `coachCitationRelativeMinutes`,
    /// `coachCitationRelativeHours`, `coachCitationRelativeDays`).
    Future<void> showCoachCitationModal(
      BuildContext context,
      ToolCallCitationChip chip, {
      void Function(ToolCallCitationChip)? onRememberTap,
    }) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _CoachCitationModalBody(
          chip: chip,
          onRememberTap: onRememberTap,
        ),
      );
    }

    String _toolDisplayName(BuildContext context, String toolName) {
      final s = AppLocalizations.of(context)!;
      switch (toolName) {
        case 'budget_snapshot':
          return s.coachToolBudgetSnapshot;
        case 'retirement_projection':
          return s.coachToolRetirementProjection;
        case 'cross_pillar_analysis':
          return s.coachToolCrossPillarAnalysis;
        case 'couple_optimization':
          return s.coachToolCoupleOptimization;
        case 'cap_status':
          return s.coachToolCapStatus;
        case 'retrieve_memories':
          return s.coachToolRetrieveMemories;
        default:
          return toolName;
      }
    }

    /// Q8_DECISION — reads 4 ARB keys via AppLocalizations.
    /// NEVER returns a Dart literal — silent FR-only string in EN/DE/ES/IT/PT
    /// would violate CLAUDE.md TOP rule #5 (i18n required) and would NOT be
    /// caught by validate_arb_parity (gate checks ARB completeness, not Dart
    /// literal leakage).
    String _relativeTime(DateTime computedAt, AppLocalizations l10n) {
      final delta = DateTime.now().toUtc().difference(computedAt.toUtc());
      if (delta.inMinutes < 1) return l10n.coachCitationRelativeJustNow;
      if (delta.inHours < 1) return l10n.coachCitationRelativeMinutes(delta.inMinutes);
      if (delta.inDays < 1) return l10n.coachCitationRelativeHours(delta.inHours);
      return l10n.coachCitationRelativeDays(delta.inDays);
    }

    class _CoachCitationModalBody extends StatelessWidget {
      final ToolCallCitationChip chip;
      final void Function(ToolCallCitationChip)? onRememberTap;

      const _CoachCitationModalBody({
        required this.chip,
        this.onRememberTap,
      });

      @override
      Widget build(BuildContext context) {
        final s = AppLocalizations.of(context)!;
        final toolDisplayName = _toolDisplayName(context, chip.toolName);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(chip.rawResponse);
        final hashShort = chip.inputsHash.length >= 16
            ? '${chip.inputsHash.substring(0, 16)}…'
            : chip.inputsHash;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: MintSpacing.md),
                  decoration: BoxDecoration(
                    color: MintColors.porcelaine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header.
              Text(
                s.coachCitationModalTitle(toolDisplayName),
                style: MintTextStyles.titleMedium(),
              ),
              const SizedBox(height: MintSpacing.md),
              // inputs_hash (truncated, selectable).
              Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 14,
                    color: MintColors.textSecondaryAaa.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: MintSpacing.xs),
                  Expanded(
                    child: SelectableText(
                      hashShort,
                      style: MintTextStyles.micro(
                        color: MintColors.textSecondaryAaa,
                      ).copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.xs),
              // computed_at (relative) — Q8_DECISION: 4 ARB keys via _relativeTime(chip.computedAt, s).
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: MintColors.textSecondaryAaa.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: MintSpacing.xs),
                  Text(
                    _relativeTime(chip.computedAt, s),
                    style: MintTextStyles.micro(
                      color: MintColors.textSecondaryAaa,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MintSpacing.md),
              // JSON viewer (collapsible).
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  key: const Key('coachCitationModalJsonExpansion'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: MintSpacing.xs),
                  title: Text(
                    s.coachCitationJsonViewerLabel,
                    style: MintTextStyles.micro(
                      color: MintColors.textMutedAaa,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(MintSpacing.sm),
                      decoration: BoxDecoration(
                        color: MintColors.bleuAir.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        prettyJson,
                        style: MintTextStyles.micro(
                          color: MintColors.textSecondaryAaa,
                        ).copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MintSpacing.lg),
              // Souviens-toi CTA.
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const Key('coachCitationModalRememberCta'),
                  icon: const Icon(Icons.bookmark_outline, size: 16),
                  label: Text(s.coachCitationRememberCta),
                  onPressed: onRememberTap == null
                      ? null
                      : () {
                          onRememberTap!(chip);
                          Navigator.of(context).pop();
                        },
                ),
              ),
            ],
          ),
        );
      }
    }
    ```
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter analyze lib/widgets/coach/coach_citation_modal.dart 2>&amp;1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - `test -f apps/mobile/lib/widgets/coach/coach_citation_modal.dart` exits 0.
    - `grep -c "Future<void> showCoachCitationModal" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 1.
    - `grep -c "showModalBottomSheet\\|ExpansionTile\\|JsonEncoder.withIndent" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns ≥3.
    - `grep -c "flag_state\\|flagState\\|flag state" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 0 (Q7_DECISION — badge dropped).
    - `grep -c "AppLocalizations.of(context)!.coach" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns ≥3 (header + JSON label + CTA + 6 tool names + 4 relative-time keys).
    - `grep -c "coachCitationRelativeJustNow\\|coachCitationRelativeMinutes\\|coachCitationRelativeHours\\|coachCitationRelativeDays" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns ≥4 (Q8_DECISION — 4 relative-time ARB keys consumed).
    - `grep -cE "'à l\\\\'instant'\\|'il y a [^']+\\\$\\{" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 0 (no Dart literals for relative-time strings).
    - `cd apps/mobile && flutter analyze lib/widgets/coach/coach_citation_modal.dart 2>&1 | grep -c "error"` returns 0.
  </acceptance_criteria>
  <done>
    Modal widget exists with 5 sections (header / hash / time / collapsible JSON / CTA); no flag_state badge; _relativeTime reads 4 ARB keys (no Dart literals); analyzer clean (zero errors).
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Wire showCoachCitationModal into coach_message_bubble.dart + unskip Plan 01 modal stubs + Souviens-toi CTA test</name>
  <read_first>
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart (Plan 05 left an empty onChipTap callback — find it)
    - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart (Plan 01 stubs)
    - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart (Plan 01 stubs)
  </read_first>
  <files>
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart (modify — wire onChipTap to showCoachCitationModal)
    - apps/mobile/test/widgets/coach/coach_citation_modal_test.dart (modify — unskip + 3 tests)
    - apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart (modify — unskip + 1 test)
  </files>
  <action>
    Step A — Edit `apps/mobile/lib/widgets/coach/coach_message_bubble.dart`. Add import:
    ```dart
    import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';
    ```
    Locate the `onChipTap: (chip) { /* Plan 06 wires the modal here */ }` callback added in Plan 05. Replace its body:
    ```dart
    onChipTap: (chip) {
      showCoachCitationModal(
        context,
        chip,
        onRememberTap: (c) {
          // Wave 2 follow-up: persist to user wiki via save_insight.
          // For v1 we just emit a SnackBar acknowledgement so Maestro G1
          // can assert the CTA wired (Plan 09).
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.coachCitationRememberCta,
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
    },
    ```

    Step B — Edit `apps/mobile/test/widgets/coach/coach_citation_modal_test.dart`. Remove skip markers; implement 3 tests:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';

    Widget _wrap(VoidCallback onTap) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    final chip = ToolCallCitationChip(
                      toolName: 'budget_snapshot',
                      inputsHash: 'a' * 64,
                      computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
                      rawResponse: const {'monthlyIncome': '7500'},
                    );
                    showCoachCitationModal(ctx, chip);
                    onTap();
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

    void main() {
      group('showCoachCitationModal', () {
        testWidgets('opens bottom sheet on chip tap', (tester) async {
          var opened = false;
          await tester.pumpWidget(_wrap(() => opened = true));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(opened, true);
          // Modal sheet renders.
          expect(find.byKey(const Key('coachCitationModalJsonExpansion')),
              findsOneWidget);
        });

        testWidgets('shows truncated 16-char inputs_hash', (tester) async {
          await tester.pumpWidget(_wrap(() {}));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          // 'a' * 16 + '…' (ellipsis char)
          expect(find.text('${'a' * 16}…'), findsOneWidget);
        });

        testWidgets('JSON viewer is collapsible (ExpansionTile)', (tester) async {
          await tester.pumpWidget(_wrap(() {}));
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          // Initially collapsed — JSON not visible.
          expect(find.textContaining('monthlyIncome'), findsNothing);
          // Expand.
          await tester.tap(find.byKey(const Key('coachCitationModalJsonExpansion')));
          await tester.pumpAndSettle();
          // Now visible.
          expect(find.textContaining('monthlyIncome'), findsOneWidget);
        });
      });
    }
    ```

    Step C — Edit `apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart`. Remove skip markers; implement 1 test:
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:mint_mobile/l10n/app_localizations.dart';
    import 'package:mint_mobile/services/rag_service.dart';
    import 'package:mint_mobile/widgets/coach/coach_citation_modal.dart';

    void main() {
      testWidgets('Souviens-toi CTA fires onRememberTap with the chip', (tester) async {
        ToolCallCitationChip? remembered;
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => showCoachCitationModal(
                    ctx,
                    ToolCallCitationChip(
                      toolName: 'budget_snapshot',
                      inputsHash: 'b' * 64,
                      computedAt: DateTime.parse('2026-05-15T10:00:00Z'),
                      rawResponse: const {'_test': true},
                    ),
                    onRememberTap: (c) => remembered = c,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('coachCitationModalRememberCta')));
        await tester.pumpAndSettle();
        expect(remembered?.toolName, 'budget_snapshot');
      });
    }
    ```

    Step D — Run `cd apps/mobile && flutter analyze && flutter test test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart`. MUST exit 0.
  </action>
  <verify>
    <automated>cd apps/mobile &amp;&amp; flutter test test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "showCoachCitationModal" apps/mobile/lib/widgets/coach/coach_message_bubble.dart` returns ≥1.
    - `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_modal_test.dart` returns 0.
    - `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_chip_modal_remember_test.dart` returns 0.
    - `cd apps/mobile && flutter test test/widgets/coach/coach_citation_modal_test.dart 2>&1 | grep "All tests passed"` returns non-empty.
    - `cd apps/mobile && flutter test test/widgets/coach/coach_citation_chip_modal_remember_test.dart 2>&1 | grep "All tests passed"` returns non-empty.
    - `cd apps/mobile && flutter analyze 2>&1 | grep -c "error"` returns 0.
  </acceptance_criteria>
  <done>
    Modal wired into chat bubble; 4 widget tests pass (exit 0); Souviens-toi CTA invokes callback; Plan 01 stubs all unskipped.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-06-01 | I | Pretty-printed JSON in modal leaks PII (CHF amounts, AHV) into screen recordings | accept | Modal is user-initiated; user explicitly taps to see their own data. iOS sim screen recordings are local; Sentry Replay (Phase 31) masks all text via `maskAllText=true`. |
| T-WAVE1B-06-02 | T | flag_state badge expected by CONTEXT but dropped (Q7_DECISION) | mitigate | Q7_DECISION block at top of plan surfaces deviation. If Julien rejects, alternative path documented (add flag_state to Pydantic models). |
| T-WAVE1B-06-03 | T | Modal opens but immediately closes due to tap propagation | mitigate | InkWell.onTap (Plan 05) calls onChipTap; modal builder runs in builder context. Test 1 asserts the bottom sheet renders. |
| T-WAVE1B-06-04 | I | "Souviens-toi" CTA accidentally persists data without user consent | mitigate | Plan 06 ships UI ONLY. Persistence (save_insight tool wiring) is documented as Wave 2 follow-up in the SnackBar callback. Tests assert callback fires, not persistence. |
| T-WAVE1B-06-05 | T | Hardcoded FR strings in modal violate i18n | mitigate | All user-facing text via `AppLocalizations.of(context)!.<key>`. Plan 07 ships ARB keys (15 keys × 6 locales = 90 entries per Q8 revision). Plan 06 depends_on Plan 07. |
| T-WAVE1B-06-06 | T | Relative-time strings hardcoded in Dart literals (FR-only leak) | mitigate | Q8_DECISION + Task 1 acceptance criteria forbid Dart literals for `à l'instant` / `il y a N`; helper signature is `_relativeTime(DateTime, AppLocalizations)` reading 4 ARB keys. Plan 07 ships the keys. |
</threat_model>

<verification>
- `cd apps/mobile && flutter test test/widgets/coach/coach_citation_modal_test.dart test/widgets/coach/coach_citation_chip_modal_remember_test.dart -q` exits 0.
- `cd apps/mobile && flutter analyze 2>&1 | grep -c "error"` returns 0.
- `grep -c "skip: 'Wave 1b" apps/mobile/test/widgets/coach/coach_citation_*.dart` returns 0 (all Plan 01 Dart stubs now unskipped).
- `grep -c "flag_state\\|flagState" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns 0 (Q7 dropped).
- `grep -c "coachCitationRelativeJustNow\\|coachCitationRelativeMinutes\\|coachCitationRelativeHours\\|coachCitationRelativeDays" apps/mobile/lib/widgets/coach/coach_citation_modal.dart` returns ≥4 (Q8 — relative-time via ARB).
</verification>

<success_criteria>
- Modal renders 5 sections (header / hash / time / collapsible JSON / CTA); no flag_state badge.
- Relative-time helper reads 4 ARB keys (Q8_DECISION); no Dart literals.
- 4 modal tests pass (exit 0).
- Plan 05's onChipTap callback invokes the modal.
- Souviens-toi CTA wired with documented Wave 2 follow-up for save_insight persistence.
- Q7_DECISION + Q8_DECISION surfaced.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-06-SUMMARY.md` with:
- Modal widget LOC count
- 4 widget tests + state (exit code 0 cited)
- Q7_DECISION outcome
- Q8_DECISION outcome (4 ARB keys consumed)
- 0-trust self-check citing flutter test output verbatim
</output>
</content>
</invoke>
