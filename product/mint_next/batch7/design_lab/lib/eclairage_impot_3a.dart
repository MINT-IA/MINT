// Batch21 R3 (ÉCLAIRAGE arc) runtime — the `eclairage_impot_3a` payoff node for
// the hidden design lab. It refreshes batch6 `result`: the FIRST moment the app
// renders something instead of collecting. It shows, for THIS YEAR'S tax, what a
// 3a contribution could change — a FOURCHETTE (never a single promised number,
// never an imperative — bug #1061), with the calc hypotheses visible and
// editable, and an estimate-not-advice disclaimer. Framed on the tax of the
// year, never on retirement.
//
// It implements product/mint_next/batch21/eclairage-scope.yaml render_contract
// (five states: nominal / precision_refined / pending_missing_income /
// non_applicable_source / low_income_floor) + r3-six-locale-copy.yaml +
// r3-engine-fixtures.yaml (every number engine-derived; NEVER re-derived here —
// NEVER#3). The amount is ALWAYS a range; the non_applicable gate NEVER shows a
// CHF amount; pending shows no number; low_income_floor shows an honest note.
//
// OFFLINE-LAB LIMITATION (documented, surfaced to the lead): the design lab is
// offline and fixture-bound. The sealed R3 fixtures cover only the célibataire /
// concubinage (is_married=false) profile at the LPP-affiliated cap (7258). The
// concubinage==célibataire equivalence is therefore GROUNDED (and proves the
// Swiss splitting ruling: concubinage never gets the married ×0.80). Married /
// registered-partnership and non-7258 versement re-invalidate their hypothesis
// row but keep the single-treatment fixture range: recomputing them honestly
// needs the backend fiscal engine, which the offline lab cannot call and must not
// re-implement in Dart (NEVER#3). Refinement is grounded on the single sealed
// exact point (85 000 -> 2213 -> 2100–2300).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'r3_eclairage_catalog.g.dart';

// Design-lab palette + R3 forest-green accent (see fact_revenu.dart).
const Color _paper = Color(0xFFFAF8F5);
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _secondaryInk = Color(0xFF4A4A4A);
const Color _border = Color(0xFFE2DED7);
const Color _forest = Color(0xFF1C3A2B);
const Color _moss = Color(0xFF4E6B4A);
const Color _bandBorder = Color(0xFFCAD8C3);

/// The civil-status hypothesis. is_married derives from civil_status ∈
/// {marie, partenariat_enregistre} ONLY — concubinage maps to the single
/// treatment (fault_5_civil_status_splitting_ruling), never the married ×0.80.
enum EclairageSituation { celibataire, marie, concubinage }

/// V4-1 (Codex P1-1): the lieu-row fixture disclosure, resolved by EXACT
/// locality. The hero range is ALWAYS the Fribourg CHEF-LIEU fixture (offline-
/// lab), so how much of a displayable lie the picked-commune label is depends
/// on the exact commune, not merely the canton:
///   * [none]        — the picked commune IS the chef-lieu (BFS 2196): the number
///                     is theirs, no disclosure.
///   * [intraCanton] — canton FR but NOT the chef-lieu (e.g. Bulle BFS 2125): the
///                     canton IS theirs, but their commune may differ from the
///                     chef-lieu the figure is computed at.
///   * [interCanton] — canton ≠ FR: the whole canton differs; the figure is a
///                     Fribourg example computed at refinement.
enum EclairageLieuDisclosure { none, intraCanton, interCanton }

/// The BFS number of the chef-lieu Fribourg — the exact commune the sealed R3
/// engine fixture is computed at (r3-engine-fixtures.yaml; r3ExampleCommune).
/// The disclosure classifier compares the picked commune against it.
const int eclairageFixtureChefLieuBfs = 2196;

/// Classifies the lieu-row disclosure from the picked commune's BFS + canton
/// CODE (locale-robust — never a label comparison). See [EclairageLieuDisclosure].
EclairageLieuDisclosure eclairageLieuDisclosureFor({
  required int bfs,
  required String cantonCode,
}) {
  if (bfs == eclairageFixtureChefLieuBfs) return EclairageLieuDisclosure.none;
  if (cantonCode == 'FR') return EclairageLieuDisclosure.intraCanton;
  return EclairageLieuDisclosure.interCanton;
}

/// The resolved render state (render_contract.states).
enum _RenderState {
  nominal,
  precisionRefined,
  pending,
  nonApplicable,
  lowIncomeFloor,
}

int _floor100(int n) => (n ~/ 100) * 100;

String _fmtChf(int n) {
  final s = n.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
    out.write(s[i]);
  }
  return out.toString();
}

class EclairageScreen extends StatefulWidget {
  const EclairageScreen({
    super.key,
    required this.taxYear,
    required this.band,
    required this.communeLabel,
    required this.cantonLabel,
    this.lieuDisclosure = EclairageLieuDisclosure.none,
    this.canContribute3a = true,
    this.initialSituation = EclairageSituation.celibataire,
    this.initialVersementChf = r3VersementChf,
    this.initialExactIncome,
    required this.onBack,
    required this.onContinue,
    required this.onEditRevenu,
    required this.onEditLieu,
    required this.onPendingComplete,
    this.onRefineSituation,
  });

  final int taxYear;

  /// The committed band enum (lt30 … gt150), or null -> pending_missing_income.
  final String? band;

  final String communeLabel;
  final String cantonLabel;

  /// V4-1 (Codex P1-1): the lieu-row fixture disclosure resolved by EXACT
  /// locality (never merely by canton). Computed by the journey from the picked
  /// commune's BFS + canton CODE (locale-robust) via [eclairageLieuDisclosureFor];
  /// [EclairageLieuDisclosure.none] for a chef-lieu pick or the harness default.
  final EclairageLieuDisclosure lieuDisclosure;

  /// The source-taxation / FATCA binary gate. false -> non_applicable_source
  /// (canContribute3a): NEVER a CHF amount under a false gate (fault_3).
  final bool canContribute3a;

  final EclairageSituation initialSituation;
  final int initialVersementChf;

  /// An exact taxable income pulled by value (refine), or null. When it equals
  /// the sealed grounded point it upgrades the render to precision_refined.
  final int? initialExactIncome;

  final VoidCallback onBack;

  /// continue -> next_action. NEVER routes in R3 (validation in place).
  final VoidCallback onContinue;

  /// edit_revenu -> reopen band choice (fact_revenu). Also the pending CTA.
  final VoidCallback onEditRevenu;

  /// edit_lieu -> reopen commune choice (fact_lieu).
  final VoidCallback onEditLieu;

  /// pending complete_action -> fact_revenu.
  final VoidCallback onPendingComplete;

  /// R4 (batch22) integration: the situation row's REFINE affordance ->
  /// fact_etat_civil. The situation VALUE stays display-only (no fabricated
  /// « marié » recompute); this is the new edge that opens the civil-status
  /// collection node. Null when the affordance is not wired (kept optional so
  /// the R3 harness constructions compile unchanged).
  final VoidCallback? onRefineSituation;

  @override
  State<EclairageScreen> createState() => _EclairageScreenState();
}

class _EclairageScreenState extends State<EclairageScreen> {
  final FocusNode _headingFocus = FocusNode(debugLabel: 'eclairage heading');
  final FocusNode _sheetHeadingFocus = FocusNode(debugLabel: 'eclairage sheet heading');
  // Restores focus to the anchor/row that opened the active overlay.
  final Map<String, FocusNode> _anchorFocus = <String, FocusNode>{};

  int? _exactIncome;

  // The active overlay, if any. Only one overlay open at a time.
  _Overlay? _overlay;
  String? _restoreAnchorId;

  late final Object _generation = Object();
  bool _headingFocusRequested = false;

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  FocusNode _anchor(String id) =>
      _anchorFocus.putIfAbsent(id, () => FocusNode(debugLabel: 'eclairage anchor $id'));

  @override
  void initState() {
    super.initState();
    _exactIncome = widget.initialExactIncome;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_headingFocusRequested) {
        _headingFocusRequested = true;
        _headingFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _headingFocus.dispose();
    _sheetHeadingFocus.dispose();
    for (final node in _anchorFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return r3Copy.containsKey(code) ? code : 'fr';
  }

  /// The band an exact taxable income falls into (by the sealed fixture edges),
  /// or null if it lands outside every band. Refinement is pulled by value: any
  /// entered income maps to ITS band -> that band's fixture-grounded range (lead
  /// ruling 2026-08-05), never a fabricated point.
  String? _bandForIncome(int income) {
    for (final b in r3Bands) {
      final high = b.highEdge;
      if (income >= b.lowEdge && (high == null || income < high)) return b.key;
    }
    return null;
  }

  /// The effective band the payoff renders: an entered exact income maps to its
  /// band (recompute by band mapping), otherwise the committed band.
  String? get _effectiveBand {
    final exact = _exactIncome;
    if (exact != null) {
      final mapped = _bandForIncome(exact);
      if (mapped != null) return mapped;
    }
    return widget.band;
  }

  R3Band? get _bandData => _effectiveBand == null
      ? null
      : r3Bands.firstWhere((b) => b.key == _effectiveBand);

  // The range tightens ONLY at the single fixture-covered exact point (85 000 ->
  // b70_100 -> 2 100 à 2 300); every other exact value renders its band range,
  // never the tightened window (lead ruling: a non-85k point never tightens).
  bool get _refineGrounded =>
      _exactIncome == r3RefinedExactIncomeChf && _effectiveBand == 'b70_100';

  _RenderState _resolveState() {
    if (!widget.canContribute3a) return _RenderState.nonApplicable;
    if (_bandData == null) return _RenderState.pending;
    if (_bandData!.renderState == 'low_income_floor') {
      return _RenderState.lowIncomeFloor;
    }
    if (_refineGrounded) return _RenderState.precisionRefined;
    return _RenderState.nominal;
  }

  void _openOverlay(_Overlay overlay, {String? restoreAnchorId}) {
    setState(() {
      _overlay = overlay;
      _restoreAnchorId = restoreAnchorId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(_generation)) _sheetHeadingFocus.requestFocus();
    });
  }

  void _closeOverlay(Object generation) {
    if (_isStale(generation)) return;
    final restore = _restoreAnchorId;
    setState(() {
      _overlay = null;
      _restoreAnchorId = null;
    });
    if (restore != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isStale(generation)) _anchor(restore).requestFocus();
      });
    }
  }

  void _saveExactIncome(int? value, Object generation) {
    if (_isStale(generation)) return;
    // Refinement is pulled by value and grounded only on the sealed exact point.
    setState(() => _exactIncome = value);
    _closeOverlay(generation);
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final copy = r3CopyFor(_localeCode(context));
    final state = _resolveState();

    final body = switch (state) {
      _RenderState.pending => _pendingBody(copy, generation),
      _RenderState.nonApplicable => _nonApplicableBody(copy, generation),
      _RenderState.lowIncomeFloor => _lowIncomeFloorBody(copy, generation),
      _RenderState.nominal ||
      _RenderState.precisionRefined =>
        _resultBody(copy, generation, refined: state == _RenderState.precisionRefined),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: _overlay != null,
          child: body,
        ),
        if (_overlay != null) _buildOverlay(copy, generation),
      ],
    );
  }

  // --- eyebrow (carries the 3a glossary anchor) ---
  Widget _eyebrow(Map<String, String> copy, Object generation) {
    final text = copy['eclairage_eyebrow']!
        .replaceAll('{taxYear}', widget.taxYear.toString());
    return Semantics(
      key: const ValueKey('text:eclairage.eyebrow'),
      button: true,
      label: text,
      onTap: () => _openOverlay(_Overlay.gloss3a, restoreAnchorId: 'gloss_3a'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _anchor('gloss_3a'),
        onPressed: () =>
            _openOverlay(_Overlay.gloss3a, restoreAnchorId: 'gloss_3a'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: _moss,
            ),
          ),
        ),
      ),
    );
  }

  // --- footer (continue above back; pending swaps the primary) ---
  Widget _footer(
    Map<String, String> copy,
    Object generation, {
    required bool pending,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending)
              _PrimaryButton(
                buttonKey: 'action:eclairage.edit_revenu',
                label: copy['eclairage_pending_action']!,
                filled: true,
                onPressed: widget.onPendingComplete,
              )
            else
              _PrimaryButton(
                buttonKey: 'action:eclairage.continue',
                label: copy['eclairage_continue']!,
                filled: true,
                onPressed: widget.onContinue,
              ),
            const SizedBox(height: 8),
            _TextButton(
              buttonKey: 'action:eclairage.back',
              label: copy['eclairage_back']!,
              onPressed: widget.onBack,
            ),
          ],
        ),
      ),
    );
  }

  // --- nominal / precision_refined ---
  Widget _resultBody(
    Map<String, String> copy,
    Object generation, {
    required bool refined,
  }) {
    final band = _bandData!;
    final locale = _localeCode(context);
    final bandLabel = copy[band.labelKey]!;

    // The amount range — floored to 100, never inflated, never collapsed to a
    // point (P4). Refined ranges use the sealed grounded window.
    final String amountText;
    if (refined) {
      amountText = copy['eclairage_amount']!
          .replaceAll('{low}', _fmtChf(r3RefinedRangeLow))
          .replaceAll('{high}', _fmtChf(r3RefinedRangeHigh));
    } else if (band.savingHigh == null) {
      // Open-topped gt150 — a lower-bounded estimate, never a single number.
      amountText = copy['eclairage_amount_open']!
          .replaceAll('{low}', _fmtChf(_floor100(band.savingLow)));
    } else {
      amountText = copy['eclairage_amount']!
          .replaceAll('{low}', _fmtChf(_floor100(band.savingLow)))
          .replaceAll('{high}', _fmtChf(_floor100(band.savingHigh!)));
    }
    final caption = refined
        ? copy['eclairage_amount_caption_refined']!
        : copy['eclairage_amount_caption']!;

    // Each hyp row splits its localized template on ' · ' into (label, value).
    // Phase B — année display_only, comprehension anchor, refine deferred to the
    // future year-refinement wave.
    final anneeValue = copy['eclairage_hyp_annee']!
        .split(' · ')
        .last
        .replaceAll('{taxYear}', widget.taxYear.toString());
    final revenuValue = refined
        ? '${_fmtChf(_exactIncome!)} CHF'
        : copy['eclairage_hyp_revenu']!
            .split(' · ')
            .last
            .replaceAll('{band}', bandLabel);
    final lieuValue = copy['eclairage_hyp_lieu']!
        .split(' · ')
        .last
        .replaceAll('{commune}', widget.communeLabel)
        .replaceAll('{canton}', widget.cantonLabel);

    final scroll = SingleChildScrollView(
      key: const ValueKey('scroll:eclairage'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrow(copy, generation),
          const SizedBox(height: 20),
          // Mechanism line with the `déduit` deduction anchor.
          _mechanismLine(copy, locale, generation),
          const SizedBox(height: 28),
          // The payoff amount — atomic live-region result (range + unit).
          Focus(
            focusNode: _headingFocus,
            child: Semantics(
              key: const ValueKey('amount:eclairage.range'),
              container: true,
              liveRegion: true,
              label: amountText,
              excludeSemantics: true,
              child: Text(
                amountText,
                key: const ValueKey('text:eclairage.range_value'),
                style: const TextStyle(
                  fontFamily: 'Gambarino',
                  fontSize: 44,
                  height: 1.05,
                  color: _forest,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            caption,
            key: const ValueKey('text:eclairage.caption'),
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 17,
              height: 1.4,
              color: _secondaryInk,
            ),
          ),
          const SizedBox(height: 28),
          // Hypotheses block.
          Text(
            copy['eclairage_hyp_label']!,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: _moss,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            key: const ValueKey('group:eclairage.hypotheses'),
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HypRow(
                  rowKey: 'row:eclairage.hyp.annee',
                  label: copy['eclairage_hyp_annee']!.split(' · ').first,
                  value: anneeValue,
                  // Phase B — année display_only, comprehension anchor, refine
                  // deferred to the future year-refinement wave.
                  displayOnly: true,
                ),
                _HypRow(
                  rowKey: 'row:eclairage.hyp.revenu',
                  actionKey: 'action:eclairage.refine_revenu',
                  focusNode: _anchor('refine_revenu'),
                  label: copy['eclairage_hyp_revenu']!.split(' · ').first,
                  value: revenuValue,
                  badge: refined ? copy['provenance_exact'] : null,
                  onTap: () => _openOverlay(
                    _Overlay.refineRevenu,
                    restoreAnchorId: 'refine_revenu',
                  ),
                ),
                _HypRow(
                  rowKey: 'row:eclairage.hyp.versement',
                  label: copy['eclairage_hyp_versement']!.split(' · ').first,
                  value: '${_fmtChf(widget.initialVersementChf)} CHF',
                  // DISPLAY-ONLY in R3 (lead ruling 2026-08-05): the versement
                  // shows the LPP plafond hypothesis (7258). The amount CHOICE is
                  // the R4 scenarios_versement screen's job (its own executed
                  // fixtures 2000/4000/7258). A cosmetic inline edit is forbidden
                  // (#1061); duplicating the choice here would be churn.
                  displayOnly: true,
                ),
                _HypRow(
                  rowKey: 'row:eclairage.hyp.situation',
                  label: copy['eclairage_hyp_situation']!.split(' · ').first,
                  value: _situationLabel(copy),
                  // DISPLAY-ONLY value (ANCHOR''' amendment, LSFin ground): the
                  // situation is a STATED assumption, never an inline toggle. A
                  // « marié » toggle would surface a possibly-overstated splitting
                  // economy the user does not own (×0.80 on a forfait chef-lieu
                  // multiplier). concubinage == célibataire (no ×0.80) stays graven.
                  displayOnly: true,
                  // MARRIED-ONLY co-located caveat (mint-experience P1, lead
                  // arbitration VAGUE GROUPÉE): when the user is marié·e/pacsé·e
                  // the hero range is STILL the single-person fixture figure (no
                  // fabricated ×0.80, NEVER#3 — backend L2 sensitivity owns the
                  // couple-income recompute). Say so, co-located with the row.
                  // célibataire AND concubinage are is_married=false — the number
                  // IS theirs, so no caveat is shown.
                  caveat: widget.initialSituation == EclairageSituation.marie
                      ? copy['eclairage_situation_caveat_marie']
                      : null,
                  // R4 (batch22) integration: the situation refine is now a real
                  // edge to the civil-status collection node (fact_etat_civil).
                  // The value stays display-only until the married recompute
                  // lands (later backend batch) — this opens the collection, it
                  // does NOT fabricate a range here.
                  refineActionKey: widget.onRefineSituation == null
                      ? null
                      : 'action:eclairage.refine_situation',
                  refineLabel: copy['eclairage_refine_situation'],
                  refineFocusNode: _anchor('refine_situation'),
                  onRefine: widget.onRefineSituation,
                ),
                _HypRow(
                  rowKey: 'row:eclairage.hyp.lieu',
                  actionKey: 'action:eclairage.edit_lieu',
                  focusNode: _anchor('edit_lieu'),
                  label: copy['eclairage_hyp_lieu']!.split(' · ').first,
                  value: lieuValue,
                  // V4-1 (Codex P1-1) FIXTURE-LOCALITY disclosure, co-located
                  // under the lieu row: the hero range is ALWAYS the Fribourg
                  // CHEF-LIEU fixture figure (offline-lab limitation), so the
                  // picked-commune label on that number is a displayable lie
                  // unless disclosed BY EXACT LOCALITY. The chef-lieu pick itself
                  // needs no disclosure (the number is theirs); a different FR
                  // commune needs the INTRA-cantonal disclosure (canton theirs,
                  // commune may differ); another canton needs the INTER-cantonal
                  // one. ONE caveat key renders whichever applies. The condition
                  // is on the BFS + canton CODE (locale-robust), computed by the
                  // journey — never a locale-dependent label comparison.
                  caveat: switch (widget.lieuDisclosure) {
                    EclairageLieuDisclosure.none => null,
                    EclairageLieuDisclosure.intraCanton =>
                      copy['eclairage_lieu_intra_canton_disclosure'],
                    EclairageLieuDisclosure.interCanton =>
                      copy['eclairage_lieu_fixture_disclosure'],
                  },
                  caveatKey: 'text:eclairage.lieu_caveat',
                  onTap: widget.onEditLieu,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (refined)
            Text(
              copy['eclairage_refine_hint']!,
              key: const ValueKey('text:eclairage.refine_hint'),
              style: const TextStyle(
                fontFamily: 'Supreme',
                fontSize: 14,
                color: _moss,
              ),
            )
          else
            Semantics(
              container: true,
              child: Text(
                copy['eclairage_hyp_edit_hint']!,
                key: const ValueKey('text:eclairage.edit_hint'),
                style: const TextStyle(
                  fontFamily: 'Supreme',
                  fontSize: 14,
                  color: _moss,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Stated (non-editable) assumptions with the `imposé ordinairement`
          // guardrail anchor.
          _assumptionsLine(copy, generation),
          const SizedBox(height: 20),
          // Estimate-not-advice disclaimer. Kept in the scroll region so it
          // stays screen-reader reachable AND never clips at 2x text scale on a
          // 320pt viewport (pinning it overflows a compact screen).
          Semantics(
            container: true,
            child: Text(
              copy['eclairage_disclaimer']!,
              key: const ValueKey('text:eclairage.disclaimer'),
              style: const TextStyle(
                fontFamily: 'Supreme',
                fontSize: 14,
                height: 1.4,
                color: _secondaryInk,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: scroll),
        _footer(copy, generation, pending: false),
      ],
    );
  }

  // The mechanism line is a named button opening the `déduction` glossary; the
  // conjugated verb (`déduit` …) is emphasised as the visual anchor.
  Widget _mechanismLine(
    Map<String, String> copy,
    String locale,
    Object generation,
  ) {
    final text = copy['eclairage_mechanism']!;
    final emphasis = r3MechanismEmphasis[locale] ?? r3MechanismEmphasis['fr']!;
    final idx = text.indexOf(emphasis);
    const baseStyle = TextStyle(
      fontFamily: 'Supreme',
      fontSize: 20,
      height: 1.4,
      color: _ink,
    );
    const emphasisStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: _forest,
      decoration: TextDecoration.underline,
      decorationColor: _forest,
    );
    final children = <InlineSpan>[];
    if (idx >= 0) {
      if (idx > 0) children.add(TextSpan(text: text.substring(0, idx)));
      children.add(TextSpan(text: emphasis, style: emphasisStyle));
      children.add(TextSpan(text: text.substring(idx + emphasis.length)));
    } else {
      children.add(TextSpan(text: text));
    }
    return Semantics(
      key: const ValueKey('text:eclairage.mechanism'),
      button: true,
      label: '$text — ${copy['eclairage_gloss_deduction_term']}',
      onTap: () => _openOverlay(_Overlay.glossDeduction,
          restoreAnchorId: 'gloss_deduction'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _anchor('gloss_deduction'),
        // The mechanism line IS the deduction glossary opener (control
        // open_deduction_glossary, node_contracts.eclairage_impot_3a). The
        // action key names the control explicitly for the integration
        // journey; the enclosing `text:eclairage.mechanism` semantics stays.
        actionKey: const ValueKey('action:eclairage.open_deduction_glossary'),
        onPressed: () => _openOverlay(_Overlay.glossDeduction,
            restoreAnchorId: 'gloss_deduction'),
        child: Text.rich(TextSpan(style: baseStyle, children: children)),
      ),
    );
  }

  // The stated (non-editable) assumptions line, a named button opening the
  // `imposé ordinairement` source-taxation guardrail glossary.
  Widget _assumptionsLine(Map<String, String> copy, Object generation) {
    final text = copy['eclairage_assumptions']!;
    final term = copy['eclairage_gloss_ordinaire_term']!;
    final idx = text.indexOf(term);
    const baseStyle = TextStyle(
      fontFamily: 'Supreme',
      fontSize: 15,
      height: 1.45,
      color: _secondaryInk,
    );
    const emphasisStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: _forest,
      decoration: TextDecoration.underline,
      decorationColor: _forest,
    );
    final children = <InlineSpan>[];
    if (idx >= 0) {
      if (idx > 0) children.add(TextSpan(text: text.substring(0, idx)));
      children.add(TextSpan(text: term, style: emphasisStyle));
      children.add(TextSpan(text: text.substring(idx + term.length)));
    } else {
      children.add(TextSpan(text: text));
    }
    return Semantics(
      key: const ValueKey('text:eclairage.assumptions'),
      button: true,
      label: '$text — $term',
      onTap: () => _openOverlay(_Overlay.glossOrdinaire,
          restoreAnchorId: 'gloss_ordinaire'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _anchor('gloss_ordinaire'),
        onPressed: () => _openOverlay(_Overlay.glossOrdinaire,
            restoreAnchorId: 'gloss_ordinaire'),
        child: Text.rich(TextSpan(style: baseStyle, children: children)),
      ),
    );
  }

  String _situationLabel(Map<String, String> copy) =>
      switch (widget.initialSituation) {
        EclairageSituation.celibataire => copy['eclairage_situation_celibataire']!,
        EclairageSituation.marie => copy['eclairage_situation_marie']!,
        EclairageSituation.concubinage => copy['eclairage_situation_concubinage']!,
      };

  // --- pending_missing_income ---
  Widget _pendingBody(Map<String, String> copy, Object generation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:eclairage'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eyebrow(copy, generation),
                const SizedBox(height: 120),
                Semantics(
                  key: const ValueKey('status:eclairage.pending'),
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Focus(
                        focusNode: _headingFocus,
                        child: Semantics(
                          header: true,
                          child: Text(
                            copy['eclairage_pending_title']!,
                            style: const TextStyle(
                              fontFamily: 'Gambarino',
                              fontSize: 32,
                              height: 1.1,
                              color: _forest,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        copy['eclairage_pending_revenu']!,
                        style: const TextStyle(
                          fontFamily: 'Supreme',
                          fontSize: 17,
                          height: 1.4,
                          color: _secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _footer(copy, generation, pending: true),
      ],
    );
  }

  // --- non_applicable_source (NEVER a CHF amount) ---
  Widget _nonApplicableBody(Map<String, String> copy, Object generation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:eclairage'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eyebrow(copy, generation),
                const SizedBox(height: 96),
                Semantics(
                  key: const ValueKey('status:eclairage.na'),
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Focus(
                        focusNode: _headingFocus,
                        child: Semantics(
                          header: true,
                          child: Text(
                            copy['eclairage_na_title']!,
                            style: const TextStyle(
                              fontFamily: 'Gambarino',
                              fontSize: 32,
                              height: 1.1,
                              color: _forest,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        copy['eclairage_na_body']!,
                        style: const TextStyle(
                          fontFamily: 'Supreme',
                          fontSize: 17,
                          height: 1.45,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _LinkAction(
                  actionKey: 'action:eclairage.na_action',
                  label: copy['eclairage_na_action']!,
                  focusNode: _anchor('gloss_ordinaire'),
                  onPressed: () => _openOverlay(
                    _Overlay.glossOrdinaire,
                    restoreAnchorId: 'gloss_ordinaire',
                  ),
                ),
              ],
            ),
          ),
        ),
        _footer(copy, generation, pending: false),
      ],
    );
  }

  // --- low_income_floor (honest note, no number) ---
  Widget _lowIncomeFloorBody(Map<String, String> copy, Object generation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:eclairage'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eyebrow(copy, generation),
                const SizedBox(height: 28),
                _mechanismLine(copy, _localeCode(context), generation),
                const SizedBox(height: 28),
                Semantics(
                  key: const ValueKey('status:eclairage.low_income_floor'),
                  container: true,
                  liveRegion: true,
                  child: Focus(
                    focusNode: _headingFocus,
                    child: Text(
                      copy['eclairage_zero_income']!,
                      style: const TextStyle(
                        fontFamily: 'Gambarino',
                        fontSize: 26,
                        height: 1.2,
                        color: _forest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _assumptionsLine(copy, generation),
                const SizedBox(height: 20),
                Semantics(
                  container: true,
                  child: Text(
                    copy['eclairage_disclaimer']!,
                    key: const ValueKey('text:eclairage.disclaimer'),
                    style: const TextStyle(
                      fontFamily: 'Supreme',
                      fontSize: 14,
                      height: 1.4,
                      color: _secondaryInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _footer(copy, generation, pending: false),
      ],
    );
  }

  // --- overlays ---
  Widget _buildOverlay(Map<String, String> copy, Object generation) {
    switch (_overlay!) {
      case _Overlay.gloss3a:
        return _GlossSheet(
          sheetId: 'sheet:eclairage.gloss.pilier3a',
          headingFocus: _sheetHeadingFocus,
          term: copy['eclairage_gloss_3a_term']!,
          definition: copy['eclairage_gloss_3a_def']!,
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.glossDeduction:
        return _GlossSheet(
          sheetId: 'sheet:eclairage.gloss.deduction',
          headingFocus: _sheetHeadingFocus,
          term: copy['eclairage_gloss_deduction_term']!,
          definition: copy['eclairage_gloss_deduction_def']!,
          metaphor: copy['eclairage_gloss_deduction_metaphor'],
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.glossOrdinaire:
        return _GlossSheet(
          sheetId: 'sheet:eclairage.gloss.ordinaire',
          headingFocus: _sheetHeadingFocus,
          term: copy['eclairage_gloss_ordinaire_term']!,
          definition: copy['eclairage_gloss_ordinaire_def']!,
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.refineRevenu:
        return _RefineRevenuSheet(
          headingFocus: _sheetHeadingFocus,
          copy: copy,
          initial: _exactIncome,
          onSave: (v) => _saveExactIncome(v, generation),
          onEditBand: () {
            _closeOverlay(generation);
            widget.onEditRevenu();
          },
          onDismiss: () => _closeOverlay(generation),
        );
    }
  }
}

enum _Overlay {
  gloss3a,
  glossDeduction,
  glossOrdinaire,
  refineRevenu,
}

/// Wraps [child] so [onPressed] fires on pointer tap AND on real keyboard/switch
/// activation (Enter/Space -> ActivateIntent) once the control is focused. Puts
/// the control in the focus tree (a physical Tab/switch stop) on top of the
/// enclosing Semantics button role. Any [focusNode] the caller owns (for focus
/// restoration) is preserved, and any [actionKey] a finder needs stays on the
/// tap target.
class _Activable extends StatelessWidget {
  const _Activable({
    required this.onPressed,
    required this.child,
    this.focusNode,
    this.actionKey,
  });

  final VoidCallback onPressed;
  final Widget child;
  final FocusNode? focusNode;
  final Key? actionKey;

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
        key: actionKey,
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

class _HypRow extends StatelessWidget {
  const _HypRow({
    required this.rowKey,
    required this.label,
    required this.value,
    this.actionKey,
    this.focusNode,
    this.onTap,
    this.badge,
    this.isLast = false,
    this.displayOnly = false,
    this.caveat,
    this.caveatKey = 'text:eclairage.situation_caveat',
    this.refineActionKey,
    this.refineLabel,
    this.refineFocusNode,
    this.onRefine,
  });

  final String rowKey;
  final String? actionKey;
  final FocusNode? focusNode;
  final String label;
  final String value;
  final String? badge;
  final VoidCallback? onTap;
  final bool isLast;

  /// An optional CO-LOCATED display-only caveat rendered directly under the
  /// row's label·value (used by the R3 situation row when the user is married:
  /// the fixture range is still a single-person figure — no fabricated ×0.80,
  /// NEVER#3). It renders inside the row's Semantics node and is folded into the
  /// row's spoken label so a screen reader announces it WITH the row. Never a
  /// promised number, never a promised delay — an honest bound on the estimate.
  final String? caveat;

  /// The ValueKey of the co-located caveat Text. Defaults to the situation-row
  /// married caveat; the lieu row (V3-1 canton disclosure) overrides it so the
  /// two co-located caveats are distinct finder targets.
  final String caveatKey;

  /// An optional REFINE affordance rendered as a DISTINCT tap target attached
  /// below a display-only row (R4 situation row): the value stays read-only, the
  /// refine opens the collection node. A separate button role, never conflated
  /// with the row's stated value.
  final String? refineActionKey;
  final String? refineLabel;
  final FocusNode? refineFocusNode;
  final VoidCallback? onRefine;

  /// A DISPLAY-ONLY row is a stated assumption, not an editable control: no
  /// button role, no tap target, no chevron affordance, no action key. Used by
  /// the R3 situation row (display_only, refine deferred to the état-civil batch;
  /// a false inline toggle would surface a possibly-overstated economy).
  final bool displayOnly;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // label · value (+ optional badge) as one wrapping rich text so a 320pt
        // viewport at 2x text scale never overflows.
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'Supreme',
                fontSize: 16,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label  ·  ',
                  style: const TextStyle(color: _moss),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (badge != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _bandBorder,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _forest,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!displayOnly) ...[
          const SizedBox(width: 10),
          // Chevron affordance — U+203A (›), decorative.
          const ExcludeSemantics(
            child: Text(
              '›',
              style: TextStyle(
                fontFamily: 'Supreme',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _moss,
              ),
            ),
          ),
        ],
      ],
    );
    // A co-located caveat (situation row, married) renders directly under the
    // label·value, inside the row. excludeSemantics on the row node strips the
    // caveat Text's own semantics, so it is announced only once — via the folded
    // row label below — never doubled.
    final caveatText = caveat;
    final inner = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: caveatText == null
          ? content
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 6),
                Text(
                  caveatText,
                  key: ValueKey<String>(caveatKey),
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontSize: 13,
                    height: 1.4,
                    color: _moss,
                  ),
                ),
              ],
            ),
    );
    final row = Semantics(
      key: ValueKey(rowKey),
      button: !displayOnly,
      readOnly: displayOnly,
      // Interactive rows are announced editable (label + value + hint); the
      // display-only row is announced as a stated, read-only assumption. A
      // co-located caveat is folded into the same utterance (announced WITH the
      // row, not as a separate node).
      label: caveatText == null ? '$label : $value' : '$label : $value. $caveatText',
      hint: badge,
      onTap: displayOnly ? null : onTap,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isLast
              ? const Border(bottom: BorderSide(color: _border))
              : null,
        ),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: displayOnly
              ? inner
              : _Activable(
                  focusNode: focusNode,
                  // Explicit ValueKey<String>: an interactive row always carries
                  // a non-null actionKey, and the finders match the exact
                  // ValueKey<String> type.
                  actionKey: ValueKey<String>(actionKey!),
                  onPressed: onTap!,
                  child: inner,
                ),
        ),
      ),
    );

    final refineKey = refineActionKey;
    final refine = onRefine;
    if (refineKey == null || refine == null) return row;
    // The display-only value keeps its read-only role; the refine is a SEPARATE
    // named button below it (the new R4 edge to the civil-status node).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _LinkAction(
              actionKey: refineKey,
              label: refineLabel!,
              focusNode: refineFocusNode,
              onPressed: refine,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlossSheet extends StatelessWidget {
  const _GlossSheet({
    required this.sheetId,
    required this.headingFocus,
    required this.term,
    required this.definition,
    required this.dismissLabel,
    required this.onDismiss,
    this.metaphor,
  });

  final String sheetId;
  final FocusNode headingFocus;
  final String term;
  final String definition;
  final String? metaphor;
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
                        if (metaphor != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            metaphor!,
                            key: ValueKey('$sheetId.metaphor'),
                            style: const TextStyle(
                              fontFamily: 'Supreme',
                              fontSize: 16,
                              height: 1.45,
                              color: _secondaryInk,
                            ),
                          ),
                        ],
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

class _RefineRevenuSheet extends StatefulWidget {
  const _RefineRevenuSheet({
    required this.headingFocus,
    required this.copy,
    required this.initial,
    required this.onSave,
    required this.onEditBand,
    required this.onDismiss,
  });

  final FocusNode headingFocus;
  final Map<String, String> copy;
  final int? initial;
  final ValueChanged<int?> onSave;
  final VoidCallback onEditBand;
  final VoidCallback onDismiss;

  @override
  State<_RefineRevenuSheet> createState() => _RefineRevenuSheetState();
}

class _RefineRevenuSheetState extends State<_RefineRevenuSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: const ValueKey('sheet:eclairage.refine_revenu'),
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SheetHandle(),
                        const SizedBox(height: 16),
                        Focus(
                          key: const ValueKey(
                              'sheet:eclairage.refine_revenu.heading'),
                          focusNode: widget.headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.copy['eclairage_exact_revenu_title']!,
                              style: const TextStyle(
                                fontFamily: 'Gambarino',
                                fontSize: 24,
                                color: _forest,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Optional: not pushed by the form (principle 2).
                        Text(
                          widget.copy['eclairage_exact_revenu_note']!,
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 16,
                            height: 1.45,
                            color: _secondaryInk,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _NumberField(
                          fieldKey: 'sheet:eclairage.refine_revenu.field',
                          controller: _controller,
                          hint: widget.copy['eclairage_exact_revenu_placeholder'],
                          suffix: 'CHF',
                        ),
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          buttonKey: 'sheet:eclairage.refine_revenu.save',
                          label: widget.copy['eclairage_exact_save']!,
                          filled: true,
                          onPressed: () {
                            final parsed = int.tryParse(
                              _controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
                            );
                            widget.onSave(parsed);
                          },
                        ),
                        const SizedBox(height: 8),
                        // edit_revenu escape: change the band instead.
                        _TextButton(
                          buttonKey: 'action:eclairage.edit_revenu',
                          label: widget.copy['fact_revenu_change'] ??
                              widget.copy['eclairage_back']!,
                          onPressed: widget.onEditBand,
                        ),
                        const SizedBox(height: 4),
                        _TextButton(
                          buttonKey: 'sheet:eclairage.refine_revenu.dismiss',
                          label: widget.copy['eclairage_back']!,
                          onPressed: widget.onDismiss,
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

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.controller,
    this.hint,
    this.suffix,
  });

  final String fieldKey;
  final TextEditingController controller;
  final String? hint;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(fieldKey),
      container: true,
      textField: true,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontFamily: 'Supreme',
          fontSize: 20,
          color: _ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          suffixText: suffix,
          filled: true,
          fillColor: _porcelain,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bandBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _bandBorder),
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
        // The caller's focusNode (na_action restoration) lives on the _Activable
        // so keyboard activation and focus restoration target the same node.
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
              color: _secondaryInk,
            ),
          ),
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
