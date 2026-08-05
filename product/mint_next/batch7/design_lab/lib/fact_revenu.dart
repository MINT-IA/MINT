// Batch21 R3 (ÉCLAIRAGE arc) runtime — the `fact_revenu` node for the hidden
// design lab. It refreshes batch6 `fact_income` (navigation.yaml:320) keeping the
// choose_band semantics: the user situates their APPROXIMATE TAXABLE income in one
// of six tappable bands — never a wheel, never a numeric keyboard, no
// preselection. The band edges are what feed the éclairage fourchette by
// construction (borne basse/haute -> estimate_tax_saving low/high).
//
// It implements product/mint_next/batch21/fact_revenu-scope.yaml +
// r3-six-locale-copy.yaml (rendered from r3_eclairage_catalog.g.dart): the
// question stands alone (no body sentence) and carries the `revenu imposable`
// tap-glossary anchor; three regions (pinned eyebrow+question / scrollable six
// band cards + help link / pinned continue-above-back); a persistent, announced
// selection summary; an error-no-selection guard; and a focus-trapped glossary
// sheet (one plain sentence + a metaphor + a brut clarification) that restores
// focus to its anchor. There is NO privacy sentence: the committed band joins the
// profile like the commune, so no datum here is device-only (privacy_copy_rule).
// Continue is guarded and NEVER routes in R3 (validation in place).

import 'package:flutter/material.dart';

import 'r3_eclairage_catalog.g.dart';

// Design-lab palette (mirrors the private tokens in design_lab_app.dart) plus the
// R3 forest-green accent used by the éclairage arc mockups.
const Color _paper = Color(0xFFFAF8F5);
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _secondaryInk = Color(0xFF4A4A4A);
const Color _border = Color(0xFFE2DED7);
// 10.4:1 on _paper — the R3 primary (payoff amount, filled CTA, selected band,
// interactive anchors). 9.4:1 for _paper text on a _forest fill.
const Color _forest = Color(0xFF1C3A2B);
// 5.6:1 on _paper — the muted green eyebrow / secondary labels.
const Color _moss = Color(0xFF4E6B4A);
// Soft sage-green border for unselected band cards.
const Color _bandBorder = Color(0xFFCAD8C3);

class FactRevenuScreen extends StatefulWidget {
  const FactRevenuScreen({
    super.key,
    required this.taxYear,
    required this.selectedBand,
    required this.onSelectBand,
    required this.onBack,
  });

  final int taxYear;

  /// The committed band enum (lt30 … gt150), or null when unset.
  final String? selectedBand;

  /// Atomically commits a reviewed band WITHOUT routing (choose_band contract).
  final ValueChanged<String> onSelectBand;

  /// Exact history back.
  final VoidCallback onBack;

  @override
  State<FactRevenuScreen> createState() => _FactRevenuScreenState();
}

class _FactRevenuScreenState extends State<FactRevenuScreen> {
  final FocusNode _questionFocus = FocusNode(debugLabel: 'fact_revenu question');
  final FocusNode _anchorFocus = FocusNode(debugLabel: 'fact_revenu imposable anchor');
  final FocusNode _glossHeadingFocus =
      FocusNode(debugLabel: 'fact_revenu gloss heading');

  bool _showNoSelectionError = false;
  bool _glossOpen = false;

  // Generation token: a callback captured in a superseded (disposed) generation
  // is a total no-op.
  late final Object _generation = Object();
  bool _questionFocusRequested = false;

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  @override
  void initState() {
    super.initState();
    // Arrival focuses the heading for the screen reader — the keyboard is NOT
    // raised (there is no text field on this screen).
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
    _anchorFocus.dispose();
    _glossHeadingFocus.dispose();
    super.dispose();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return r3Copy.containsKey(code) ? code : 'fr';
  }

  void _handleSelect(String band, Object generation) {
    if (_isStale(generation)) return;
    // Same-band reselect: idempotent no-op, no state churn (fact_revenu contract
    // same_band_reselect).
    if (widget.selectedBand == band) return;
    setState(() => _showNoSelectionError = false);
    widget.onSelectBand(band);
  }

  void _handleContinue(Object generation) {
    if (_isStale(generation)) return;
    // Continue is guarded and NEVER routes in R3: with nothing selected it
    // surfaces the no-selection guard; otherwise it validates in place.
    setState(() => _showNoSelectionError = widget.selectedBand == null);
  }

  void _openGloss(Object generation) {
    if (_isStale(generation)) return;
    setState(() => _glossOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(generation)) _glossHeadingFocus.requestFocus();
    });
  }

  void _dismissGloss(Object generation) {
    if (_isStale(generation)) return;
    setState(() => _glossOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(generation)) _anchorFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final copy = r3CopyFor(_localeCode(context));
    final year = widget.taxYear.toString();
    String c(String key) => copy[key]!;
    String withYear(String t) => t.replaceAll('{taxYear}', year);

    final selectedBand = widget.selectedBand;
    final selectedLabel = selectedBand == null
        ? null
        : c(r3Bands.firstWhere((b) => b.key == selectedBand).labelKey);

    final scroll = SingleChildScrollView(
      key: const ValueKey('scroll:fact_revenu'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            withYear(c('fact_revenu_eyebrow')),
            key: const ValueKey('text:fact_revenu.eyebrow'),
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: _moss,
            ),
          ),
          const SizedBox(height: 16),
          // The question stands ALONE (no body sentence) and takes arrival focus.
          Focus(
            key: const ValueKey('text:fact_revenu.question'),
            focusNode: _questionFocus,
            child: Semantics(
              header: true,
              child: Text(
                c('fact_revenu_question'),
                style: const TextStyle(
                  fontFamily: 'Gambarino',
                  fontSize: 30,
                  height: 1.12,
                  color: _ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // The `revenu imposable` glossary anchor: a named button (not a bare
          // styled span) opening the definition sheet — no route, no commit.
          _GlossAnchor(
            anchorKey: 'anchor:fact_revenu.imposable',
            focusNode: _anchorFocus,
            label: c('fact_revenu_gloss_imposable_term'),
            onPressed: () => _openGloss(generation),
          ),
          const SizedBox(height: 24),
          // Six band cards — single-select group, stable low->high, none
          // preselected. No wheel, no numeric keyboard.
          Semantics(
            key: const ValueKey('group:fact_revenu.bands'),
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final band in r3Bands)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BandCard(
                      bandKey: band.key,
                      label: c(band.labelKey),
                      selected: band.key == selectedBand,
                      onPressed: () => _handleSelect(band.key, generation),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _LinkAction(
            actionKey: 'action:fact_revenu.help_link',
            label: c('fact_revenu_help_link'),
            onPressed: () => _openGloss(generation),
          ),
          const SizedBox(height: 20),
          // Persistent, visible selection summary (announced region).
          if (selectedBand == null)
            _StatusChip(
              statusKey: 'status:fact_revenu.selection_none',
              text: c('fact_revenu_selection_none'),
              liveRegion: false,
            )
          else
            _SelectionSummary(
              label: c('fact_revenu_selection_label'),
              value: c('fact_revenu_selection_selected')
                  .replaceAll('{band}', selectedLabel!),
            ),
        ],
      ),
    );

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
                statusKey: 'status:fact_revenu.error_no_selection',
                text: c('fact_revenu_error_no_selection'),
                liveRegion: true,
                tone: _StatusTone.error,
              ),
              const SizedBox(height: 12),
            ],
            // Continue ABOVE back (three_regions.pinned_footer).
            _PrimaryButton(
              buttonKey: 'action:fact_revenu.continue',
              label: c('fact_revenu_continue'),
              filled: selectedBand != null,
              onPressed: () => _handleContinue(generation),
            ),
            const SizedBox(height: 8),
            _TextButton(
              buttonKey: 'action:fact_revenu.back',
              label: c('fact_revenu_back'),
              onPressed: widget.onBack,
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _glossOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: scroll), footer],
          ),
        ),
        if (_glossOpen)
          _ImposableGlossSheet(
            headingFocus: _glossHeadingFocus,
            term: c('fact_revenu_gloss_imposable_term'),
            definition: c('fact_revenu_gloss_imposable_def'),
            metaphor: c('fact_revenu_gloss_imposable_metaphor'),
            brutTerm: c('fact_revenu_gloss_brut_term'),
            brutDef: c('fact_revenu_gloss_brut_def'),
            dismissLabel: c('gloss_dismiss'),
            onDismiss: () => _dismissGloss(generation),
          ),
      ],
    );
  }
}

class _BandCard extends StatelessWidget {
  const _BandCard({
    required this.bandKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String bandKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('choice:fact_revenu.$bandKey'),
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? _forest : _porcelain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _forest : _bandBorder,
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
            color: isError ? _forest : _secondaryInk,
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
    // A focusable, announced region carrying the reviewed band atomically
    // (selection_refindable). The band is text, not colour-only.
    return Semantics(
      key: const ValueKey('status:fact_revenu.selection'),
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
              color: _moss,
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

class _GlossAnchor extends StatelessWidget {
  const _GlossAnchor({
    required this.anchorKey,
    required this.focusNode,
    required this.label,
    required this.onPressed,
  });

  final String anchorKey;
  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(anchorKey),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Focus(
        focusNode: focusNode,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(vertical: 8),
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
      ),
    );
  }
}

class _LinkAction extends StatelessWidget {
  const _LinkAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
  });

  final String actionKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(actionKey),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? _forest : const Color(0xFFDCE6D6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: filled ? _forest : _bandBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: filled ? _paper : _moss,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
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
              color: _secondaryInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// The `revenu imposable` glossary sheet: heading + one plain sentence + a
/// metaphor + a brut clarification (concepts_are_glossary_entries: revenu
/// imposable, brut). Focus-trapped until dismissed, then restores to the anchor.
class _ImposableGlossSheet extends StatelessWidget {
  const _ImposableGlossSheet({
    required this.headingFocus,
    required this.term,
    required this.definition,
    required this.metaphor,
    required this.brutTerm,
    required this.brutDef,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final FocusNode headingFocus;
  final String term;
  final String definition;
  final String metaphor;
  final String brutTerm;
  final String brutDef;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: const ValueKey('sheet:fact_revenu.gloss'),
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
                          key: const ValueKey('sheet:fact_revenu.gloss.heading'),
                          focusNode: headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              term,
                              style: const TextStyle(
                                fontFamily: 'Gambarino',
                                fontSize: 26,
                                height: 1.15,
                                color: _forest,
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
                        const SizedBox(height: 12),
                        Text(
                          metaphor,
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 16,
                            height: 1.45,
                            color: _secondaryInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // brut clarification (never a promise; brut != imposable).
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Supreme',
                              fontSize: 16,
                              height: 1.45,
                              color: _secondaryInk,
                            ),
                            children: [
                              TextSpan(
                                text: '$brutTerm — ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              TextSpan(text: brutDef),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          buttonKey: 'sheet:fact_revenu.gloss.dismiss',
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
            color: _bandBorder,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
