import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'l10n/generated/mint_next_localizations.dart';

enum _DesignNode {
  today3aIntent,
  orientation,
  factTaxYear,
  factLppAffiliation,
  lppUnknownHelp,
  withoutLppBoundary,
  factContribution,
  contributionUnknownHelp,
  factContributedAmount,
  factCanton,
  educationExplanation,
  dismissed,
}

enum _LppAffiliation { yes, no, unknown }

enum _ContributionStatus { yes, no, unknown }

class MintNextDesignLabApp extends StatelessWidget {
  const MintNextDesignLabApp({
    super.key,
    this.locale,
    this.textScaler,
    this.currentYear,
  });

  final Locale? locale;
  final TextScaler? textScaler;
  final int? currentYear;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: MintNextLocalizations.localizationsDelegates,
      supportedLocales: MintNextLocalizations.supportedLocales,
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: _DesignLabJourney(currentYear: currentYear ?? DateTime.now().year),
    );
  }
}

const _paper = Color(0xFFFAF8F5);
const _porcelain = Color(0xFFF4F1EC);
const _ink = Color(0xFF1A1A1A);
const _secondaryInk = Color(0xFF4A4A4A);
// 5.98:1 against _paper. The former coral failed normal-text AA at 3.51:1.
const _coral = Color(0xFF944B34);
const _sage = Color(0xFFD4DFCE);
const _border = Color(0xFFE2DED7);

final _theme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: _paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _sage,
    surface: _paper,
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(
      fontFamily: 'Supreme',
      fontSize: 18,
      height: 1.45,
      color: _ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Supreme',
      fontSize: 16,
      height: 1.45,
      color: _secondaryInk,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Supreme',
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
  ),
);

class _DesignLabJourney extends StatefulWidget {
  const _DesignLabJourney({required this.currentYear});

  final int currentYear;

  @override
  State<_DesignLabJourney> createState() => _DesignLabJourneyState();
}

class _DesignLabJourneyState extends State<_DesignLabJourney> {
  _DesignNode _node = _DesignNode.today3aIntent;
  int? _taxYear;
  _LppAffiliation? _lppAffiliation;
  _ContributionStatus? _contributionStatus;
  bool _contributionEdgeHelpExpanded = false;
  final FocusNode _safeExitTriggerFocus = FocusNode(
    debugLabel: 'safe exit trigger',
  );

  @override
  void didUpdateWidget(covariant _DesignLabJourney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentYear != widget.currentYear) {
      _clearEphemeralFacts();
      _node = _DesignNode.factTaxYear;
    }
  }

  @override
  void dispose() {
    _safeExitTriggerFocus.dispose();
    super.dispose();
  }

  void _go(_DesignNode node) => setState(() => _node = node);

  void _clearContributionFacts() {
    _contributionStatus = null;
    _contributionEdgeHelpExpanded = false;
  }

  void _clearEphemeralFacts() {
    _taxYear = null;
    _lppAffiliation = null;
    _clearContributionFacts();
  }

  void _leaveWithoutSaving() {
    setState(() {
      _clearEphemeralFacts();
      _node = _DesignNode.dismissed;
    });
  }

  String get _nodeId => switch (_node) {
    _DesignNode.today3aIntent => 'today_3a_intent',
    _DesignNode.orientation => 'orientation',
    _DesignNode.factTaxYear => 'fact_tax_year',
    _DesignNode.factLppAffiliation => 'fact_lpp_affiliation',
    _DesignNode.lppUnknownHelp => 'lpp_unknown_help',
    _DesignNode.withoutLppBoundary => 'without_lpp_boundary',
    _DesignNode.factContribution => 'fact_contribution',
    _DesignNode.contributionUnknownHelp => 'contribution_unknown_help',
    _DesignNode.factContributedAmount => 'fact_contributed_amount',
    _DesignNode.factCanton => 'fact_canton',
    _DesignNode.educationExplanation => 'education_explanation',
    _DesignNode.dismissed => 'dismissed',
  };

  Future<void> _showSafeExit() async {
    final l10n = MintNextLocalizations.of(context);
    final leftJourney = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (sheetContext) => _SafeExitSheet(
        l10n: l10n,
        onResume: () => Navigator.pop(sheetContext, false),
        onLeave: () {
          Navigator.pop(sheetContext, true);
          _leaveWithoutSaving();
        },
      ),
    );
    if (mounted && leftJourney != true) {
      _safeExitTriggerFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              nodeId: _nodeId,
              onExit: _showSafeExit,
              exitFocusNode: _safeExitTriggerFocus,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                child: KeyedSubtree(
                  key: ValueKey('node:$_nodeId'),
                  child: switch (_node) {
                    _DesignNode.today3aIntent => _Today(
                      onStart: () => _go(_DesignNode.orientation),
                    ),
                    _DesignNode.orientation => _Orientation(
                      onContinue: () => _go(_DesignNode.factTaxYear),
                      onBack: () => _go(_DesignNode.today3aIntent),
                    ),
                    _DesignNode.factTaxYear => _TaxYear(
                      selectedYear: _taxYear,
                      currentYear: widget.currentYear,
                      onSelect: () => setState(() {
                        if (_taxYear != widget.currentYear) {
                          _clearContributionFacts();
                        }
                        _taxYear = widget.currentYear;
                      }),
                      onBack: () => _go(_DesignNode.orientation),
                      onContinue: () => _go(_DesignNode.factLppAffiliation),
                    ),
                    _DesignNode.factLppAffiliation => _LppQuestion(
                      selected: _lppAffiliation,
                      onChoose: (value) {
                        setState(() {
                          if (_lppAffiliation != value) {
                            _clearContributionFacts();
                          }
                          _lppAffiliation = value;
                        });
                        _go(switch (value) {
                          _LppAffiliation.yes => _DesignNode.factContribution,
                          _LppAffiliation.no => _DesignNode.withoutLppBoundary,
                          _LppAffiliation.unknown => _DesignNode.lppUnknownHelp,
                        });
                      },
                      onBack: () => _go(_DesignNode.factTaxYear),
                    ),
                    _DesignNode.lppUnknownHelp => _LppUnknownHelp(
                      onBack: () => _go(_DesignNode.factLppAffiliation),
                    ),
                    _DesignNode.withoutLppBoundary => _WithoutLppBoundary(
                      onBack: () => _go(_DesignNode.factLppAffiliation),
                    ),
                    _DesignNode.factContribution => _ContributionQuestion(
                      taxYear: _taxYear!,
                      selected: _contributionStatus,
                      edgeHelpExpanded: _contributionEdgeHelpExpanded,
                      onToggleEdgeHelp: () => setState(
                        () => _contributionEdgeHelpExpanded =
                            !_contributionEdgeHelpExpanded,
                      ),
                      onChoose: (value) {
                        setState(() => _contributionStatus = value);
                        _go(switch (value) {
                          _ContributionStatus.yes =>
                            _DesignNode.factContributedAmount,
                          _ContributionStatus.no => _DesignNode.factCanton,
                          _ContributionStatus.unknown =>
                            _DesignNode.contributionUnknownHelp,
                        });
                      },
                      onBack: () => _go(_DesignNode.factLppAffiliation),
                    ),
                    _DesignNode.contributionUnknownHelp =>
                      _ContributionUnknownHelp(
                        taxYear: _taxYear!,
                        onContinueEducation: () =>
                            _go(_DesignNode.educationExplanation),
                        onBack: () => _go(_DesignNode.factContribution),
                      ),
                    _DesignNode.factContributedAmount =>
                      _ContributionAmountBoundary(
                        taxYear: _taxYear!,
                        onBack: () => _go(_DesignNode.factContribution),
                      ),
                    _DesignNode.factCanton => _CantonBoundary(
                      taxYear: _taxYear!,
                      onBack: () => _go(_DesignNode.factContribution),
                    ),
                    _DesignNode.educationExplanation => _EducationBoundary(
                      onBack: () => _go(_DesignNode.contributionUnknownHelp),
                    ),
                    _DesignNode.dismissed => _Terminal(
                      title: l10n.dismissedTitle,
                      onRestart: () => _go(_DesignNode.today3aIntent),
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.nodeId,
    required this.onExit,
    required this.exitFocusNode,
  });
  final String nodeId;
  final VoidCallback onExit;
  final FocusNode exitFocusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.brand,
              sortKey: const OrdinalSortKey(0),
              child: ExcludeSemantics(
                child: Text(
                  largeText ? 'm.' : l10n.brand,
                  style: const TextStyle(
                    fontFamily: 'Supreme',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 3.2,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ),
          if (largeText)
            Semantics(
              sortKey: const OrdinalSortKey(1),
              child: IconButton(
                key: ValueKey('action:$nodeId.open_safe_exit'),
                focusNode: exitFocusNode,
                tooltip: l10n.quitJourney,
                onPressed: onExit,
                icon: const ExcludeSemantics(
                  child: Text(
                    '×',
                    style: TextStyle(fontFamily: 'Supreme', fontSize: 28),
                  ),
                ),
              ),
            )
          else
            MintDesignLabAction.text(
              key: ValueKey('action:$nodeId.open_safe_exit'),
              label: l10n.quit,
              semanticsLabel: l10n.quitJourney,
              semanticsSortKey: const OrdinalSortKey(1),
              focusNode: exitFocusNode,
              onPressed: onExit,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _Today extends StatelessWidget {
  const _Today({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    return _Page(
      nodeId: 'today_3a_intent',
      eyebrow: l10n.todayEyebrow,
      title: l10n.todayTitle,
      body: l10n.todayBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:today_3a_intent.start'),
          label: largeText ? l10n.startShort : l10n.start,
          onPressed: onStart,
        ),
      ],
    );
  }
}

class _Orientation extends StatelessWidget {
  const _Orientation({required this.onContinue, required this.onBack});
  final VoidCallback onContinue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'orientation',
      eyebrow: l10n.orientationEyebrow,
      title: l10n.orientationTitle,
      body: l10n.orientationBody,
      accent: _EditorialNote(text: l10n.orientationNote),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:orientation.continue'),
          label: l10n.continueLabel,
          onPressed: onContinue,
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:orientation.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _TaxYear extends StatelessWidget {
  const _TaxYear({
    required this.selectedYear,
    required this.currentYear,
    required this.onSelect,
    required this.onBack,
    required this.onContinue,
  });
  final int? selectedYear;
  final int currentYear;
  final VoidCallback onSelect;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final year = currentYear;
    return _Page(
      nodeId: 'fact_tax_year',
      eyebrow: l10n.taxYearEyebrow,
      title: l10n.taxYearTitle,
      body: l10n.taxYearBody,
      accent: Semantics(
        excludeSemantics: true,
        selected: selectedYear == year,
        button: true,
        label: l10n.currentYearLabel(year),
        onTap: onSelect,
        child: InkWell(
          key: const ValueKey('action:fact_tax_year.confirm_current_year'),
          onTap: onSelect,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selectedYear == year ? _sage : _porcelain,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selectedYear == year ? _ink : _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.confirmYear(year),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Icon(
                  selectedYear == year
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (selectedYear == year)
          MintDesignLabAction(
            key: const ValueKey('action:fact_tax_year.continue'),
            label: l10n.continueLabel,
            onPressed: onContinue,
          ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_tax_year.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _LppQuestion extends StatelessWidget {
  const _LppQuestion({
    required this.selected,
    required this.onChoose,
    required this.onBack,
  });

  final _LppAffiliation? selected;
  final ValueChanged<_LppAffiliation> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_lpp_affiliation',
      eyebrow: l10n.lppQuestionEyebrow,
      title: l10n.lppQuestionTitle,
      body: l10n.lppQuestionBody,
      accent: _EditorialNote(text: l10n.lppQuestionEvidence),
      actions: [
        Semantics(
          key: const ValueKey('group:fact_lpp_affiliation.choices'),
          container: true,
          explicitChildNodes: true,
          label: l10n.lppQuestionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_yes',
                label: l10n.lppChoiceYes,
                selected: selected == _LppAffiliation.yes,
                onPressed: () => onChoose(_LppAffiliation.yes),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_no',
                label: l10n.lppChoiceNo,
                selected: selected == _LppAffiliation.no,
                onPressed: () => onChoose(_LppAffiliation.no),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_lpp_affiliation.choose_unknown',
                label: l10n.lppChoiceUnknown,
                selected: selected == _LppAffiliation.unknown,
                onPressed: () => onChoose(_LppAffiliation.unknown),
              ),
            ],
          ),
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_lpp_affiliation.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _ChoiceAction extends StatelessWidget {
  const _ChoiceAction({
    required this.actionId,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String actionId;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: MintDesignLabAction.secondary(
      key: ValueKey(actionId),
      label: selected ? '✓  $label' : label,
      onPressed: onPressed,
    ),
  );
}

class _LppUnknownHelp extends StatelessWidget {
  const _LppUnknownHelp({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'lpp_unknown_help',
      eyebrow: l10n.lppUnknownEyebrow,
      title: l10n.lppUnknownTitle,
      body: l10n.lppUnknownBody,
      accent: Semantics(
        label: l10n.lppUnknownListLabel,
        child: Column(
          children:
              [
                    l10n.lppUnknownPayslip,
                    l10n.lppUnknownCertificate,
                    l10n.lppUnknownAsk,
                  ]
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _ChecklistRow(number: entry.key + 1, text: entry.value),
                  )
                  .toList(),
        ),
      ),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:lpp_unknown_help.back'),
          label: l10n.lppBackToQuestion,
          onPressed: onBack,
        ),
        _UnavailableReference(
          key: const ValueKey('action:lpp_unknown_help.keep_checklist_local'),
          label: l10n.lppKeepChecklist,
          unavailable: l10n.localReferenceUnavailable,
        ),
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: _sage),
          child: Text('$number', style: Theme.of(context).textTheme.labelLarge),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _WithoutLppBoundary extends StatelessWidget {
  const _WithoutLppBoundary({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'without_lpp_boundary',
      eyebrow: l10n.withoutLppEyebrow,
      title: l10n.withoutLppTitle,
      body: l10n.withoutLppBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction(
          key: const ValueKey('action:without_lpp_boundary.back'),
          label: l10n.lppCorrectAnswer,
          onPressed: onBack,
        ),
        _UnavailableReference(
          key: const ValueKey(
            'action:without_lpp_boundary.keep_explanation_local',
          ),
          label: l10n.withoutLppKeepExplanation,
          unavailable: l10n.localReferenceUnavailable,
        ),
      ],
    );
  }
}

class _UnavailableReference extends StatelessWidget {
  const _UnavailableReference({
    super.key,
    required this.label,
    required this.unavailable,
  });

  final String label;
  final String unavailable;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    enabled: false,
    readOnly: true,
    label: '$label. $unavailable',
    excludeSemantics: true,
    child: Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _porcelain,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: _secondaryInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label · $unavailable',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContributionQuestion extends StatelessWidget {
  const _ContributionQuestion({
    required this.taxYear,
    required this.selected,
    required this.edgeHelpExpanded,
    required this.onToggleEdgeHelp,
    required this.onChoose,
    required this.onBack,
  });

  final int taxYear;
  final _ContributionStatus? selected;
  final bool edgeHelpExpanded;
  final VoidCallback onToggleEdgeHelp;
  final ValueChanged<_ContributionStatus> onChoose;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_contribution',
      eyebrow: l10n.contributionEyebrow(taxYear),
      title: l10n.contributionTitle(taxYear),
      body: l10n.contributionBody,
      accent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorialNote(text: l10n.contributionCreditedNote(taxYear)),
          const SizedBox(height: 12),
          Text(
            l10n.contributionAmountNote,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _DisclosureAction(
            label: l10n.contributionEdgeHelp,
            expanded: edgeHelpExpanded,
            onPressed: onToggleEdgeHelp,
          ),
          if (edgeHelpExpanded) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('content:fact_contribution.edge_help'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              decoration: BoxDecoration(
                color: _porcelain,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  l10n.contributionEdgePending,
                  l10n.contributionEdgeTransfer,
                  l10n.contributionEdgeBuyback,
                  l10n.contributionEdgeFullRefund,
                  l10n.contributionEdgePartialRefund,
                  l10n.contributionEdgeUnclearCorrection,
                  l10n.contributionEdgeMixedTransfer,
                  l10n.contributionEdgeReturn,
                  l10n.contributionEdgeAdjustment,
                ].map((text) => _MovementRule(text: text)).toList(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Semantics(
          key: const ValueKey('group:fact_contribution.choices'),
          container: true,
          explicitChildNodes: true,
          label: l10n.contributionChoiceGroupLabel(taxYear),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_yes',
                label: l10n.contributionChoiceYes,
                selected: selected == _ContributionStatus.yes,
                onPressed: () => onChoose(_ContributionStatus.yes),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_no',
                label: l10n.contributionChoiceNo,
                selected: selected == _ContributionStatus.no,
                onPressed: () => onChoose(_ContributionStatus.no),
              ),
              const SizedBox(height: 6),
              _ChoiceAction(
                actionId: 'action:fact_contribution.choose_unknown',
                label: l10n.contributionChoiceUnknown,
                selected: selected == _ContributionStatus.unknown,
                onPressed: () => onChoose(_ContributionStatus.unknown),
              ),
            ],
          ),
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_contribution.back'),
          label: l10n.backLabel,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _DisclosureAction extends StatelessWidget {
  const _DisclosureAction({
    required this.label,
    required this.expanded,
    required this.onPressed,
  });

  final String label;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: expanded,
    label: label,
    onTap: onPressed,
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey('action:fact_contribution.toggle_edge_help'),
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    ),
  );
}

class _MovementRule extends StatelessWidget {
  const _MovementRule({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.arrow_right_rounded, size: 20, color: _coral),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _ContributionUnknownHelp extends StatelessWidget {
  const _ContributionUnknownHelp({
    required this.taxYear,
    required this.onContinueEducation,
    required this.onBack,
  });

  final int taxYear;
  final VoidCallback onContinueEducation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'contribution_unknown_help',
      eyebrow: l10n.contributionUnknownEyebrow,
      title: l10n.contributionUnknownTitle,
      body: l10n.contributionUnknownBody(taxYear),
      accent: Semantics(
        label: l10n.contributionUnknownListLabel,
        child: Column(
          children:
              [
                    l10n.contributionUnknownProviderStatement(taxYear),
                    l10n.contributionUnknownInsuranceCertificate,
                    l10n.contributionUnknownProviderQuestion,
                    l10n.contributionUnknownTransferWarning,
                    l10n.contributionUnknownEducationLimit,
                  ]
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _ChecklistRow(number: entry.key + 1, text: entry.value),
                  )
                  .toList(),
        ),
      ),
      actions: [
        MintDesignLabAction(
          key: const ValueKey(
            'action:contribution_unknown_help.continue_education_only',
          ),
          label: l10n.contributionUnknownContinueEducation,
          onPressed: onContinueEducation,
        ),
        MintDesignLabAction.text(
          key: const ValueKey('action:contribution_unknown_help.back'),
          label: l10n.contributionBackToQuestion,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _ContributionAmountBoundary extends StatelessWidget {
  const _ContributionAmountBoundary({
    required this.taxYear,
    required this.onBack,
  });
  final int taxYear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_contributed_amount',
      eyebrow: l10n.nextStepEyebrow,
      title: l10n.contributionAmountBoundaryTitle(taxYear),
      body: l10n.contributionAmountBoundaryBody(taxYear),
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_contributed_amount.back'),
          label: l10n.contributionBoundaryBack,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _CantonBoundary extends StatelessWidget {
  const _CantonBoundary({required this.taxYear, required this.onBack});
  final int taxYear;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'fact_canton',
      eyebrow: l10n.nextStepEyebrow,
      title: l10n.contributionCantonBoundaryTitle(taxYear),
      body: l10n.contributionCantonBoundaryBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_canton.back'),
          label: l10n.contributionBoundaryBack,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _EducationBoundary extends StatelessWidget {
  const _EducationBoundary({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return _Page(
      nodeId: 'education_explanation',
      eyebrow: l10n.contributionUnknownEyebrow,
      title: l10n.contributionEducationTitle,
      body: l10n.contributionEducationBody,
      accent: const _QuietOrb(),
      actions: [
        MintDesignLabAction.text(
          key: const ValueKey('action:education_explanation.back'),
          label: l10n.contributionEducationBack,
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _Page extends StatefulWidget {
  const _Page({
    required this.nodeId,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.accent,
    required this.actions,
  });
  final String nodeId;
  final String eyebrow;
  final String title;
  final String body;
  final Widget accent;
  final List<Widget> actions;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final ScrollController _scrollController = ScrollController();
  final FocusNode _headingFocus = FocusNode(debugLabel: 'page heading');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headingFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headingFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final actionPanel = _ActionPanel(actions: widget.actions);
    return Column(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            sortKey: const OrdinalSortKey(2),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                key: ValueKey('scroll:${widget.nodeId}'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.eyebrow,
                      style: const TextStyle(
                        fontFamily: 'Supreme',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        color: _coral,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Focus(
                      key: ValueKey('heading:${widget.nodeId}'),
                      focusNode: _headingFocus,
                      child: Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          widget.title,
                          style: _editorial(largeText ? 28 : 38),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.body,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    widget.accent,
                    if (largeText) ...[const SizedBox(height: 24), actionPanel],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!largeText)
          Semantics(
            container: true,
            sortKey: const OrdinalSortKey(3),
            child: actionPanel,
          ),
      ],
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _paper,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: actions
            .expand((action) => [action, const SizedBox(height: 6)])
            .toList(),
      ),
    ),
  );
}

class _SafeExitSheet extends StatefulWidget {
  const _SafeExitSheet({
    required this.l10n,
    required this.onResume,
    required this.onLeave,
  });

  final MintNextLocalizations l10n;
  final VoidCallback onResume;
  final VoidCallback onLeave;

  @override
  State<_SafeExitSheet> createState() => _SafeExitSheetState();
}

class _SafeExitSheetState extends State<_SafeExitSheet> {
  final ScrollController _controller = ScrollController();
  final FocusNode _headingFocus = FocusNode(debugLabel: 'safe exit heading');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _headingFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _headingFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    policy: WidgetOrderTraversalPolicy(),
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.tab) {
          return KeyEventResult.ignored;
        }
        final scope = FocusScope.of(context);
        HardwareKeyboard.instance.isShiftPressed
            ? scope.previousFocus()
            : scope.nextFocus();
        return KeyEventResult.handled;
      },
      child: SafeArea(
        key: const ValueKey('overlay:safe_exit'),
        child: Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const ValueKey('scroll:safe_exit'),
            controller: _controller,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Focus(
                  key: const ValueKey('heading:safe_exit'),
                  focusNode: _headingFocus,
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.l10n.safeExitTitle,
                      style: _editorial(30),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.l10n.safeExitBody,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                MintDesignLabAction(
                  key: const ValueKey('overlay-action:safe_exit.resume'),
                  label: widget.l10n.resume,
                  onPressed: widget.onResume,
                ),
                const SizedBox(height: 10),
                MintDesignLabAction.secondary(
                  key: const ValueKey(
                    'overlay-action:safe_exit.keep_local_reference',
                  ),
                  label: widget.l10n.keepReferenceUnavailable,
                  onPressed: null,
                ),
                const SizedBox(height: 10),
                MintDesignLabAction.text(
                  key: const ValueKey(
                    'overlay-action:safe_exit.leave_without_saving',
                  ),
                  label: widget.l10n.leave,
                  onPressed: widget.onLeave,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EditorialNote extends StatelessWidget {
  const _EditorialNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _porcelain,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Text(text, style: _editorial(21).copyWith(height: 1.35)),
  );
}

class _QuietOrb extends StatelessWidget {
  const _QuietOrb();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color(0xFFE8CFB8), _sage]),
      ),
    ),
  );
}

class _Terminal extends StatelessWidget {
  const _Terminal({required this.title, required this.onRestart});
  final String title;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) => _Page(
    nodeId: 'dismissed',
    eyebrow: 'MINT',
    title: title,
    body: MintNextLocalizations.of(context).safeExitBody,
    accent: const _QuietOrb(),
    actions: [
      MintDesignLabAction(
        key: const ValueKey('action:dismissed.restart'),
        label: MintNextLocalizations.of(context).start,
        onPressed: onRestart,
      ),
    ],
  );
}

TextStyle _editorial(double size) => TextStyle(
  fontFamily: 'Gambarino',
  fontSize: size,
  height: 1.12,
  color: _ink,
  fontWeight: FontWeight.w400,
);

enum MintActionTone { primary, secondary, text }

class MintDesignLabAction extends StatelessWidget {
  const MintDesignLabAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
  }) : tone = MintActionTone.primary;
  const MintDesignLabAction.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
  }) : tone = MintActionTone.secondary;
  const MintDesignLabAction.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.semanticsLabel,
    this.semanticsSortKey,
    this.focusNode,
  }) : tone = MintActionTone.text;

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final String? semanticsLabel;
  final SemanticsSortKey? semanticsSortKey;
  final FocusNode? focusNode;
  final MintActionTone tone;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(compact ? 72 : double.infinity, 48),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: 'Supreme',
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final button = switch (tone) {
      MintActionTone.primary => FilledButton(
        focusNode: semanticsLabel == null ? focusNode : null,
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(_ink),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.secondary => OutlinedButton(
        focusNode: semanticsLabel == null ? focusNode : null,
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_ink),
          side: const WidgetStatePropertyAll(BorderSide(color: _ink)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.text => TextButton(
        focusNode: semanticsLabel == null ? focusNode : null,
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_secondaryInk),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    };
    if (semanticsLabel == null) return button;
    return Focus(
      focusNode: focusNode,
      child: Semantics(
        label: semanticsLabel,
        sortKey: semanticsSortKey,
        button: true,
        enabled: onPressed != null,
        onTap: onPressed,
        excludeSemantics: true,
        child: button,
      ),
    );
  }
}
