// Batch18 R1 runtime — the `fact_canton` entry/search/selection screen for the
// hidden design lab. It implements the accepted Batch17 written contract
// (product/mint_next/batch17/canton-scope.yaml) exactly: an unset single-choice
// canton picker with a local, privacy-only search and an immutable origin
// receipt. R1 deliberately renders NO continue/unknown control and NEVER routes
// or creates commune/result state — those belong to R2/R3.
//
// i18n comes from the runtime catalog (canton_r1_catalog.g.dart), whose 26
// codes, six-locale labels and reviewed per-locale order are byte-identical to
// the sealed fixture. The local search reuses the shared Unicode data modules
// (multi_provider_casefold_data.dart + multi_provider_default_ignorable_data.dart)
// verbatim to build an NFKC case + diacritic fold.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'canton_r1_catalog.g.dart';
import 'multi_provider_casefold_data.dart';
import 'multi_provider_default_ignorable_data.dart';

// Design-lab palette (mirrors the private tokens in design_lab_app.dart; this
// package has no MintColors and hardcodes its prototype palette by convention).
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _secondaryInk = Color(0xFF4A4A4A);
const Color _coral = Color(0xFF944B34);
const Color _sage = Color(0xFFD4DFCE);
const Color _border = Color(0xFFE2DED7);

/// Local search fold: NFKC compatibility normalization, default-ignorable
/// removal, full case fold (shared casefold table), then canonical decomposition
/// with combining-mark (diacritic) stripping and whitespace collapse. Applied
/// identically to the raw query and to every reviewed label so matching is
/// case- and diacritic-insensitive. Pure and offline — no network/logging.
final RegExp _cantonMarks = RegExp(r'\p{M}', unicode: true);
final RegExp _cantonWhitespace = RegExp(r'\s+', unicode: true);

bool _isDefaultIgnorable(int rune) {
  for (final (start, end) in multiProviderDefaultIgnorableRanges) {
    if (rune < start) break;
    if (rune <= end) return true;
  }
  return false;
}

String foldForCantonSearch(String raw) {
  final composed = unicode.nfkc(raw);
  final folded = StringBuffer();
  for (final rune in composed.runes) {
    if (_isDefaultIgnorable(rune)) continue;
    folded.write(multiProviderFullCaseFold[rune] ?? String.fromCharCode(rune));
  }
  final stripped = unicode.nfd(folded.toString()).replaceAll(_cantonMarks, '');
  return stripped.replaceAll(_cantonWhitespace, ' ').trim();
}

/// A reviewed label matches when the folded query is a prefix or a suffix of the
/// folded label. This is the reviewed "prefix or (boundary) substring" matching:
/// it accepts leading tokens ("arg" → Argovie) and trailing tokens
/// ("wald" → Nidwald/Obwald, "Rhodes-Extérieures" → Appenzell Rhodes-Extérieures)
/// without matching a query buried inside a word ("ag" must not match Campagne).
bool cantonLabelMatches(String foldedLabel, String foldedQuery) =>
    foldedLabel.startsWith(foldedQuery) || foldedLabel.endsWith(foldedQuery);

/// Bounds the raw query to [maxCodePoints] Unicode code points (runes), so an
/// emoji or a combining mark counts as one code point. The raw query itself is
/// otherwise preserved verbatim.
class _CantonQueryCodePointLimiter extends TextInputFormatter {
  const _CantonQueryCodePointLimiter(this.maxCodePoints);

  final int maxCodePoints;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final runes = newValue.text.runes.toList(growable: false);
    if (runes.length <= maxCodePoints) return newValue;
    final clipped = String.fromCharCodes(runes.take(maxCodePoints));
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

class CantonR1Screen extends StatefulWidget {
  const CantonR1Screen({
    super.key,
    required this.taxYear,
    required this.hasPositiveContribution,
    required this.onBack,
  });

  final int taxYear;

  /// True when the runtime origin is the positive `fact_contributed_amount`
  /// branch; false for the `fact_contribution` "no" branch. Immutable while this
  /// node is live, so the origin receipt and exact-history Back cannot drift.
  final bool hasPositiveContribution;

  final VoidCallback onBack;

  @override
  State<CantonR1Screen> createState() => _CantonR1ScreenState();
}

class _CantonR1ScreenState extends State<CantonR1Screen> {
  static const int _maxQueryCodePoints = 64;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'fact_canton search');

  // Ephemeral, uncommitted UI state. Never persisted, logged, or sent.
  String _query = '';
  String? _selectedCode;

  // Generation token minted per live screen instance. Every R1 callback captures
  // it; a callback captured in a superseded (disposed/re-entered) generation
  // compares unequal / unmounted and is a total no-op — no mutation, no route.
  late final Object _generation = Object();

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _handleQuery(String value, Object generation) {
    if (_isStale(generation)) return;
    if (value == _query) return;
    setState(() => _query = value);
  }

  void _handleClear(Object generation) {
    if (_isStale(generation)) return;
    setState(() => _query = '');
    _searchController.clear();
    // Restore search focus after the current frame, past any tap-outside
    // unfocus triggered by activating the clear control.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(generation)) _searchFocus.requestFocus();
    });
  }

  void _handleSelect(String code, Object generation) {
    if (_isStale(generation)) return;
    if (!cantonR1AllowedCodes.contains(code)) return;
    // Same-code reselect: byte-equivalent no-op (no mutation, no rebuild).
    if (_selectedCode == code) return;
    setState(() => _selectedCode = code);
  }

  void _handleBack(Object generation) {
    if (_isStale(generation)) return;
    widget.onBack();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return cantonR1Order.containsKey(code) ? code : 'fr';
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final locale = _localeCode(context);
    final copy = cantonR1Copy[locale]!;
    final labels = cantonR1Labels[locale]!;
    final order = cantonR1Order[locale]!;
    final year = widget.taxYear.toString();
    String withYear(String template) => template.replaceAll('{taxYear}', year);

    final heading = withYear(copy.question);
    final body = withYear(copy.body);
    final eyebrow = withYear(copy.eyebrow);

    final foldedQuery = foldForCantonSearch(_query);
    final visibleCodes = foldedQuery.isEmpty
        ? order
        : [
            for (final code in order)
              if (cantonLabelMatches(
                foldForCantonSearch(labels[code]!),
                foldedQuery,
              ))
                code,
          ];
    final noMatch = foldedQuery.isNotEmpty && visibleCodes.isEmpty;
    final selectedLabel = _selectedCode == null ? null : labels[_selectedCode]!;

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll:fact_canton'),
            // Programmatic reveal only: `ensureVisible` still scrolls (jumpTo),
            // but disabling user drag means a row tap never spins up a transient
            // hold/idle scroll activity — keeping the reachable-state snapshot
            // byte-stable across a same-code reselection (R1_09).
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    color: _coral,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    heading,
                    style: const TextStyle(
                      fontFamily: 'Gambarino',
                      fontSize: 30,
                      height: 1.12,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(body, style: textTheme.bodyLarge),
                const SizedBox(height: 16),
                _OriginReceipt(
                  positive: widget.hasPositiveContribution,
                  text: widget.hasPositiveContribution
                      ? copy.originPositive
                      : copy.originNo,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        key: const ValueKey('field:fact_canton.search'),
                        container: true,
                        textField: true,
                        label: copy.searchLabel,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: (value) => _handleQuery(value, generation),
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          autofillHints: const <String>[],
                          enableInteractiveSelection: false,
                          inputFormatters: const [
                            _CantonQueryCodePointLimiter(_maxQueryCodePoints),
                          ],
                          style: textTheme.bodyLarge,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: copy.searchLabel,
                            prefixIcon: const Icon(
                              Icons.search,
                              color: _secondaryInk,
                            ),
                            filled: true,
                            fillColor: _porcelain,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _border),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _ClearSearchButton(
                        label: copy.clearSearch,
                        onPressed: () => _handleClear(generation),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Semantics(
                  key: const ValueKey('group:fact_canton.choices'),
                  container: true,
                  explicitChildNodes: true,
                  label: heading,
                  value: selectedLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final code in visibleCodes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CantonRow(
                            code: code,
                            label: labels[code]!,
                            selected: code == _selectedCode,
                            onPressed: () => _handleSelect(code, generation),
                          ),
                        ),
                    ],
                  ),
                ),
                if (noMatch)
                  Container(
                    key: const ValueKey('status:fact_canton.no_match'),
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        copy.searchEmpty,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('status:fact_canton.privacy'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _porcelain,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Semantics(
                    container: true,
                    child: Text(copy.privacy, style: textTheme.bodyMedium),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Fixed bottom action bar: keeps Back on-screen (like the shared _Page
        // action panel) so callers that tap it without ensureVisible still hit
        // it, while the 26-row list above scrolls under programmatic reveal.
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: _BackControl(
              label: copy.back,
              onPressed: () => _handleBack(generation),
            ),
          ),
        ),
      ],
    );
  }
}

class _OriginReceipt extends StatelessWidget {
  const _OriginReceipt({required this.positive, required this.text});

  final bool positive;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey(
        positive
            ? 'receipt:fact_canton.origin.positive'
            : 'receipt:fact_canton.origin.no',
      ),
      container: true,
      readOnly: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _sage.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_rounded, size: 18, color: _secondaryInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _CantonRow extends StatelessWidget {
  const _CantonRow({
    required this.code,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String code;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('choice:fact_canton.$code'),
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
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _sage : _porcelain,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _ink : _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                const Icon(Icons.check_circle, size: 22, color: _ink),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearSearchButton extends StatelessWidget {
  const _ClearSearchButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('action:fact_canton.clear_search'),
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _porcelain,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: const Icon(Icons.close_rounded, size: 22, color: _ink),
        ),
      ),
    );
  }
}

class _BackControl extends StatelessWidget {
  const _BackControl({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // A GestureDetector (not a Material button) keeps this control's only
    // semantic tap handler the generation-guarded one on the enclosing
    // Semantics: a Material button injects its own descendant Semantics whose
    // tap would bypass the generation guard (R1_11).
    return Semantics(
      key: const ValueKey('action:fact_canton.back'),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
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
