import 'package:flutter/material.dart';

import 'l10n/generated/mint_next_localizations.dart';

enum _DesignNode { today3aIntent, orientation, factTaxYear, dismissed }

class MintNextDesignLabApp extends StatelessWidget {
  const MintNextDesignLabApp({super.key, this.locale, this.textScaler});

  final Locale? locale;
  final TextScaler? textScaler;

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
      home: const _DesignLabJourney(),
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
  const _DesignLabJourney();

  @override
  State<_DesignLabJourney> createState() => _DesignLabJourneyState();
}

class _DesignLabJourneyState extends State<_DesignLabJourney> {
  _DesignNode _node = _DesignNode.today3aIntent;
  int? _taxYear;

  void _go(_DesignNode node) => setState(() => _node = node);

  String get _nodeId => switch (_node) {
    _DesignNode.today3aIntent => 'today_3a_intent',
    _DesignNode.orientation => 'orientation',
    _DesignNode.factTaxYear => 'fact_tax_year',
    _DesignNode.dismissed => 'dismissed',
  };

  Future<void> _showSafeExit() async {
    final l10n = MintNextLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      builder: (sheetContext) => _SafeExitSheet(
        l10n: l10n,
        onResume: () => Navigator.pop(sheetContext),
        onLeave: () {
          Navigator.pop(sheetContext);
          _go(_DesignNode.dismissed);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(nodeId: _nodeId, onExit: _showSafeExit),
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
                      onSelect: () =>
                          setState(() => _taxYear = DateTime.now().year),
                      onBack: () => _go(_DesignNode.orientation),
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
  const _Header({required this.nodeId, required this.onExit});
  final String nodeId;
  final VoidCallback onExit;

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
            IconButton(
              key: ValueKey('action:$nodeId.open_safe_exit'),
              tooltip: l10n.quit,
              onPressed: onExit,
              icon: const ExcludeSemantics(
                child: Text(
                  '×',
                  style: TextStyle(fontFamily: 'Supreme', fontSize: 28),
                ),
              ),
            )
          else
            MintDesignLabAction.text(
              key: ValueKey('action:$nodeId.open_safe_exit'),
              label: l10n.quit,
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
    required this.onSelect,
    required this.onBack,
  });
  final int? selectedYear;
  final VoidCallback onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = MintNextLocalizations.of(context);
    final year = DateTime.now().year;
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
      afterAccent: selectedYear == year
          ? Text(
              l10n.partialBoundary,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : null,
      actions: [
        MintDesignLabAction.text(
          key: const ValueKey('action:fact_tax_year.back'),
          label: l10n.backLabel,
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
    this.afterAccent,
  });
  final String nodeId;
  final String eyebrow;
  final String title;
  final String body;
  final Widget accent;
  final Widget? afterAccent;
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
                  if (widget.afterAccent != null) ...[
                    const SizedBox(height: 18),
                    widget.afterAccent!,
                  ],
                  if (largeText) ...[const SizedBox(height: 24), actionPanel],
                ],
              ),
            ),
          ),
        ),
        if (!largeText) actionPanel,
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
            Text(widget.l10n.safeExitTitle, style: _editorial(30)),
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
  }) : tone = MintActionTone.primary;
  const MintDesignLabAction.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  }) : tone = MintActionTone.secondary;
  const MintDesignLabAction.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
  }) : tone = MintActionTone.text;

  final String label;
  final VoidCallback? onPressed;
  final bool compact;
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
    return switch (tone) {
      MintActionTone.primary => FilledButton(
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(_ink),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.secondary => OutlinedButton(
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_ink),
          side: const WidgetStatePropertyAll(BorderSide(color: _ink)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
      MintActionTone.text => TextButton(
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(_secondaryInk),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    };
  }
}
