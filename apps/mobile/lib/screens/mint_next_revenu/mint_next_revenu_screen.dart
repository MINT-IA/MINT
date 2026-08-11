import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait revenu (Lego 3).
///
/// Une seule décision cognitive : « combien je reçois, selon quelle
/// période ». Un montant, deux cartes de période sans présélection.
/// Collecte → relecture explicite → confirmation → résumé enregistré avec
/// modification et suppression. La sortie sûre n'écrit rien ; un échec de
/// persistance est visible et ne prétend jamais avoir réussi.
class MintNextRevenuScreen extends StatefulWidget {
  const MintNextRevenuScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MintNextRevenuScreen> createState() => _MintNextRevenuScreenState();
}

enum _Step { collect, review, saved }

String mintNextRevenuPeriodLabel(S l10n, MintNextRevenuPeriod period) =>
    switch (period) {
      MintNextRevenuPeriod.monthly => l10n.mintNextRevenuPeriodMonthly,
      MintNextRevenuPeriod.yearly => l10n.mintNextRevenuPeriodYearly,
    };

/// Format suisse « 6'500 CHF » — centimes affichés seulement s'ils existent.
String mintNextRevenuChf(int amountCents) {
  final francs = amountCents ~/ 100;
  final cents = amountCents % 100;
  final grouped = francs.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => "'");
  return cents == 0
      ? '$grouped CHF'
      : "$grouped.${cents.toString().padLeft(2, '0')} CHF";
}

/// Identifiants sémantiques littéraux (audit locators — pas d'interpolation).
const _periodSemanticsIds = {
  MintNextRevenuPeriod.monthly: 'input:revenu.period_monthly',
  MintNextRevenuPeriod.yearly: 'input:revenu.period_yearly',
};

class _MintNextRevenuScreenState extends State<MintNextRevenuScreen> {
  _Step _step = _Step.collect;
  final _amountController = TextEditingController();
  MintNextRevenuPeriod? _period;
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().revenuFact;
    if (existing != null) {
      _step = _Step.saved;
      _period = existing.period;
      _amountController.text = _editableAmount(existing.amountCents);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  static String _editableAmount(int amountCents) => amountCents % 100 == 0
      ? (amountCents ~/ 100).toString()
      : (amountCents / 100).toStringAsFixed(2);

  /// CHF saisi → centimes. Accepte « 6500 », « 6500.50 », « 6'500 »,
  /// virgule ou point ; null si invalide ou non strictement positif.
  static int? parseAmountCents(String raw) {
    final cleaned =
        raw.trim().replaceAll("'", '').replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite || value <= 0) return null;
    final cents = (value * 100).round();
    return cents > 0 ? cents : null;
  }

  MintNextRevenuFact _draftFact(int amountCents) => MintNextRevenuFact(
        amountCents: amountCents,
        period: _period!,
        assertedAt: _now(),
        source: MintNextRevenuFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> _confirmSave() async {
    final amountCents = parseAmountCents(_amountController.text);
    if (amountCents == null || _period == null) {
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
      await context
          .read<CoachProfileProvider>()
          .saveRevenuFact(_draftFact(amountCents));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextRevenu] save failed: '
          '${error.runtimeType}: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _saveFailed = true;
      });
    }
  }

  Future<void> _delete() async {
    final l10n = S.of(context)!;
    final provider = context.read<CoachProfileProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.mintNextRevenuDeleteTitle),
        content: Text(l10n.mintNextRevenuDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextRevenuDeleteCancel),
          ),
          Semantics(
            identifier: 'action:revenu.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextRevenuDeleteConfirm),
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
      await provider.deleteRevenuFact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _period = null;
        _amountController.clear();
        _step = _Step.collect;
      });
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
        title: Text(l10n.mintNextRevenuTitle),
        leading: Semantics(
          identifier: 'action:revenu.safe_exit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.mintNextRevenuSafeExit,
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
                  identifier: 'status:revenu.save_failed',
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.mintNextRevenuSaveFailed,
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
                _Step.collect => _collect(l10n),
                _Step.review => _review(l10n),
                _Step.saved => _saved(l10n),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodCard(S l10n, MintNextRevenuPeriod period) {
    final selected = _period == period;
    return Semantics(
      identifier: _periodSemanticsIds[period]!,
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy
            ? null
            : () => setState(() {
                  _period = period;
                  _validationError = false;
                }),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.md),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? MintColors.primary : MintColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(mintNextRevenuPeriodLabel(l10n, period),
                    style: MintTextStyles.bodyLarge(
                        color: MintColors.textPrimary)),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: MintColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collect(S l10n) => Semantics(
        identifier: 'node:revenu.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextRevenuQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextRevenuHint,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'input:revenu.amount',
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[\d.,' ]")),
                ],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.mintNextRevenuAmountLabel,
                  hintText: l10n.mintNextRevenuAmountHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _validationError = false),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            for (final period in MintNextRevenuPeriod.values) ...[
              _periodCard(l10n, period),
              const SizedBox(height: MintSpacing.sm),
            ],
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'status:revenu.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextRevenuErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'action:revenu.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (parseAmountCents(_amountController.text) == null ||
                            _period == null) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextRevenuContinue),
              ),
            ),
          ],
        ),
      );

  Widget _review(S l10n) {
    final amountCents = parseAmountCents(_amountController.text);
    return Semantics(
      identifier: 'node:revenu.review',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextRevenuReviewTitle,
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
                Text(
                  '${mintNextRevenuChf(amountCents ?? 0)} · '
                  '${mintNextRevenuPeriodLabel(l10n, _period!)}',
                  style: MintTextStyles.headlineSmall(
                      color: MintColors.textPrimary),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextRevenuReviewSource(
                      MaterialLocalizations.of(context)
                          .formatShortDate(_now())),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:revenu.confirm',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _confirmSave,
              child: Text(l10n.mintNextRevenuConfirm),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:revenu.back_to_collect',
            button: true,
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.collect),
              child: Text(l10n.mintNextRevenuBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saved(S l10n) {
    final fact = context.watch<CoachProfileProvider>().revenuFact;
    if (fact == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:revenu.saved',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextRevenuSavedTitle,
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
                Semantics(
                  identifier: 'fact:revenu.summary',
                  child: Text(
                    '${mintNextRevenuChf(fact.amountCents)} · '
                    '${mintNextRevenuPeriodLabel(l10n, fact.period)}',
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary),
                  ),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextRevenuReviewSource(
                      MaterialLocalizations.of(context)
                          .formatShortDate(fact.assertedAt.toLocal())),
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.xl),
          Semantics(
            identifier: 'action:revenu.edit',
            button: true,
            child: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _period = fact.period;
                        _amountController.text =
                            _editableAmount(fact.amountCents);
                        _step = _Step.collect;
                      }),
              child: Text(l10n.mintNextRevenuEdit),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:revenu.delete',
            button: true,
            child: TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(l10n.mintNextRevenuDelete),
            ),
          ),
        ],
      ),
    );
  }
}
