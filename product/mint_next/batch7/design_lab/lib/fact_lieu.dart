// Batch20 R2 runtime — the fused `fact_lieu` (COMMUNE DIRECTE) node for the
// hidden design lab. The commune-directe pivot (Julien 2026-08-04) folds
// fact_canton into a single fused node: the user answers « Où habites-tu ? » with
// a NATIONAL commune search and the canton is DERIVED from the chosen commune,
// never asked and never a wheel on this screen.
//
// It implements product/mint_next/batch20/commune-scope.yaml + six-locale-copy.yaml
// exactly (rendered from fact_lieu_catalog.g.dart): question alone with no body,
// national contains-fold search over official names / bilingual aliases / NPA
// (secondary display-only text, never committed), a fifty-row render cap with an
// overflow status carrying the total, a persistent selection summary, an atomic
// commune+derived-canton announcement, a tappable communal-tax glossary sheet
// (one sentence + a metaphor, focus-trapped), and a no-match spelling prompt with
// a discreet help link escalating to the R3 complex-situation path — the only
// residual exit. The derived canton label is resolved through the accepted R1
// canton catalog (canton_r1_catalog.g.dart). Continue is guarded and NEVER routes
// in R2. The local search reuses the shared Unicode casefold data modules verbatim.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'canton_r1_catalog.g.dart';
import 'fact_lieu_catalog.g.dart';
import 'multi_provider_casefold_data.dart';
import 'multi_provider_default_ignorable_data.dart';

// Design-lab palette (mirrors the private tokens in design_lab_app.dart).
const Color _paper = Color(0xFFFAF8F5);
const Color _porcelain = Color(0xFFF4F1EC);
const Color _ink = Color(0xFF1A1A1A);
const Color _secondaryInk = Color(0xFF4A4A4A);
const Color _coral = Color(0xFF944B34);
const Color _sage = Color(0xFFD4DFCE);
const Color _border = Color(0xFFE2DED7);

const int _renderCap = 50;

final RegExp _lieuMarks = RegExp(r'\p{M}', unicode: true);
final RegExp _lieuWhitespace = RegExp(r'\s+', unicode: true);

bool _isDefaultIgnorable(int rune) {
  for (final (start, end) in multiProviderDefaultIgnorableRanges) {
    if (rune < start) break;
    if (rune <= end) return true;
  }
  return false;
}

/// Local search fold: NFKC compatibility normalization, default-ignorable
/// removal, full case fold (shared casefold table), then canonical decomposition
/// with combining-mark (diacritic) stripping and whitespace collapse. Applied
/// identically to the raw query and to every reviewed token so matching is case-
/// and diacritic-insensitive. Pure and offline — never networked or logged.
String foldForCommuneSearch(String raw) {
  final composed = unicode.nfkc(raw);
  final folded = StringBuffer();
  for (final rune in composed.runes) {
    if (_isDefaultIgnorable(rune)) continue;
    folded.write(multiProviderFullCaseFold[rune] ?? String.fromCharCode(rune));
  }
  final stripped = unicode.nfd(folded.toString()).replaceAll(_lieuMarks, '');
  return stripped.replaceAll(_lieuWhitespace, ' ').trim();
}

/// Bounds the raw query to [maxCodePoints] Unicode code points (runes).
class _LieuQueryCodePointLimiter extends TextInputFormatter {
  const _LieuQueryCodePointLimiter(this.maxCodePoints);

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

/// A reviewed commune in the national search index for the selected tax year.
class _CommuneEntry {
  const _CommuneEntry({
    required this.bfs,
    required this.name,
    required this.cantonCode,
    required this.npa,
    required this.tokens,
    required this.sortKey,
  });

  final int bfs;
  final String name;
  final String cantonCode;
  final String npa;
  final List<String> tokens; // folded name + aliases + npa
  final String sortKey; // folded name for a stable localized order
}

class FactLieuScreen extends StatefulWidget {
  const FactLieuScreen({
    super.key,
    required this.taxYear,
    this.onContinue,
    this.onCommuneSelected,
  });

  final int taxYear;

  /// Forward route once a reviewed commune is selected. In the batch20-only
  /// harness this is null and continue validates in place (never routes in R2).
  /// The batch21 éclairage integration wires it to the R3 fact_revenu node,
  /// superseding the R2 outbound-edge obligation (registry.deferred_integration).
  final VoidCallback? onContinue;

  /// R4 (batch22) integration: LIFTS the committed commune label + its derived
  /// canton label to the parent journey at the moment continue commits, so the
  /// éclairage payoff hypothesis row shows the commune the user actually picked
  /// (never a hardcoded fixture commune) and the same commune seeds the
  /// scenarios_versement fermeture node. Optional: null in the batch20/batch21
  /// harnesses (which never lift the commune), so their sealed constructions are
  /// unchanged. The engine fixtures stay canton-FR-grounded (documented
  /// offline-lab limitation) — this lifts the LABEL, never re-derives a number.
  /// V3-1 (Codex P1-1): also lifts the canton CODE so the éclairage can disclose
  /// (locale-robustly) when the FR-fixture hero range is not the user's canton.
  /// V4-1 (Codex P1-1): also lifts the commune BFS id so the éclairage can
  /// disclose by EXACT LOCALITY — no disclosure at the chef-lieu, an intra-
  /// cantonal one for another FR commune, an inter-cantonal one otherwise.
  final void Function(String commune, String canton, String cantonCode, int bfs)?
  onCommuneSelected;

  @override
  State<FactLieuScreen> createState() => _FactLieuScreenState();
}

class _FactLieuScreenState extends State<FactLieuScreen> {
  static const int _maxQueryCodePoints = 64;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'fact_lieu search');
  final FocusNode _questionFocus = FocusNode(debugLabel: 'fact_lieu question');
  final FocusNode _anchorFocus = FocusNode(debugLabel: 'fact_lieu communal anchor');
  final FocusNode _glossHeadingFocus =
      FocusNode(debugLabel: 'fact_lieu gloss heading');

  // Ephemeral, uncommitted UI state. Never persisted, logged, or sent.
  String _query = '';
  int? _selectedBfs;
  bool _showNoSelectionError = false;
  bool _r3HelpShown = false;
  bool _glossOpen = false;

  // Generation token per live instance: a callback captured in a superseded
  // (disposed) generation is a total no-op.
  late final Object _generation = Object();
  bool _questionFocusRequested = false;

  bool _isStale(Object generation) =>
      !mounted || !identical(generation, _generation);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_questionFocusRequested) {
        _questionFocusRequested = true;
        _questionFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _questionFocus.dispose();
    _anchorFocus.dispose();
    _glossHeadingFocus.dispose();
    super.dispose();
  }

  String _localeCode(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return factLieuCopy.containsKey(code) ? code : 'fr';
  }

  void _handleQuery(String value, Object generation) {
    if (_isStale(generation)) return;
    if (value == _query) return;
    setState(() {
      _query = value;
      _showNoSelectionError = false;
      _r3HelpShown = false;
    });
  }

  void _handleClear(Object generation) {
    if (_isStale(generation)) return;
    setState(() {
      _query = '';
      _showNoSelectionError = false;
      _r3HelpShown = false;
    });
    _searchController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isStale(generation)) _searchFocus.requestFocus();
    });
  }

  void _handleSelect(int bfs, Object generation) {
    if (_isStale(generation)) return;
    // Same-commune reselect: idempotent no-op (R2_14).
    if (_selectedBfs == bfs) return;
    setState(() {
      _selectedBfs = bfs;
      _showNoSelectionError = false;
    });
  }

  void _handleContinue(
    Object generation, {
    String? communeName,
    String? cantonLabel,
    String? cantonCode,
    int? communeBfs,
  }) {
    if (_isStale(generation)) return;
    // Guarded continue: with nothing selected it surfaces the no-selection
    // guard and stays. With a reviewed commune selected it routes forward when
    // a forward route is wired (batch21 éclairage integration -> fact_revenu),
    // otherwise it validates in place (batch20-only harness, onContinue null).
    if (_selectedBfs == null) {
      setState(() => _showNoSelectionError = true);
      return;
    }
    setState(() => _showNoSelectionError = false);
    // R4 (batch22): lift the committed commune + derived canton LABEL up so the
    // éclairage payoff shows the commune the user picked (never the fixture
    // commune) before routing forward.
    if (communeName != null &&
        cantonLabel != null &&
        cantonCode != null &&
        communeBfs != null) {
      widget.onCommuneSelected
          ?.call(communeName, cantonLabel, cantonCode, communeBfs);
    }
    widget.onContinue?.call();
  }

  void _handleHelp(Object generation) {
    if (_isStale(generation)) return;
    // Escalate to the R3 complex-situation help WITHOUT committing any fact and
    // WITHOUT routing out of fact_lieu — the only residual exit for a commune
    // that is genuinely absent from the reviewed national set.
    setState(() => _r3HelpShown = true);
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

  // Build the national index for the selected tax year: every reviewed commune
  // whose BFS is valid at the determining date, tagged with its derived canton.
  List<_CommuneEntry> _index() {
    final year = widget.taxYear;
    final entries = <_CommuneEntry>[];
    factLieuScope.forEach((cantonCode, byYear) {
      final codes = byYear[year];
      if (codes == null) return;
      for (final bfs in codes) {
        final name = factLieuNames[bfs]!;
        final npa = factLieuNpa[bfs]!;
        final tokens = <String>[
          foldForCommuneSearch(name),
          for (final alias in factLieuAliases[bfs] ?? const <String>[])
            foldForCommuneSearch(alias),
          foldForCommuneSearch(npa),
        ];
        entries.add(_CommuneEntry(
          bfs: bfs,
          name: name,
          cantonCode: cantonCode,
          npa: npa,
          tokens: tokens,
          sortKey: foldForCommuneSearch(name),
        ));
      }
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final generation = _generation;
    final locale = _localeCode(context);
    final copy = factLieuCopy[locale]!;
    final cantonLabels = cantonR1Labels[locale]!;
    final year = widget.taxYear.toString();
    String withYear(String t) => t.replaceAll('{taxYear}', year);
    String cantonLabelOf(String code) => cantonLabels[code] ?? code;

    final foldedQuery = foldForCommuneSearch(_query);
    final index = _index();
    final selected =
        _selectedBfs == null ? null : index.firstWhere((e) => e.bfs == _selectedBfs);

    List<_CommuneEntry> matches = const <_CommuneEntry>[];
    if (foldedQuery.isNotEmpty) {
      matches = [
        for (final e in index)
          if (e.tokens.any((t) => t.contains(foldedQuery))) e,
      ]..sort((a, b) {
          final byName = a.sortKey.compareTo(b.sortKey);
          return byName != 0 ? byName : a.bfs.compareTo(b.bfs);
        });
    }
    final total = matches.length;
    final overflow = total > _renderCap;
    final rendered = overflow ? matches.sublist(0, _renderCap) : matches;
    final noMatch = foldedQuery.isNotEmpty && matches.isEmpty;

    final textTheme = Theme.of(context).textTheme;

    final scroll = SingleChildScrollView(
      key: const ValueKey('scroll:fact_lieu'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The eyebrow gives the 3a-simulation context on arrival; once the
          // user is actively searching it steps aside so the results and the
          // continue control stay reachable on a compact viewport with a raised
          // keyboard (search-focused layout).
          if (foldedQuery.isEmpty) ...[
            Text(
              withYear(copy.eyebrow),
              style: const TextStyle(
                fontFamily: 'Supreme',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: _coral,
              ),
            ),
            const SizedBox(height: 16),
          ],
          // The question stands ALONE (no body sentence, amendement Julien 1) and
          // takes focus on arrival for the screen reader — the keyboard is NOT
          // auto-raised. It shows large on arrival and collapses to a single
          // compact line while a query is active so the first result stays high.
          Focus(
            key: const ValueKey('text:fact_lieu.question'),
            focusNode: _questionFocus,
            child: Semantics(
              header: true,
              child: Text(
                copy.question,
                maxLines: foldedQuery.isEmpty ? null : 1,
                overflow: foldedQuery.isEmpty
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Gambarino',
                  fontSize: foldedQuery.isEmpty ? 30 : 20,
                  height: 1.12,
                  color: _ink,
                ),
              ),
            ),
          ),
          SizedBox(height: foldedQuery.isEmpty ? 20 : 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  key: const ValueKey('field:fact_lieu.search'),
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
                      _LieuQueryCodePointLimiter(_maxQueryCodePoints),
                    ],
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: copy.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search, color: _secondaryInk),
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
                _IconAction(
                  actionKey: 'action:fact_lieu.clear_search',
                  label: copy.clearSearch,
                  icon: Icons.close_rounded,
                  onPressed: () => _handleClear(generation),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // --- results / empty / no-match block ---
          if (foldedQuery.isEmpty)
            _StatusChip(
              statusKey: 'status:fact_lieu.empty',
              text: copy.empty,
              liveRegion: false,
            )
          else if (noMatch) ...[
            _StatusChip(
              statusKey: 'status:fact_lieu.no_match',
              text: copy.noMatch,
              liveRegion: true,
            ),
            const SizedBox(height: 8),
            _LinkAction(
              actionKey: 'action:fact_lieu.help',
              label: copy.helpLink,
              onPressed: () => _handleHelp(generation),
            ),
          ] else ...[
            // A non-overflow match set renders its rows directly (no count
            // banner) so the first canton-naming result stays reachable on a
            // compact viewport under a raised keyboard. Beyond the fifty-row
            // render cap an overflow status carries the total.
            if (overflow) ...[
              _StatusChip(
                statusKey: 'status:fact_lieu.overflow',
                text: copy.overflowStatus.replaceAll('{count}', '$total'),
                liveRegion: true,
              ),
              Padding(
                key: const ValueKey('count:fact_lieu.overflow_total'),
                padding: const EdgeInsets.only(top: 4),
                child: ExcludeSemantics(
                  child: Text(
                    '$total',
                    style: textTheme.bodySmall?.copyWith(color: _secondaryInk),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Semantics(
              key: const ValueKey('group:fact_lieu.choices'),
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final e in rendered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CommuneRow(
                        entry: e,
                        cantonLabel: cantonLabelOf(e.cantonCode),
                        npaText: copy.npaSecondary.replaceAll('{npa}', e.npa),
                        selected: e.bfs == _selectedBfs,
                        onPressed: () => _handleSelect(e.bfs, generation),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_r3HelpShown) ...[
            const SizedBox(height: 8),
            _StatusChip(
              statusKey: 'status:fact_lieu.r3_help',
              text: copy.r3Help,
              liveRegion: true,
            ),
          ],
          const SizedBox(height: 16),
          // --- selection summary (persists across queries) ---
          if (selected == null)
            _StatusChip(
              statusKey: 'status:fact_lieu.selection_none',
              text: copy.selectionNone,
              liveRegion: false,
            )
          else ...[
            _SelectionSummary(
              label: copy.selectionLabel,
              value: copy.selectionSelected
                  .replaceAll('{commune}', selected.name)
                  .replaceAll('{canton}', cantonLabelOf(selected.cantonCode)),
            ),
            // ONE atomic announcement carrying the commune AND its derived
            // canton — never split into two live regions.
            Semantics(
              key: const ValueKey('announce:fact_lieu.selected'),
              liveRegion: true,
              label:
                  '${selected.name} — ${cantonLabelOf(selected.cantonCode)}',
              child: const SizedBox(width: 1, height: 1),
            ),
          ],
          const SizedBox(height: 16),
          // The communal-tax teaching is a TAPPABLE anchor, not an inline wall.
          _GlossAnchor(
            focusNode: _anchorFocus,
            label: copy.communalHint,
            onPressed: () => _openGloss(generation),
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
                statusKey: 'status:fact_lieu.error_no_selection',
                text: copy.errorNoSelection,
                liveRegion: true,
                tone: _StatusTone.error,
              ),
              const SizedBox(height: 12),
            ],
            _ContinueControl(
              key: const ValueKey('action:fact_lieu.continue'),
              label: copy.continueLabel,
              onPressed: () => _handleContinue(
                generation,
                communeName: selected?.name,
                cantonLabel: selected == null
                    ? null
                    : cantonLabelOf(selected.cantonCode),
                cantonCode: selected?.cantonCode,
                communeBfs: selected?.bfs,
              ),
              // Subtle until a commune is selected, strong once it is — the
              // continue is guarded and never routes in R2, so the affordance
              // signals readiness rather than promising a route.
              filled: _selectedBfs != null,
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
          _GlossSheet(
            headingFocus: _glossHeadingFocus,
            term: copy.glossCommunalTerm,
            definition: copy.glossCommunalDef,
            metaphor: copy.glossCommunalMetaphor,
            dismissLabel: copy.glossDismiss,
            onDismiss: () => _dismissGloss(generation),
          ),
      ],
    );
  }
}

class _CommuneRow extends StatelessWidget {
  const _CommuneRow({
    required this.entry,
    required this.cantonLabel,
    required this.npaText,
    required this.selected,
    required this.onPressed,
  });

  final _CommuneEntry entry;
  final String cantonLabel;
  final String npaText;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      key: ValueKey('choice:fact_lieu.${entry.bfs}'),
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      // The row reads the commune AND its derived canton as one label.
      label: '${entry.name}, $cantonLabel',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.name, style: textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    // Wrap (not Row): the derived-canton label and the secondary
                    // NPA text flow to a second line under a raised keyboard at a
                    // 2x text scale in a 320pt-wide viewport, never overflowing.
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          cantonLabel,
                          key: ValueKey('canton:fact_lieu.${entry.bfs}'),
                          style: textTheme.bodySmall
                              ?.copyWith(color: _secondaryInk),
                        ),
                        Text(
                          npaText,
                          key: ValueKey('npa:fact_lieu.${entry.bfs}'),
                          style: textTheme.bodySmall
                              ?.copyWith(color: _secondaryInk),
                        ),
                      ],
                    ),
                  ],
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
        border: Border.all(color: isError ? _coral : _border),
      ),
      child: Semantics(
        container: true,
        liveRegion: liveRegion,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isError ? _coral : _secondaryInk,
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('status:fact_lieu.selection'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _sage.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: _secondaryInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _GlossAnchor extends StatelessWidget {
  const _GlossAnchor({
    required this.focusNode,
    required this.label,
    required this.onPressed,
  });

  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('anchor:fact_lieu.impot_communal'),
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
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _porcelain,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline_rounded,
                    size: 18, color: _coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _ink,
                          decoration: TextDecoration.underline,
                          decorationColor: _coral,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlossSheet extends StatelessWidget {
  const _GlossSheet({
    required this.headingFocus,
    required this.term,
    required this.definition,
    required this.metaphor,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final FocusNode headingFocus;
  final String term;
  final String definition;
  final String metaphor;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // The whole sheet subtree carries the sheet key so any trapped focus is
    // owned by `sheet:fact_lieu.gloss`. FocusScope + the ExcludeFocus'd
    // background trap traversal inside the open sheet until it is dismissed.
    return Positioned.fill(
      key: const ValueKey('sheet:fact_lieu.gloss'),
      child: FocusScope(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(color: Color(0x66000000), dismissible: false),
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: _paper,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Focus(
                          key: const ValueKey('sheet:fact_lieu.gloss.heading'),
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
                        const SizedBox(height: 12),
                        Text(definition, style: textTheme.bodyLarge),
                        const SizedBox(height: 12),
                        Container(
                          key: const ValueKey('sheet:fact_lieu.gloss.metaphor'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _sage.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: Text(metaphor, style: textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 20),
                        _ContinueControl(
                          key: const ValueKey('sheet:fact_lieu.gloss.dismiss'),
                          label: dismissLabel,
                          onPressed: onDismiss,
                          filled: false,
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

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String actionKey;
  final String label;
  final IconData icon;
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
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _porcelain,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 22, color: _ink),
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _coral,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _coral,
                ),
          ),
        ),
      ),
    );
  }
}

class _ContinueControl extends StatelessWidget {
  const _ContinueControl({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? _ink : _paper,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: filled ? _ink : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Supreme',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: filled ? _paper : _secondaryInk,
            ),
          ),
        ),
      ),
    );
  }
}
