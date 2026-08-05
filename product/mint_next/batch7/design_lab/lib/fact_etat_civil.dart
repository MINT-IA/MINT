// Batch22 R4 (FERMETURE DE LA BOUCLE) runtime — the `fact_etat_civil` node for
// the hidden design lab. It refreshes batch6 `fact_household` (the COARSE
// couple/family bucket that is the exact site of fault_5): the user declares
// their civil status in ONE tap among three tappable cards — célibataire /
// marié·e ou partenaire enregistré·e / en couple non marié·e — and is_married
// derives ONLY from marie_pacse. Concubinage maps to the SINGLE treatment
// (is_married=false), NEVER the married splitting (the ruling). No personal
// tax amount is shown here (a collection screen, like fact_revenu).
//
// It implements product/mint_next/batch22/fact_etat_civil-scope.yaml
// (three tappable cards, no wheel, no preselection; a determining-date subline
// under the question; a splitting-vs-separate glossary via help_link; the
// concubinage card carries its OWN glossary, the ruling in clear) +
// r4-six-locale-copy.yaml (rendered from r4_fermeture_catalog.g.dart).
//
// The question stands ALONE (no body sentence) and takes arrival focus; the
// determining-date hint is a discrete subline (never overloading the
// question). Continue is guarded (route_guard: a_status_is_selected) and
// NEVER routes in R4 (deferred_integration.never_routes_in_r4_applies_to:
// [continue, back] — this is parallel prep, not the integration wave). There
// is NO privacy sentence: the committed status joins the profile like the
// tranche/commune, so no datum on this screen is device-only
// (privacy_copy_rule).

import 'package:flutter/material.dart';

import 'r4_fermeture_catalog.g.dart';

// Design-lab palette (mirrors scenarios_versement.dart / batch21's private
// tokens; each screen file in this lib dir is self-contained by convention).
const Color _paper = Color(0xFFFAF8F5);
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _border = Color(0xFFE2DED7);
const Color _forest = Color(0xFF1C3A2B); // 10.4:1 on _paper (R3-proven accent).
const Color _cardBorder = Color(0xFFCAD8C3);

/// The R4 secondary-text token — DARKENED per the sealed contract's
/// MUST_FIX_BEFORE_GREEN obligation (accessibility_contract.
/// secondary_text_contrast_binding, fact_etat_civil-scope.yaml:331-338). The
/// flagged mockup sauge — rgb(110,140,116) on paper rgb(246,244,238) —
/// measures 3.37:1 (below the 4.5:1 functional-text floor). This darkened
/// token — rgb(86,114,92), i.e. 0xFF56725C — measures 4.83:1 on the same
/// paper background (WCAG relative-luminance formula, verified by
/// `test/dev_fact_etat_civil_r4_test.dart`). Applied to every `applies_to`
/// surface: eyebrow, help_link, selection_summary, glossary_body.
const Color _sauge = Color(0xFF56725C);

/// The three civil-status cards, in the sealed stable order
/// (input_contract.cards). `isMarried` is the ONLY thing that derives
/// is_married (fault_5 ruling) — concubinage is never married.
class _StatusOption {
  const _StatusOption({
    required this.key,
    required this.labelKey,
    required this.isMarried,
  });

  final String key;
  final String labelKey;
  final bool isMarried;
}

const List<_StatusOption> _statusOptions = <_StatusOption>[
  _StatusOption(
    key: 'celibataire',
    labelKey: 'etat_civil_card_celibataire',
    isMarried: false,
  ),
  _StatusOption(
    key: 'marie_pacse',
    labelKey: 'etat_civil_card_marie_pacse',
    isMarried: true,
  ),
  _StatusOption(
    key: 'concubinage',
    labelKey: 'etat_civil_card_concubinage',
    isMarried: false,
  ),
];

/// is_married derivation (fault_5_civil_status_splitting_ruling): derives
/// ONLY from marie_pacse. Exposed for the future integration test / coach
/// widget to reuse without re-deriving the rule (NEVER#3).
bool r4IsMarriedFromCivilStatus(String? status) => status == 'marie_pacse';

class FactEtatCivilScreen extends StatefulWidget {
  const FactEtatCivilScreen({
    super.key,
    required this.taxYear,
    required this.selectedStatus,
    required this.onSelectStatus,
    required this.onBack,
    this.onContinue,
  });

  final int taxYear;

  /// The committed status enum (celibataire / marie_pacse / concubinage), or
  /// null when unset (default_hypothesis — never a preselected card).
  final String? selectedStatus;

  /// Atomically commits a reviewed status WITHOUT routing (choose_status
  /// contract: upgrades_provenance hypothesis_to_declared, replaces_in_place).
  final ValueChanged<String> onSelectStatus;

  /// Exact history back. deferred_integration.never_routes_in_r4_applies_to
  /// includes `back` for this node — the isolated batch22 harness has no
  /// prior node in this parallel-prep lane, so this is an inert callback;
  /// linear wiring is the promoter's integration wave.
  final VoidCallback onBack;

  /// `continue` -> eclairage_impot_3a (route_guard: a_status_is_selected).
  /// Null in the batch22 harness (never_routes_in_r4): with no status the
  /// no-selection error surfaces and never routes; with a status the guard
  /// clears but there is no forward route yet.
  final VoidCallback? onContinue;

  @override
  State<FactEtatCivilScreen> createState() => _FactEtatCivilScreenState();
}

class _FactEtatCivilScreenState extends State<FactEtatCivilScreen> {
  final FocusNode _questionFocus =
      FocusNode(debugLabel: 'fact_etat_civil question');
  final FocusNode _helpLinkFocus =
      FocusNode(debugLabel: 'fact_etat_civil help_link anchor');
  final FocusNode _concubinageGlossFocus =
      FocusNode(debugLabel: 'fact_etat_civil concubinage gloss anchor');
  final FocusNode _sheetHeadingFocus =
      FocusNode(debugLabel: 'fact_etat_civil sheet heading');

  bool _showNoSelectionError = false;
  _Overlay? _overlay;

  late final Object _generation = Object();
  bool _questionFocusRequested = false;

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  @override
  void initState() {
    super.initState();
    // Arrival focuses the heading for the screen reader — no keyboard is
    // raised (no text field on this screen; input_contract.numeric_keyboard:
    // not_applicable).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_questionFocusRequested) {
        _questionFocusRequested = true;
        _questionFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _questionFocus.dispose();
    _helpLinkFocus.dispose();
    _concubinageGlossFocus.dispose();
    _sheetHeadingFocus.dispose();
    super.dispose();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return r4Copy.containsKey(code) ? code : 'fr';
  }

  void _handleSelect(String status, Object generation) {
    if (_isStale(generation)) return;
    // same_status_reselect: idempotent no-op, no state churn.
    if (widget.selectedStatus == status) return;
    setState(() => _showNoSelectionError = false);
    widget.onSelectStatus(status);
  }

  void _handleContinue(Object generation) {
    if (_isStale(generation)) return;
    if (widget.selectedStatus == null) {
      setState(() => _showNoSelectionError = true);
      return;
    }
    setState(() => _showNoSelectionError = false);
    widget.onContinue?.call();
  }

  void _openOverlay(_Overlay overlay) {
    setState(() => _overlay = overlay);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(_generation)) _sheetHeadingFocus.requestFocus();
    });
  }

  void _dismissOverlay(Object generation) {
    if (_isStale(generation)) return;
    final wasConcubinage = _overlay == _Overlay.glossConcubinage;
    setState(() => _overlay = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isStale(generation)) return;
      (wasConcubinage ? _concubinageGlossFocus : _helpLinkFocus)
          .requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final copy = r4CopyFor(_localeCode(context));
    final year = widget.taxYear.toString();
    String c(String key) => copy[key]!;
    String withYear(String t) => t.replaceAll('{taxYear}', year);

    final selected = widget.selectedStatus;
    final selectedOption =
        selected == null ? null : _statusOptions.firstWhere((o) => o.key == selected);

    // The header content (eyebrow + question + determining hint) renders
    // FIRST in the scrollable region below, so it is the first thing seen on
    // arrival exactly like a pinned header would be (the scroll starts at the
    // top) — WITHOUT a separately-measured non-scrolling region that could
    // overflow a compact 320x700 viewport at 2x text scale (compact_proof).
    // Only the footer (continue/back) is truly pinned outside the scroll,
    // mirroring fact_revenu.dart's proven layout (product/mint_next/batch21).
    final headerChildren = <Widget>[
      Text(
        withYear(c('etat_civil_eyebrow')),
        key: const ValueKey('text:fact_etat_civil.eyebrow'),
        style: const TextStyle(
          fontFamily: 'Supreme',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: _sauge,
        ),
      ),
      const SizedBox(height: 16),
      // The question stands ALONE (no body sentence) and takes arrival focus.
      Focus(
        key: const ValueKey('text:fact_etat_civil.question'),
        focusNode: _questionFocus,
        child: Semantics(
          header: true,
          child: Text(
            c('etat_civil_question'),
            style: const TextStyle(
              fontFamily: 'Gambarino',
              fontSize: 28,
              height: 1.15,
              color: _ink,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // The determining-date hint: a discrete subline, never overloading the
      // question (fact_etat_civil-scope.yaml determining_date).
      Text(
        withYear(c('etat_civil_determining_hint')),
        key: const ValueKey('text:fact_etat_civil.determining_hint'),
        style: const TextStyle(
          fontFamily: 'Supreme',
          fontSize: 14,
          height: 1.4,
          color: _ink,
        ),
      ),
      const SizedBox(height: 24),
    ];

    // --- scrollable region: header content + three status cards + help_link
    // ---
    final scroll = SingleChildScrollView(
      key: const ValueKey('scroll:fact_etat_civil'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...headerChildren,
          Semantics(
            key: const ValueKey('group:fact_etat_civil.cards'),
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final option in _statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StatusCard(
                      statusKey: option.key,
                      label: c(option.labelKey),
                      selected: option.key == selected,
                      onPressed: () => _handleSelect(option.key, generation),
                      // The concubinage card carries its OWN glossary anchor
                      // (the ruling, in clear) — a DISTINCT tap target from
                      // selection (never conflating "select" with "learn
                      // more").
                      glossaryActionKey: option.key == 'concubinage'
                          ? 'action:fact_etat_civil.open_concubinage_glossary'
                          : null,
                      glossaryLabel: option.key == 'concubinage'
                          ? c('etat_civil_gloss_concubinage_term')
                          : null,
                      glossaryFocusNode: option.key == 'concubinage'
                          ? _concubinageGlossFocus
                          : null,
                      onOpenGlossary: option.key == 'concubinage'
                          ? () => _openOverlay(_Overlay.glossConcubinage)
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _LinkAction(
            actionKey: 'action:fact_etat_civil.help_link',
            label: c('etat_civil_help_link'),
            focusNode: _helpLinkFocus,
            onPressed: () => _openOverlay(_Overlay.glossSplitting),
          ),
          const SizedBox(height: 20),
          if (selected == null)
            _StatusChip(
              statusKey: 'status:fact_etat_civil.selection_none',
              text: c('etat_civil_selection_none'),
              liveRegion: false,
            )
          else ...[
            _SelectionSummary(
              label: c('etat_civil_selection_label'),
              value: c('etat_civil_selection_selected')
                  .replaceAll('{status}', c(selectedOption!.labelKey)),
            ),
            const SizedBox(height: 10),
            Text(
              c('etat_civil_recompute_hint'),
              key: const ValueKey('text:fact_etat_civil.recompute_hint'),
              style: const TextStyle(
                fontFamily: 'Supreme',
                fontSize: 14,
                color: _sauge,
              ),
            ),
          ],
        ],
      ),
    );

    // --- pinned footer: continue above back (three_regions.pinned_footer) ---
    final footer = DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showNoSelectionError) ...[
              _StatusChip(
                statusKey: 'status:fact_etat_civil.error_no_selection',
                text: c('etat_civil_error_no_selection'),
                liveRegion: true,
                tone: _StatusTone.error,
              ),
              const SizedBox(height: 12),
            ],
            _PrimaryButton(
              buttonKey: 'action:fact_etat_civil.continue',
              label: c('etat_civil_continue'),
              filled: selected != null,
              onPressed: () => _handleContinue(generation),
            ),
            const SizedBox(height: 8),
            _TextButton(
              buttonKey: 'action:fact_etat_civil.back',
              label: c('etat_civil_back'),
              onPressed: widget.onBack,
            ),
          ],
        ),
      ),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: scroll), footer],
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(excluding: _overlay != null, child: body),
        if (_overlay == _Overlay.glossSplitting)
          _SplittingGlossSheet(
            headingFocus: _sheetHeadingFocus,
            marieTerm: c('etat_civil_gloss_marie_term'),
            marieDef: c('etat_civil_gloss_marie_def'),
            celibataireTerm: c('etat_civil_gloss_celibataire_term'),
            celibataireDef: c('etat_civil_gloss_celibataire_def'),
            dismissLabel: c('gloss_dismiss'),
            onDismiss: () => _dismissOverlay(generation),
          ),
        if (_overlay == _Overlay.glossConcubinage)
          _GlossSheet(
            sheetId: 'sheet:fact_etat_civil.gloss.concubinage',
            headingFocus: _sheetHeadingFocus,
            term: c('etat_civil_gloss_concubinage_term'),
            definition: c('etat_civil_gloss_concubinage_def'),
            dismissLabel: c('gloss_dismiss'),
            onDismiss: () => _dismissOverlay(generation),
          ),
      ],
    );
  }
}

enum _Overlay { glossSplitting, glossConcubinage }

/// Wraps [child] so [onPressed] fires on pointer tap AND on real keyboard/
/// switch activation (Enter/Space -> ActivateIntent) once the control is
/// focused (mirrors fact_revenu.dart / eclairage_impot_3a.dart's `_Activable`).
class _Activable extends StatelessWidget {
  const _Activable({
    required this.onPressed,
    required this.child,
    this.focusNode,
  });

  final VoidCallback onPressed;
  final Widget child;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

/// One of the three tappable status cards. The concubinage card additionally
/// carries its OWN glossary anchor (fact_etat_civil-scope.yaml
/// input_contract.cards / teaching_mechanism.on_screen_anchors_minimal) as a
/// visually-attached but structurally DISTINCT tap target below the card, so
/// selecting and "learn more" are never conflated for assistive tech.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.statusKey,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.glossaryActionKey,
    this.glossaryLabel,
    this.glossaryFocusNode,
    this.onOpenGlossary,
  });

  final String statusKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final String? glossaryActionKey;
  final String? glossaryLabel;
  final FocusNode? glossaryFocusNode;
  final VoidCallback? onOpenGlossary;

  @override
  Widget build(BuildContext context) {
    final card = Semantics(
      key: ValueKey('choice:fact_etat_civil.$statusKey'),
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: _Activable(
        onPressed: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? _forest : _porcelain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _forest : _cardBorder,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Supreme',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: selected ? _paper : _ink,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                const Icon(Icons.check_rounded, size: 24, color: _paper),
              ],
            ],
          ),
        ),
      ),
    );

    // A local copy forces Dart to promote the nullable field to a
    // non-nullable `String` after this null-check, so the `ValueKey` built
    // below is `ValueKey<String>` (matching `find.byKey(ValueKey<String>(...))`
    // in the dev test) rather than a mismatched `ValueKey<String?>`.
    final glossaryKey = glossaryActionKey;
    if (glossaryKey == null) return card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            key: ValueKey(glossaryKey),
            button: true,
            label: glossaryLabel,
            onTap: onOpenGlossary,
            excludeSemantics: true,
            child: _Activable(
              focusNode: glossaryFocusNode,
              onPressed: onOpenGlossary!,
              child: Container(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                alignment: Alignment.center,
                child: const ExcludeSemantics(
                  child: Text(
                    'ⓘ',
                    style: TextStyle(
                      fontFamily: 'Supreme',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _forest,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _StatusTone { neutral, error }

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.statusKey,
    required this.text,
    required this.liveRegion,
    this.tone = _StatusTone.neutral,
  });

  final String statusKey;
  final String text;
  final bool liveRegion;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isError = tone == _StatusTone.error;
    return Container(
      key: ValueKey(statusKey),
      alignment: Alignment.centerLeft,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFF7E9E4) : _porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isError ? _forest : _border),
      ),
      child: Semantics(
        container: true,
        liveRegion: liveRegion,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Supreme',
            fontSize: 16,
            height: 1.35,
            color: isError ? _forest : _ink,
          ),
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    // A focusable, announced region carrying the reviewed status atomically
    // (selection_refindable). The status is text, not colour-only
    // (concubinage_distinction_not_colour_only).
    return Semantics(
      key: const ValueKey('status:fact_etat_civil.selection'),
      container: true,
      liveRegion: true,
      label: '$label : $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _sauge,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  final String actionKey;
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(actionKey),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: _Activable(
        focusNode: focusNode,
        onPressed: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _forest,
              decoration: TextDecoration.underline,
              decorationColor: _forest,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String buttonKey;
  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(buttonKey),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: _Activable(
        onPressed: onPressed,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? _forest : const Color(0xFFDCE6D6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: filled ? _forest : _cardBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: filled ? _paper : _sauge,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final String buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(buttonKey),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: _Activable(
        onPressed: onPressed,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _sauge,
            ),
          ),
        ),
      ),
    );
  }
}

/// The `help_link` splitting-vs-separate glossary sheet: PRIMARY block is the
/// marié·e/partenaire term+definition (imposition commune), plus a SECONDARY
/// célibataire clarification block (covers divorce/veuvage) — mirroring
/// fact_revenu.dart's `_ImposableGlossSheet` two-concept pattern
/// (concepts_are_glossary_entries: [imposition_commune_splitting,
/// celibataire_seul]).
class _SplittingGlossSheet extends StatelessWidget {
  const _SplittingGlossSheet({
    required this.headingFocus,
    required this.marieTerm,
    required this.marieDef,
    required this.celibataireTerm,
    required this.celibataireDef,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final FocusNode headingFocus;
  final String marieTerm;
  final String marieDef;
  final String celibataireTerm;
  final String celibataireDef;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: const ValueKey('sheet:fact_etat_civil.gloss.splitting'),
      child: FocusScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(color: Color(0x66102217), dismissible: false),
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: _paper,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SheetHandle(),
                        const SizedBox(height: 16),
                        Focus(
                          key: const ValueKey(
                            'sheet:fact_etat_civil.gloss.splitting.heading',
                          ),
                          focusNode: headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              marieTerm,
                              style: const TextStyle(
                                fontFamily: 'Gambarino',
                                fontSize: 24,
                                height: 1.15,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          marieDef,
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 18,
                            height: 1.45,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Supreme',
                              fontSize: 16,
                              height: 1.45,
                              color: _ink,
                            ),
                            children: [
                              TextSpan(
                                text: '$celibataireTerm — ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: celibataireDef),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          buttonKey: 'sheet:fact_etat_civil.gloss.splitting.dismiss',
                          label: dismissLabel,
                          filled: false,
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single term + definition glossary sheet (used for the concubinage
/// ruling). Focus-trapped until dismissed, then restores to its anchor.
class _GlossSheet extends StatelessWidget {
  const _GlossSheet({
    required this.sheetId,
    required this.headingFocus,
    required this.term,
    required this.definition,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final String sheetId;
  final FocusNode headingFocus;
  final String term;
  final String definition;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: ValueKey(sheetId),
      child: FocusScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(color: Color(0x66102217), dismissible: false),
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: _paper,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SheetHandle(),
                        const SizedBox(height: 16),
                        Focus(
                          key: ValueKey('$sheetId.heading'),
                          focusNode: headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              term,
                              style: const TextStyle(
                                fontFamily: 'Gambarino',
                                fontSize: 24,
                                height: 1.15,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          definition,
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 18,
                            height: 1.45,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          buttonKey: '$sheetId.dismiss',
                          label: dismissLabel,
                          filled: false,
                          onPressed: onDismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ExcludeSemantics(
        child: Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
            color: _cardBorder,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
