import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait affiliation LPP (Lego 4).
///
/// Une seule question, deux cartes Oui/Non sans présélection, une aide qui
/// distingue affiliation, certificat et avoir LPP. Collecte → relecture →
/// confirmation → résumé avec modification et suppression. La suppression
/// rend l'affiliation INCONNUE — jamais « non ». La sortie sûre n'écrit
/// rien ; un échec de persistance est visible.
class MintNextLppAffiliationScreen extends StatefulWidget {
  const MintNextLppAffiliationScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MintNextLppAffiliationScreen> createState() =>
      _MintNextLppAffiliationScreenState();
}

enum _Step { collect, review, saved }

String mintNextLppAffiliationLabel(S l10n, bool affiliated) => affiliated
    ? l10n.mintNextLppAffiliationStatusYes
    : l10n.mintNextLppAffiliationStatusNo;

class _MintNextLppAffiliationScreenState
    extends State<MintNextLppAffiliationScreen> {
  _Step _step = _Step.collect;
  bool? _affiliated;
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().lppAffiliationFact;
    if (existing != null) {
      _step = _Step.saved;
      _affiliated = existing.affiliated;
    }
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  MintNextLppAffiliationFact _draftFact() => MintNextLppAffiliationFact(
        affiliated: _affiliated!,
        assertedAt: _now(),
        source: MintNextLppAffiliationFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> _confirmSave() async {
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await context
          .read<CoachProfileProvider>()
          .saveLppAffiliationFact(_draftFact());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextLppAffiliation] save failed: '
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
        title: Text(l10n.mintNextLppAffiliationDeleteTitle),
        content: Text(l10n.mintNextLppAffiliationDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextLppAffiliationDeleteCancel),
          ),
          Semantics(
            identifier: 'action:lpp_affiliation.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextLppAffiliationDeleteConfirm),
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
      await provider.deleteLppAffiliationFact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _affiliated = null;
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
        title: Text(l10n.mintNextLppAffiliationTitle),
        leading: Semantics(
          identifier: 'action:lpp_affiliation.safe_exit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.mintNextLppAffiliationSafeExit,
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
                  identifier: 'status:lpp_affiliation.save_failed',
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.mintNextLppAffiliationSaveFailed,
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

  Widget _choiceCard(S l10n, {required bool value}) {
    final selected = _affiliated == value;
    return Semantics(
      identifier: value
          ? 'input:lpp_affiliation.yes'
          : 'input:lpp_affiliation.no',
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy
            ? null
            : () => setState(() {
                  _affiliated = value;
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
                child: Text(
                    value
                        ? l10n.mintNextLppAffiliationYes
                        : l10n.mintNextLppAffiliationNo,
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
        identifier: 'node:lpp_affiliation.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextLppAffiliationQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextLppAffiliationHint,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            _choiceCard(l10n, value: true),
            const SizedBox(height: MintSpacing.sm),
            _choiceCard(l10n, value: false),
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:lpp_affiliation.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextLppAffiliationErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'action:lpp_affiliation.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_affiliated == null) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextLppAffiliationContinue),
              ),
            ),
          ],
        ),
      );

  Widget _review(S l10n) {
    if (_affiliated == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:lpp_affiliation.review',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextLppAffiliationReviewTitle,
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
                Text(mintNextLppAffiliationLabel(l10n, _affiliated!),
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary)),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextLppAffiliationReviewSource(
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
            identifier: 'action:lpp_affiliation.confirm',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _confirmSave,
              child: Text(l10n.mintNextLppAffiliationConfirm),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:lpp_affiliation.back_to_collect',
            button: true,
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.collect),
              child: Text(l10n.mintNextLppAffiliationBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saved(S l10n) {
    final fact = context.watch<CoachProfileProvider>().lppAffiliationFact;
    if (fact == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:lpp_affiliation.saved',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextLppAffiliationSavedTitle,
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
                  identifier: 'fact:lpp_affiliation.summary',
                  child: Text(
                      mintNextLppAffiliationLabel(l10n, fact.affiliated),
                      style: MintTextStyles.headlineSmall(
                          color: MintColors.textPrimary)),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextLppAffiliationReviewSource(
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
            identifier: 'action:lpp_affiliation.edit',
            button: true,
            child: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _affiliated = fact.affiliated;
                        _step = _Step.collect;
                      }),
              child: Text(l10n.mintNextLppAffiliationEdit),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:lpp_affiliation.delete',
            button: true,
            child: TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(l10n.mintNextLppAffiliationDelete),
            ),
          ),
        ],
      ),
    );
  }
}
