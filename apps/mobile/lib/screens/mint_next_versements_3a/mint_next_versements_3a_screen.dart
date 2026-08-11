import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_versements_3a_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_revenu/mint_next_revenu_screen.dart'
    show MintNextRevenuScreen, mintNextRevenuChf;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait versements 3a (Lego 5) — le premier fait pluriel.
///
/// La liste annuelle est l'écran de revue ; la saisie enregistre UN
/// versement (montant + date de crédit = une décision factuelle, année
/// fiscale pinnée, par défaut celle de la date). Chaque entrée se corrige ou
/// se supprime individuellement par son id stable. Un dépassement de plafond
/// n'est ni bloqué ni tronqué. La sortie sûre n'écrit rien ; un échec de
/// persistance est visible.
class MintNextVersements3aScreen extends StatefulWidget {
  const MintNextVersements3aScreen({super.key, this.now});

  final DateTime Function()? now;

  /// Première année fiscale sélectionnable (premières lacunes rachetables).
  static const minTaxYear = 2025;

  /// Date saisie « jj.mm.aaaa » → date UTC ; parsing lexical strict,
  /// jamais de correction silencieuse.
  static DateTime? parseCreditDate(String raw) {
    final match =
        RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(raw.trim());
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    if (year < 1985 || year > 2100 || month < 1 || month > 12) return null;
    final date = DateTime.utc(year, month, day);
    // Rejette les débordements silencieux (31.02 → 03.03).
    if (date.month != month || date.day != day) return null;
    return date;
  }

  @override
  State<MintNextVersements3aScreen> createState() =>
      _MintNextVersements3aScreenState();
}

enum _Step { list, collect, review }

class _MintNextVersements3aScreenState
    extends State<MintNextVersements3aScreen> {
  _Step _step = _Step.list;
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  int? _taxYear;
  bool _taxYearPinnedManually = false;

  /// Id de l'entrée en cours de correction — null pour un ajout.
  String? _editingId;
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().versements3aFact;
    if (existing == null || existing.entries.isEmpty) {
      _step = _Step.collect;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  MintNextVersements3aFact _currentFact() =>
      context.read<CoachProfileProvider>().versements3aFact ??
      MintNextVersements3aFact.empty(at: _now());

  int? _amountCents() =>
      MintNextRevenuScreen.parseAmountCents(_amountController.text);

  DateTime? _creditDate() =>
      MintNextVersements3aScreen.parseCreditDate(_dateController.text);

  int _effectiveTaxYear() =>
      _taxYear ?? _creditDate()?.year ?? _now().year;

  List<int> _selectableYears() {
    final current = _now().year;
    return [
      for (var y = current; y >= MintNextVersements3aScreen.minTaxYear; y--) y
    ];
  }

  void _startAdd() => setState(() {
        _editingId = null;
        _amountController.clear();
        _dateController.clear();
        _taxYear = null;
        _taxYearPinnedManually = false;
        _validationError = false;
        _step = _Step.collect;
      });

  void _startEdit(MintNextVersement3aEntry entry) => setState(() {
        _editingId = entry.id;
        _amountController.text =
            MintNextRevenuScreen.editableAmount(entry.amountCents);
        final d = entry.creditedAt;
        _dateController.text = '${d.day.toString().padLeft(2, '0')}.'
            '${d.month.toString().padLeft(2, '0')}.${d.year}';
        _taxYear = entry.taxYear;
        _taxYearPinnedManually = true;
        _validationError = false;
        _step = _Step.collect;
      });

  MintNextVersement3aEntry _draftEntry(MintNextVersements3aFact fact) {
    final now = _now();
    // Id unique même sous horloge figée (tests, rafales) : l'instant seul ne
    // suffit pas — le compteur de mutations du fait le complète.
    return MintNextVersement3aEntry(
      id: _editingId ??
          'v${now.microsecondsSinceEpoch}-${fact.mutationCount}',
      amountCents: _amountCents()!,
      creditedAt: _creditDate()!,
      taxYear: _effectiveTaxYear(),
    );
  }

  Future<void> _confirmSave() async {
    if (_amountCents() == null || _creditDate() == null) {
      setState(() {
        _validationError = true;
        _step = _Step.collect;
      });
      return;
    }
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      final now = _now();
      final fact = _currentFact();
      final entry = _draftEntry(fact);
      final next = _editingId == null
          ? fact.withEntryAdded(entry, now)
          : fact.withEntryUpdated(_editingId!, entry, now);
      await context.read<CoachProfileProvider>().saveVersements3aFact(next);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.list;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextVersements3a] save failed: '
          '${error.runtimeType}: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _deleteEntry(MintNextVersement3aEntry entry) async {
    final l10n = S.of(context)!;
    final provider = context.read<CoachProfileProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mintNextVersements3aDeleteEntryTitle),
        content: Text(l10n.mintNextVersements3aDeleteEntryBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextVersements3aDeleteCancel),
          ),
          Semantics(
            identifier: 'action:versements_3a.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextVersements3aDeleteConfirm),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      final next = _currentFact().withEntryRemoved(entry.id, _now());
      await provider.saveVersements3aFact(next);
      if (!mounted) return;
      setState(() => _busy = false);
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  void _safeExit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      appBar: AppBar(
        title: Text(l10n.mintNextVersements3aTitle),
        leading: Semantics(
          identifier: 'action:versements_3a.safe_exit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.mintNextVersements3aSafeExit,
            onPressed: _safeExit,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saveFailed)
                Semantics(
                  identifier: 'status:versements_3a.save_failed',
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.mintNextVersements3aSaveFailed,
                        style: MintTextStyles.bodyMedium(
                            color: MintColors.textPrimary)),
                  ),
                ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: MintSpacing.md),
                  child: LinearProgressIndicator(),
                ),
              switch (_step) {
                _Step.list => _list(l10n),
                _Step.collect => _collect(l10n),
                _Step.review => _review(l10n),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(S l10n) {
    final fact = context.watch<CoachProfileProvider>().versements3aFact;
    if (fact == null || fact.entries.isEmpty) {
      return _collect(l10n);
    }
    final years = fact.taxYears.toList()..sort((a, b) => b.compareTo(a));
    return Semantics(
      identifier: 'node:versements_3a.list',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextVersements3aListTitle,
                style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary)),
          ),
          const SizedBox(height: MintSpacing.md),
          for (final year in years) ...[
            Text(
              l10n.mintNextVersements3aYearTotal('$year',
                  mintNextRevenuChf(fact.totalForYearCents(year))),
              style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
            ),
            const SizedBox(height: MintSpacing.sm),
            for (final entry in fact.entriesForYear(year)) ...[
              Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                margin: const EdgeInsets.only(bottom: MintSpacing.sm),
                decoration: BoxDecoration(
                  color: MintColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MintColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mintNextRevenuChf(entry.amountCents),
                              style: MintTextStyles.bodyLarge(
                                  color: MintColors.textPrimary)),
                          Text(
                            l10n.mintNextVersements3aEntryCredited(
                                MaterialLocalizations.of(context)
                                    .formatShortDate(
                                        entry.creditedAt.toLocal())),
                            style: MintTextStyles.bodySmall(
                                color: MintColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      identifier: 'action:versements_3a.entry_edit',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: l10n.mintNextVersements3aEdit,
                        onPressed: _busy ? null : () => _startEdit(entry),
                      ),
                    ),
                    Semantics(
                      identifier: 'action:versements_3a.entry_delete',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: l10n.mintNextVersements3aDelete,
                        onPressed: _busy ? null : () => _deleteEntry(entry),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: MintSpacing.md),
          ],
          Semantics(
            identifier: 'action:versements_3a.add',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _startAdd,
              child: Text(l10n.mintNextVersements3aAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collect(S l10n) => Semantics(
        identifier: 'node:versements_3a.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextVersements3aQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextVersements3aHint,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'input:versements_3a.amount',
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.mintNextVersements3aAmountLabel,
                  hintText: l10n.mintNextVersements3aAmountHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _validationError = false),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'input:versements_3a.credit_date',
              child: TextField(
                controller: _dateController,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.mintNextVersements3aDateLabel,
                  hintText: l10n.mintNextVersements3aDateHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {
                  _validationError = false;
                  if (!_taxYearPinnedManually) _taxYear = null;
                }),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'input:versements_3a.tax_year',
              child: DropdownButtonFormField<int>(
                initialValue: _selectableYears().contains(_effectiveTaxYear())
                    ? _effectiveTaxYear()
                    : null,
                decoration: InputDecoration(
                  labelText: l10n.mintNextVersements3aTaxYearLabel,
                  helperText: l10n.mintNextVersements3aTaxYearHelper,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final year in _selectableYears())
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) => setState(() {
                  _taxYear = value;
                  _taxYearPinnedManually = true;
                }),
              ),
            ),
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:versements_3a.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextVersements3aErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'action:versements_3a.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_amountCents() == null || _creditDate() == null) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextVersements3aContinue),
              ),
            ),
            if (_currentFact().entries.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'action:versements_3a.back_to_list',
                button: true,
                child: TextButton(
                  onPressed:
                      _busy ? null : () => setState(() => _step = _Step.list),
                  child: Text(l10n.mintNextVersements3aBackToList),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _review(S l10n) {
    final amountCents = _amountCents();
    final creditDate = _creditDate();
    if (amountCents == null || creditDate == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:versements_3a.review',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextVersements3aReviewTitle,
                style: MintTextStyles.headlineMedium(
                    color: MintColors.textPrimary)),
          ),
          const SizedBox(height: MintSpacing.md),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: MintColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mintNextRevenuChf(amountCents),
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary)),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  l10n.mintNextVersements3aEntryCredited(
                      MaterialLocalizations.of(context)
                          .formatShortDate(creditDate.toLocal())),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
                Text(
                  l10n.mintNextVersements3aReviewTaxYear(
                      '${_effectiveTaxYear()}'),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:versements_3a.confirm',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _confirmSave,
              child: Text(l10n.mintNextVersements3aConfirm),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:versements_3a.back_to_collect',
            button: true,
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.collect),
              child: Text(l10n.mintNextVersements3aBack),
            ),
          ),
        ],
      ),
    );
  }
}
