// Batch22 R4 (FERMETURE DE LA BOUCLE) runtime — the `scenarios_versement` node
// for the hidden design lab. It refreshes batch6 `next_action`: after the R3
// éclairage payoff, this answers "et maintenant ?" — a small SPECTRUM of
// scenarios (2-3 discrete amounts, low to the maximum) with the estimated tax
// effect of each, in francs, always a RANGE, never a bare number, never an
// imperative to contribute (regression #1061). It states the LOCKED LIQUIDITY
// cost honestly (anti-dark-pattern) and never credits a benefit above the
// remaining 3a room (fault_B).
//
// It implements product/mint_next/batch22/scenarios_versement-scope.yaml
// render_contract (4 states: pending_missing_fact / marge_epuisee_overcontribution
// / marge_reduite / nominal, resolved via state_precedence RELATIVE to the
// DERIVED annual cap) + r4-six-locale-copy.yaml + r4-engine-fixtures.yaml
// (every number engine-derived; NEVER re-derived here — NEVER#3). The annual
// cap DERIVES from lpp_affiliation + revenu (ceiling_derivation_opp3: affilié
// -> 7 258 flat ; non-affilié -> min(0.20 * revenu net, 36 288)) — this
// arithmetic RULE is explicitly GRAVED by the sealed contract as a runtime
// obligation (its 3 mandatory_contract_test_cases "gouvernent le contrat ; le
// runtime devra les faire passer"), distinct from the DEFERRED decision of
// ROUTING the non-affilié branch into the live linear journey
// (deferred_integration.non_affilie_ceiling_routing). This file implements the
// rule, not the routing.
//
// OFFLINE-LAB LIMITATION (documented, surfaced to the lead, mirrors
// eclairage_impot_3a.dart's precedent): the sealed r4-engine-fixtures.yaml
// covers exactly ONE grounded scenario spectrum (affilié, canton FR, tranche
// 70-100k, célibataire, déjà-versé 0 -> nominal ; déjà-versé 4 000 -> marge
// réduite) and ONE grounded non-affilié exact point (revenu 20 000 -> plafond
// dérivé 4 000). Contributed amounts outside {0, 4 000} on the affilié path
// render the state correctly (cap/remaining/excess arithmetic is honest) but
// show NO scenario rows — inventing a fourchette for an ungrounded amount
// would violate 0-trust/NEVER#3. Similarly, a custom own_amount value that
// does not land on the remaining-room boundary or an existing anchor renders
// with NO numeric effect (the amount alone), except in the non-affilié
// overlay, whose note is qualitative and therefore safe to reuse for ANY
// deductible amount (it never states a number).
//
// CONTRACT GAP note: two copy keys the sealed r4-six-locale-copy.yaml scope
// names but does not provide (`scenarios_excess_note`,
// `scenarios_own_amount_save`) and four per-fact pending nouns are filled as
// documented gap-fills in r4_fermeture_catalog.g.dart (same pattern R3 used
// for gloss_dismiss / provenance_exact / eclairage_amount_open).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'r4_fermeture_catalog.g.dart';

// Design-lab palette (mirrors batch21's private tokens; see fact_revenu.dart /
// eclairage_impot_3a.dart in this same lib dir).
const Color _paper = Color(0xFFFAF8F5);
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _border = Color(0xFFE2DED7);
const Color _forest = Color(0xFF1C3A2B); // 10.4:1 on _paper (R3-proven accent).
const Color _cardBorder = Color(0xFFCAD8C3);

/// The R4 secondary-text token — DARKENED per the sealed contract's
/// MUST_FIX_BEFORE_GREEN obligation (accessibility_contract.
/// secondary_text_contrast_binding, scenarios_versement-scope.yaml:508-516).
/// The flagged mockup sauge — rgb(110,140,116) on paper rgb(246,244,238) —
/// measures 3.37:1 (below the 4.5:1 functional-text floor; these ranges ARE
/// the decisional information, never decorative). This darkened token —
/// rgb(86,114,92), i.e. 0xFF56725C — measures 4.83:1 on the same paper
/// background (WCAG relative-luminance formula, verified by
/// `test/dev_scenarios_versement_r4_test.dart` "darkened sauge token clears
/// 4.5:1"). Applied to every `applies_to` surface: eyebrow, effect ranges,
/// amount_max/rest suffix, commune caveat, disclaimer, plafond20 notes.
const Color _sauge = Color(0xFF56725C);

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

enum _RenderState { pending, margeEpuisee, margeReduite, nominal }

enum _Overlay { glossPlafond, glossMarge, glossBloque, ownAmount }

class ScenariosVersementScreen extends StatefulWidget {
  const ScenariosVersementScreen({
    super.key,
    required this.taxYear,
    required this.commune,
    required this.canton,
    required this.band,
    required this.affiliated,
    this.contributedChf = 0,
    this.nonAffiliatedIncomeChf = r4Plafond20DemoIncomeChf,
    required this.onBack,
    required this.onContinue,
    required this.onPendingComplete,
    required this.onKeepLocalReference,
    required this.onReviewExistingOvercontribution,
  });

  final int? taxYear;
  final String? commune;
  final String? canton;

  /// The committed taxable-income band (fact_revenu enum). OFFLINE-LAB
  /// LIMITATION: only 'b70_100' has a grounded scenario spectrum.
  final String? band;

  /// lpp_affiliation. null -> pending_missing_fact (a critical input).
  final bool? affiliated;

  /// contributed_amount (navigation.yaml:260). Default 0 (contribution_status
  /// = no). Not a critical input — it always has a value.
  final int contributedChf;

  /// The non-affilié "revenu net de l'activité lucrative" hypothesis feeding
  /// the OPP3 20% cap. Defaults to the sealed exact fixture point (20 000).
  final int nonAffiliatedIncomeChf;

  /// Exact history back. `back` is NOT in scenarios_versement-scope.yaml's
  /// never_routes_in_r4_applies_to list, but the isolated batch22 harness has
  /// no prior node to return to (parallel prep, not integration) — the
  /// harness wires this to an inert callback; linear wiring is the promoter's
  /// integration wave.
  final VoidCallback onBack;

  /// `continue`: always enabled, never routes in R4 (never_routes_in_r4).
  final VoidCallback onContinue;

  /// pending_missing_fact `complete_action` -> the node that collects the
  /// named missing fact. Inert no-op in the isolated harness.
  final VoidCallback onPendingComplete;

  /// `keep_local_reference` -> reference_saved (boundary node, out of scope;
  /// never_routes_in_r4). Inert no-op in the isolated harness.
  final VoidCallback onKeepLocalReference;

  /// `review_existing_overcontribution` -> existing_overcontribution_help
  /// (boundary node, out of scope; never_routes_in_r4). Visible only in
  /// marge_epuisee_overcontribution.
  final VoidCallback onReviewExistingOvercontribution;

  @override
  State<ScenariosVersementScreen> createState() =>
      _ScenariosVersementScreenState();
}

class _ScenariosVersementScreenState extends State<ScenariosVersementScreen> {
  final FocusNode _chooseLineFocus =
      FocusNode(debugLabel: 'scenarios choose_line');
  final FocusNode _sheetHeadingFocus =
      FocusNode(debugLabel: 'scenarios sheet heading');
  final Map<String, FocusNode> _anchorFocus = <String, FocusNode>{};

  int? _ownAmountChf;

  _Overlay? _overlay;
  String? _restoreAnchorId;

  late final Object _generation = Object();
  bool _headingFocusRequested = false;

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  FocusNode _anchor(String id) => _anchorFocus.putIfAbsent(
        id,
        () => FocusNode(debugLabel: 'scenarios anchor $id'),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_headingFocusRequested) {
        _headingFocusRequested = true;
        _chooseLineFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _chooseLineFocus.dispose();
    _sheetHeadingFocus.dispose();
    for (final node in _anchorFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return r4Copy.containsKey(code) ? code : 'fr';
  }

  int get _annualCapChf => widget.affiliated == true
      ? r4AffiliatedCapChf
      : r4DeriveAnnualCapChf(
          affiliated: false,
          nonAffiliatedIncomeChf: widget.nonAffiliatedIncomeChf,
        );

  /// The first missing critical input, in
  /// critical_inputs_for_this_screen order — additional_planned_amount is
  /// NEVER a trigger here (state_precedence carve-out).
  String? get _firstMissingFact {
    if (widget.taxYear == null) return 'tax_year';
    if (widget.commune == null) return 'commune';
    if (widget.band == null) return 'band';
    if (widget.affiliated == null) return 'affiliation';
    return null;
  }

  _RenderState _resolveState() {
    if (_firstMissingFact != null) return _RenderState.pending;
    final cap = _annualCapChf;
    if (widget.contributedChf >= cap) return _RenderState.margeEpuisee;
    if (widget.contributedChf > 0) return _RenderState.margeReduite;
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
    if (restore == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isStale(generation)) return;
      if (restore == 'choose_line') {
        _chooseLineFocus.requestFocus();
      } else {
        _anchor(restore).requestFocus();
      }
    });
  }

  void _saveOwnAmount(int? value, Object generation) {
    if (_isStale(generation)) return;
    setState(() => _ownAmountChf = value);
    _closeOverlay(generation);
  }

  /// The 2-3 grounded anchors for the affilié path, or the single qualitative
  /// max-scenario anchor for the non-affilié overlay (ceiling_dimension: the
  /// overlay composes with the marge state, it never terminates it).
  List<R4ScenarioAnchor> _scenarioAnchorsFor({
    required _RenderState state,
    required bool affiliated,
    required int contributed,
    required int remaining,
  }) {
    if (!affiliated) {
      return <R4ScenarioAnchor>[
        R4ScenarioAnchor(amountChf: remaining, isMax: true),
      ];
    }
    if (state == _RenderState.nominal) return r4NominalScenarios;
    if (contributed == r4MargeReduiteGroundedContributedChf) {
      return r4MargeReduiteScenarios;
    }
    // Ungrounded contributed value on the affilié path: no fixture exists for
    // this exact remaining room, so no invented scenario row is shown
    // (documented offline-lab limitation, not a bug).
    return const <R4ScenarioAnchor>[];
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final copy = r4CopyFor(_localeCode(context));
    final state = _resolveState();

    final body = switch (state) {
      _RenderState.pending => _pendingBody(copy, generation),
      _RenderState.margeEpuisee => _margeEpuiseeBody(copy, generation),
      _RenderState.margeReduite ||
      _RenderState.nominal =>
        _scenariosBody(copy, generation, state),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(excluding: _overlay != null, child: body),
        if (_overlay != null) _buildOverlay(copy, generation),
      ],
    );
  }

  Widget _eyebrowText(Map<String, String> copy) {
    final year = widget.taxYear?.toString() ?? '—';
    return Text(
      copy['scenarios_eyebrow']!.replaceAll('{taxYear}', year),
      key: const ValueKey('text:scenarios.eyebrow'),
      style: const TextStyle(
        fontFamily: 'Supreme',
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
        color: _sauge,
      ),
    );
  }

  // The choose_line heading: arrival focus + the `plafond` glossary anchor
  // (teaching_mechanism.on_screen_anchors_minimal:
  // choose_line_carries_plafond_anchor).
  Widget _chooseLine(Map<String, String> copy, Object generation) {
    final text = copy['scenarios_choose_line']!;
    return Semantics(
      key: const ValueKey('text:scenarios.choose_line'),
      header: true,
      button: true,
      label: text,
      onTap: () =>
          _openOverlay(_Overlay.glossPlafond, restoreAnchorId: 'choose_line'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _chooseLineFocus,
        actionKey: const ValueKey('action:scenarios.open_plafond_glossary'),
        onPressed: () => _openOverlay(
          _Overlay.glossPlafond,
          restoreAnchorId: 'choose_line',
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Gambarino',
            fontSize: 27,
            height: 1.15,
            color: _ink,
          ),
        ),
      ),
    );
  }

  // The remaining/room line: the `marge restante` glossary anchor.
  Widget _remainingLine(
    Map<String, String> copy,
    Object generation, {
    required int room,
  }) {
    final text =
        copy['scenarios_remaining']!.replaceAll('{room}', _fmtChf(room));
    return Semantics(
      key: const ValueKey('text:scenarios.remaining'),
      button: true,
      label: text,
      onTap: () =>
          _openOverlay(_Overlay.glossMarge, restoreAnchorId: 'gloss_marge'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _anchor('gloss_marge'),
        actionKey: const ValueKey('action:scenarios.open_marge_glossary'),
        onPressed: () => _openOverlay(
          _Overlay.glossMarge,
          restoreAnchorId: 'gloss_marge',
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 17,
              height: 1.4,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }

  // The liquidity note: MANDATORY, anti-dark-pattern (fault_D). Carries the
  // `bloqué` glossary anchor.
  Widget _liquidityNote(Map<String, String> copy, Object generation) {
    final text = copy['scenarios_liquidity']!;
    return Semantics(
      key: const ValueKey('text:scenarios.liquidity'),
      button: true,
      label: text,
      onTap: () =>
          _openOverlay(_Overlay.glossBloque, restoreAnchorId: 'gloss_bloque'),
      excludeSemantics: true,
      child: _Activable(
        focusNode: _anchor('gloss_bloque'),
        actionKey: const ValueKey('action:scenarios.open_liquidity_glossary'),
        onPressed: () => _openOverlay(
          _Overlay.glossBloque,
          restoreAnchorId: 'gloss_bloque',
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 15,
              height: 1.45,
              color: _ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _plainText(String text, {required String key, bool sauge = false}) {
    return Text(
      text,
      key: ValueKey(key),
      style: TextStyle(
        fontFamily: 'Supreme',
        fontSize: 15,
        height: 1.4,
        color: sauge ? _sauge : _ink,
      ),
    );
  }

  // --- nominal / marge_reduite (composes the non-affilié overlay) ---
  Widget _scenariosBody(
    Map<String, String> copy,
    Object generation,
    _RenderState state,
  ) {
    final cap = _annualCapChf;
    final contributed = widget.contributedChf;
    final remaining = cap - contributed;
    final affiliated = widget.affiliated!;

    final anchors = _scenarioAnchorsFor(
      state: state,
      affiliated: affiliated,
      contributed: contributed,
      remaining: remaining,
    );

    final scroll = SingleChildScrollView(
      key: const ValueKey('scroll:scenarios'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _eyebrowText(copy),
          const SizedBox(height: 16),
          _chooseLine(copy, generation),
          const SizedBox(height: 16),
          if (!affiliated) ...[
            _plainText(
              copy['scenarios_plafond20_line']!,
              key: 'text:scenarios.plafond20_line',
            ),
            const SizedBox(height: 6),
            _plainText(
              copy['scenarios_plafond20_amount']!
                  .replaceAll('{ceiling}', _fmtChf(cap)),
              key: 'text:scenarios.plafond20_amount',
            ),
            const SizedBox(height: 6),
            _plainText(
              copy['scenarios_plafond20_income_hyp']!,
              key: 'text:scenarios.plafond20_income_hyp',
              sauge: true,
            ),
            const SizedBox(height: 20),
          ] else ...[
            if (contributed > 0) ...[
              _plainText(
                copy['scenarios_already']!
                    .replaceAll('{contributed}', _fmtChf(contributed)),
                key: 'text:scenarios.already',
              ),
              const SizedBox(height: 8),
            ],
            _remainingLine(copy, generation, room: remaining),
            const SizedBox(height: 8),
            _plainText(
              copy['scenarios_commune_caveat']!,
              key: 'text:scenarios.commune_caveat',
              sauge: true,
            ),
            const SizedBox(height: 20),
          ],
          Semantics(
            key: const ValueKey('group:scenarios.rows'),
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < anchors.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _scenarioRow(
                      copy,
                      i,
                      anchors[i],
                      contributed: contributed,
                    ),
                  ),
                if (_ownAmountChf != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ownAmountRow(
                      copy,
                      remaining: remaining,
                      contributed: contributed,
                      affiliated: affiliated,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // own_amount: pulled by value, optional, no preselection — and
          // NEVER offered when the room is exhausted (that is marge_epuisee,
          // handled in its own body, fault_E).
          _LinkAction(
            actionKey: 'action:scenarios.own_amount',
            label: copy['scenarios_own_amount']!,
            focusNode: _anchor('open_own_amount'),
            onPressed: () => _openOverlay(
              _Overlay.ownAmount,
              restoreAnchorId: 'open_own_amount',
            ),
          ),
          const SizedBox(height: 20),
          _liquidityNote(copy, generation),
          const SizedBox(height: 12),
          _plainText(
            copy['scenarios_disclaimer']!,
            key: 'text:scenarios.disclaimer',
            sauge: true,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: scroll), _footer(copy, state: state)],
    );
  }

  Widget _scenarioRow(
    Map<String, String> copy,
    int index,
    R4ScenarioAnchor anchor, {
    required int contributed,
  }) {
    final useMoreTemplate = contributed > 0;
    final amountText = useMoreTemplate
        ? copy['scenarios_amount_more']!
            .replaceAll('{amount}', _fmtChf(anchor.amountChf))
        : copy['scenarios_amount']!
            .replaceAll('{amount}', _fmtChf(anchor.amountChf));
    final suffix = anchor.isMax
        ? (useMoreTemplate
            ? copy['scenarios_amount_rest_suffix']!
            : copy['scenarios_amount_max_suffix']!)
        : '';
    final String effectText;
    if (anchor.isQualitative) {
      effectText = copy['scenarios_plafond20_effect_note']!;
    } else {
      effectText = copy['scenarios_effect']!
          .replaceAll('{low}', _fmtChf(_floor100(anchor.savingLowRaw!)))
          .replaceAll('{high}', _fmtChf(_floor100(anchor.savingHighRaw!)));
    }
    // The announced scenario REGION: amount + effect spoken as one utterance
    // (reconciled key region:scenarios.scenario — one per grounded scenario;
    // each lives under its own Focus/Padding, never a direct sibling of another
    // region, so the shared ValueKey never trips the duplicate-key assertion).
    final label = '$amountText$suffix — $effectText';
    return Focus(
      focusNode: _anchor('scenario_$index'),
      child: Semantics(
        key: const ValueKey('region:scenarios.scenario'),
        container: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _porcelain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: amountText,
                      style: const TextStyle(
                        fontFamily: 'Supreme',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      TextSpan(
                        text: suffix,
                        style: const TextStyle(
                          fontFamily: 'Supreme',
                          fontSize: 13,
                          color: _sauge,
                        ),
                      ),
                  ],
                ),
                key: ValueKey('amount:scenarios.scenario_$index'),
              ),
              const SizedBox(height: 6),
              Text(
                effectText,
                // Reconciled key amount:scenarios.effect — the francs effect
                // RANGE of this scenario (one per grounded scenario; >= 2 in
                // the nominal spectrum). Shared across rows but each under its
                // own scenario Column, so no duplicate-key assertion.
                key: const ValueKey('amount:scenarios.effect'),
                style: const TextStyle(
                  fontFamily: 'Supreme',
                  fontSize: 16,
                  height: 1.35,
                  color: _sauge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The own_amount pulled-value row. See the OFFLINE-LAB LIMITATION header
  // note: a numeric effect is shown only when the deductible amount is
  // grounded (matches an existing fixture anchor exactly, or clamps to
  // remaining room which is itself always a grounded anchor); the
  // non-affilié overlay's note is qualitative and therefore safe for any
  // amount. Never a fabricated number (0-trust / NEVER#3).
  Widget _ownAmountRow(
    Map<String, String> copy, {
    required int remaining,
    required int contributed,
    required bool affiliated,
  }) {
    final entered = _ownAmountChf!;
    final deductible = entered < remaining ? entered : remaining;
    final useMoreTemplate = contributed > 0;
    final amountText = useMoreTemplate
        ? copy['scenarios_amount_more']!
            .replaceAll('{amount}', _fmtChf(entered))
        : copy['scenarios_amount']!.replaceAll('{amount}', _fmtChf(entered));

    String? effectText;
    if (!affiliated) {
      effectText = copy['scenarios_plafond20_effect_note'];
    } else {
      final state =
          contributed > 0 ? _RenderState.margeReduite : _RenderState.nominal;
      final anchors = _scenarioAnchorsFor(
        state: state,
        affiliated: true,
        contributed: contributed,
        remaining: remaining,
      );
      for (final a in anchors) {
        if (a.amountChf == deductible) {
          effectText = copy['scenarios_effect']!
              .replaceAll('{low}', _fmtChf(_floor100(a.savingLowRaw!)))
              .replaceAll('{high}', _fmtChf(_floor100(a.savingHighRaw!)));
          break;
        }
      }
    }

    final exceeds = entered > remaining;
    final labelParts = <String>[amountText];
    if (effectText != null) labelParts.add(effectText);
    if (exceeds) labelParts.add(copy['scenarios_excess_note']!);

    return Focus(
      focusNode: _anchor('own_amount_result'),
      child: Semantics(
        key: const ValueKey('row:scenarios.own_amount_result'),
        container: true,
        label: labelParts.join(' — '),
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _porcelain,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _forest, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amountText,
                key: const ValueKey('amount:scenarios.own_amount_result'),
                style: const TextStyle(
                  fontFamily: 'Supreme',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (effectText != null) ...[
                const SizedBox(height: 6),
                Text(
                  effectText,
                  key: const ValueKey(
                    'text:scenarios.own_amount_result.effect',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontSize: 16,
                    height: 1.35,
                    color: _sauge,
                  ),
                ),
              ],
              if (exceeds) ...[
                const SizedBox(height: 6),
                Text(
                  copy['scenarios_excess_note']!,
                  key: const ValueKey('text:scenarios.excess_note'),
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontSize: 14,
                    height: 1.35,
                    color: _sauge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- pending_missing_fact ---
  Widget _pendingBody(Map<String, String> copy, Object generation) {
    final fact = _firstMissingFact!;
    final factLabel = copy['scenarios_pending_fact_$fact']!;
    final whichText =
        copy['scenarios_pending_which']!.replaceAll('{fact}', factLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:scenarios'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eyebrowText(copy),
                const SizedBox(height: 96),
                Semantics(
                  key: const ValueKey('status:scenarios.pending'),
                  container: true,
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Focus(
                        focusNode: _chooseLineFocus,
                        child: Semantics(
                          header: true,
                          child: Text(
                            copy['scenarios_pending_title']!,
                            key: const ValueKey(
                              'text:scenarios.pending_title',
                            ),
                            style: const TextStyle(
                              fontFamily: 'Gambarino',
                              fontSize: 28,
                              height: 1.15,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        whichText,
                        key: const ValueKey('text:scenarios.pending_which'),
                        style: const TextStyle(
                          fontFamily: 'Supreme',
                          fontSize: 17,
                          height: 1.4,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _footer(copy, state: _RenderState.pending),
      ],
    );
  }

  // --- marge_epuisee_overcontribution (fault_E: no contribute-more scenario) ---
  Widget _margeEpuiseeBody(Map<String, String> copy, Object generation) {
    final cap = _annualCapChf;
    final contributed = widget.contributedChf;
    final excess = contributed - cap;
    final overLine = copy['scenarios_over_line']!
        .replaceAll('{contributed}', _fmtChf(contributed))
        .replaceAll('{cap}', _fmtChf(cap));
    final overExcess =
        copy['scenarios_over_excess']!.replaceAll('{excess}', _fmtChf(excess));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:scenarios'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _eyebrowText(copy),
                const SizedBox(height: 16),
                _chooseLine(copy, generation),
                const SizedBox(height: 24),
                Semantics(
                  key: const ValueKey('status:scenarios.over'),
                  container: true,
                  liveRegion: true,
                  child: Focus(
                    focusNode: _anchor('over_status'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overLine,
                          key: const ValueKey('text:scenarios.over_line'),
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 17,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          overExcess,
                          key: const ValueKey('text:scenarios.over_excess'),
                          style: const TextStyle(
                            fontFamily: 'Supreme',
                            fontSize: 15,
                            height: 1.45,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _LinkAction(
                  actionKey: 'action:scenarios.review_existing_overcontribution',
                  label: copy['scenarios_over_action']!,
                  onPressed: widget.onReviewExistingOvercontribution,
                ),
                const SizedBox(height: 24),
                // Mandatory anti-dark-pattern liquidity + estimate disclaimer
                // (lsfin_no_promise_contract; kept even though the state's own
                // literal `shows` list omits them — the top-level obligation
                // is unconditional).
                _liquidityNote(copy, generation),
                const SizedBox(height: 12),
                _plainText(
                  copy['scenarios_disclaimer']!,
                  key: 'text:scenarios.disclaimer',
                  sauge: true,
                ),
              ],
            ),
          ),
        ),
        _footer(copy, state: _RenderState.margeEpuisee),
      ],
    );
  }

  Widget _footer(Map<String, String> copy, {required _RenderState state}) {
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
            if (state == _RenderState.pending)
              _PrimaryButton(
                buttonKey: 'action:scenarios.pending_action',
                label: copy['scenarios_pending_action']!,
                onPressed: widget.onPendingComplete,
              )
            else ...[
              _TextButton(
                buttonKey: 'action:scenarios.keep_local_reference',
                label: copy['scenarios_keep_reference']!,
                onPressed: widget.onKeepLocalReference,
              ),
              const SizedBox(height: 8),
              _PrimaryButton(
                buttonKey: 'action:scenarios.continue',
                label: copy['scenarios_continue']!,
                onPressed: widget.onContinue,
              ),
            ],
            const SizedBox(height: 8),
            _TextButton(
              buttonKey: 'action:scenarios.back',
              label: copy['scenarios_back']!,
              onPressed: widget.onBack,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(Map<String, String> copy, Object generation) {
    switch (_overlay!) {
      case _Overlay.glossPlafond:
        return _GlossSheet(
          sheetId: 'sheet:scenarios.gloss.plafond',
          headingFocus: _sheetHeadingFocus,
          term: copy['scenarios_gloss_plafond_term']!,
          definition: copy['scenarios_gloss_plafond_def']!
              .replaceAll('{affiliatedCap}', _fmtChf(r4AffiliatedCapChf)),
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.glossMarge:
        return _GlossSheet(
          sheetId: 'sheet:scenarios.gloss.marge',
          headingFocus: _sheetHeadingFocus,
          term: copy['scenarios_gloss_marge_term']!,
          definition: copy['scenarios_gloss_marge_def']!,
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.glossBloque:
        return _GlossSheet(
          sheetId: 'sheet:scenarios.gloss.bloque',
          headingFocus: _sheetHeadingFocus,
          term: copy['scenarios_gloss_bloque_term']!,
          definition: copy['scenarios_gloss_bloque_def']!,
          dismissLabel: copy['gloss_dismiss']!,
          onDismiss: () => _closeOverlay(generation),
        );
      case _Overlay.ownAmount:
        return _OwnAmountSheet(
          headingFocus: _sheetHeadingFocus,
          copy: copy,
          initial: _ownAmountChf,
          onSave: (v) => _saveOwnAmount(v, generation),
          onDismiss: () => _closeOverlay(generation),
        );
    }
  }
}

/// Wraps [child] so [onPressed] fires on pointer tap AND on real keyboard/switch
/// activation (Enter/Space -> ActivateIntent) once the control is focused
/// (mirrors eclairage_impot_3a.dart / fact_revenu.dart's `_Activable`).
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
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _forest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _forest),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _paper,
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

/// A term + definition glossary sheet (plafond / marge / bloqué). Focus-trapped
/// until dismissed, then restores to its anchor.
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
                                fontSize: 26,
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

class _OwnAmountSheet extends StatefulWidget {
  const _OwnAmountSheet({
    required this.headingFocus,
    required this.copy,
    required this.initial,
    required this.onSave,
    required this.onDismiss,
  });

  final FocusNode headingFocus;
  final Map<String, String> copy;
  final int? initial;
  final ValueChanged<int?> onSave;
  final VoidCallback onDismiss;

  @override
  State<_OwnAmountSheet> createState() => _OwnAmountSheetState();
}

class _OwnAmountSheetState extends State<_OwnAmountSheet> {
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
      key: const ValueKey('sheet:scenarios.own_amount'),
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
                            'sheet:scenarios.own_amount.heading',
                          ),
                          focusNode: widget.headingFocus,
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.copy['scenarios_own_amount']!,
                              style: const TextStyle(
                                fontFamily: 'Gambarino',
                                fontSize: 22,
                                color: _ink,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _NumberField(
                          fieldKey: 'sheet:scenarios.own_amount.field',
                          controller: _controller,
                        ),
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          buttonKey: 'sheet:scenarios.own_amount.save',
                          label: widget.copy['scenarios_own_amount_save']!,
                          onPressed: () {
                            final parsed = int.tryParse(
                              _controller.text
                                  .replaceAll(RegExp(r'[^0-9]'), ''),
                            );
                            widget.onSave(parsed);
                          },
                        ),
                        const SizedBox(height: 8),
                        _TextButton(
                          buttonKey: 'sheet:scenarios.own_amount.dismiss',
                          label: widget.copy['scenarios_back']!,
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
  const _NumberField({required this.fieldKey, required this.controller});

  final String fieldKey;
  final TextEditingController controller;

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
          suffixText: 'CHF',
          filled: true,
          fillColor: _porcelain,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _cardBorder),
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
            color: _cardBorder,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
