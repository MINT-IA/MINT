import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_civil_status_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait état civil (Lego 2).
///
/// Une seule décision : six cartes, aucune présélection, aucun menu
/// déroulant. Collecte → relecture explicite → confirmation → résumé
/// enregistré avec modification et suppression. La sortie sûre n'écrit
/// rien ; un échec de persistance est visible et ne prétend jamais avoir
/// réussi.
class MintNextEtatCivilScreen extends StatefulWidget {
  const MintNextEtatCivilScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MintNextEtatCivilScreen> createState() =>
      _MintNextEtatCivilScreenState();
}

enum _Step { collect, review, saved }

String mintNextEtatCivilStatusLabel(S l10n, MintNextCivilStatus status) =>
    switch (status) {
      MintNextCivilStatus.celibataire => l10n.mintNextEtatCivilStatusCelibataire,
      MintNextCivilStatus.marie => l10n.mintNextEtatCivilStatusMarie,
      MintNextCivilStatus.partenariatEnregistre =>
        l10n.mintNextEtatCivilStatusPartenariatEnregistre,
      MintNextCivilStatus.concubinage => l10n.mintNextEtatCivilStatusConcubinage,
      MintNextCivilStatus.divorce => l10n.mintNextEtatCivilStatusDivorce,
      MintNextCivilStatus.veuf => l10n.mintNextEtatCivilStatusVeuf,
    };

class _MintNextEtatCivilScreenState extends State<MintNextEtatCivilScreen> {
  _Step _step = _Step.collect;
  MintNextCivilStatus? _status;
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().civilStatusFact;
    if (existing != null) {
      _step = _Step.saved;
      _status = existing.status;
    }
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  MintNextCivilStatusFact _draftFact() => MintNextCivilStatusFact(
        status: _status!,
        assertedAt: _now(),
        source: MintNextCivilStatusFact.userDeclarationSource,
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
          .saveCivilStatusFact(_draftFact());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextEtatCivil] save failed: '
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
        title: Text(l10n.mintNextEtatCivilDeleteTitle),
        content: Text(l10n.mintNextEtatCivilDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextEtatCivilDeleteCancel),
          ),
          Semantics(
            identifier: 'action:etat_civil.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextEtatCivilDeleteConfirm),
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
      await provider.deleteCivilStatusFact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
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
        title: Text(l10n.mintNextEtatCivilTitle),
        leading: Semantics(
          identifier: 'action:etat_civil.safe_exit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.mintNextEtatCivilSafeExit,
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
                  identifier: 'status:etat_civil.save_failed',
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.mintNextEtatCivilSaveFailed,
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

  Widget _statusCard(S l10n, MintNextCivilStatus status) {
    final selected = _status == status;
    return Semantics(
      identifier: 'input:etat_civil.status_${status.id}',
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy
            ? null
            : () => setState(() {
                  _status = status;
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
                child: Text(mintNextEtatCivilStatusLabel(l10n, status),
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
        identifier: 'node:etat_civil.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextEtatCivilQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextEtatCivilHint,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            for (final status in MintNextCivilStatus.values) ...[
              _statusCard(l10n, status),
              const SizedBox(height: MintSpacing.sm),
            ],
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.xs),
              Semantics(
                identifier: 'status:etat_civil.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextEtatCivilErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'action:etat_civil.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_status == null) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextEtatCivilContinue),
              ),
            ),
          ],
        ),
      );

  Widget _review(S l10n) => Semantics(
        identifier: 'node:etat_civil.review',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextEtatCivilReviewTitle,
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
                  Text(mintNextEtatCivilStatusLabel(l10n, _status!),
                      style: MintTextStyles.headlineSmall(
                          color: MintColors.textPrimary)),
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    l10n.mintNextEtatCivilReviewSource(
                        MaterialLocalizations.of(context)
                            .formatShortDate(_now())),
                    style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MintSpacing.xl),
            Semantics(
              identifier: 'action:etat_civil.confirm',
              button: true,
              child: FilledButton(
                onPressed: _busy ? null : _confirmSave,
                child: Text(l10n.mintNextEtatCivilConfirm),
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Semantics(
              identifier: 'action:etat_civil.back_to_collect',
              button: true,
              child: TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _step = _Step.collect),
                child: Text(l10n.mintNextEtatCivilBack),
              ),
            ),
          ],
        ),
      );

  Widget _saved(S l10n) {
    final fact = context.watch<CoachProfileProvider>().civilStatusFact;
    if (fact == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:etat_civil.saved',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextEtatCivilSavedTitle,
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
                  identifier: 'fact:etat_civil.summary',
                  child: Text(mintNextEtatCivilStatusLabel(l10n, fact.status),
                      style: MintTextStyles.headlineSmall(
                          color: MintColors.textPrimary)),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextEtatCivilReviewSource(
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
            identifier: 'action:etat_civil.edit',
            button: true,
            child: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _status = fact.status;
                        _step = _Step.collect;
                      }),
              child: Text(l10n.mintNextEtatCivilEdit),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:etat_civil.delete',
            button: true,
            child: TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(l10n.mintNextEtatCivilDelete),
            ),
          ),
        ],
      ),
    );
  }
}
