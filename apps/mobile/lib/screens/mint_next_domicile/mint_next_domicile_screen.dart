import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Cycle canonique du fait domicile fiscal (Lego 1).
///
/// Collecte → relecture explicite → confirmation → résumé enregistré avec
/// modification et suppression. La sortie sûre n'écrit rien ; un échec de
/// persistance est visible et ne prétend jamais avoir réussi.
class MintNextDomicileScreen extends StatefulWidget {
  const MintNextDomicileScreen({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<MintNextDomicileScreen> createState() => _MintNextDomicileScreenState();
}

enum _Step { collect, review, saved }

class _MintNextDomicileScreenState extends State<MintNextDomicileScreen> {
  _Step _step = _Step.collect;
  String? _canton;
  final _communeController = TextEditingController();
  bool _validationError = false;
  bool _saveFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final existing = context.read<CoachProfileProvider>().domicileFact;
    if (existing != null) {
      _step = _Step.saved;
      _canton = existing.canton;
      _communeController.text = existing.communeName;
    }
  }

  @override
  void dispose() {
    _communeController.dispose();
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)();

  MintNextDomicileFact _draftFact() => MintNextDomicileFact(
        canton: _canton!,
        communeName: _communeController.text.trim(),
        assertedAt: _now(),
        source: MintNextDomicileFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  Future<void> _confirmSave() async {
    setState(() {
      _busy = true;
      _saveFailed = false;
    });
    try {
      await context.read<CoachProfileProvider>().saveDomicileFact(_draftFact());
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = _Step.saved;
      });
    } on Object catch (error, stack) {
      debugPrint('[MintNextDomicile] save failed: '
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
        title: Text(l10n.mintNextDomicileDeleteTitle),
        content: Text(l10n.mintNextDomicileDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.mintNextDomicileDeleteCancel),
          ),
          Semantics(
            identifier: 'action:domicile.delete_confirm',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.mintNextDomicileDeleteConfirm),
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
      await provider.deleteDomicileFact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _canton = null;
        _communeController.clear();
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
        title: Text(l10n.mintNextDomicileTitle),
        leading: Semantics(
          identifier: 'action:domicile.safe_exit',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.mintNextDomicileSafeExit,
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
                  identifier: 'status:domicile.save_failed',
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(MintSpacing.md),
                    margin: const EdgeInsets.only(bottom: MintSpacing.md),
                    decoration: BoxDecoration(
                      color: MintColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.mintNextDomicileSaveFailed,
                        style:
                            MintTextStyles.bodyMedium(color: MintColors.textPrimary)),
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

  Widget _collect(S l10n) => Semantics(
        identifier: 'node:domicile.collect',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.mintNextDomicileQuestion,
                  style: MintTextStyles.headlineMedium(
                      color: MintColors.textPrimary)),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(l10n.mintNextDomicileWhy,
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'input:domicile.canton',
              child: DropdownButtonFormField<String>(
                initialValue: _canton,
                decoration: InputDecoration(
                  labelText: l10n.mintNextDomicileCantonLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final code in sortedCantonCodes)
                    DropdownMenuItem(
                      value: code,
                      child: Text('${cantonFullNames[code]} ($code)'),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _canton = value;
                  _validationError = false;
                }),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'input:domicile.commune',
              child: TextField(
                controller: _communeController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.mintNextDomicileCommuneLabel,
                  hintText: l10n.mintNextDomicileCommuneHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _validationError = false),
              ),
            ),
            if (_validationError) ...[
              const SizedBox(height: MintSpacing.sm),
              Semantics(
                identifier: 'status:domicile.validation_error',
                liveRegion: true,
                child: Text(l10n.mintNextDomicileErrorMissing,
                    style: MintTextStyles.bodySmall(color: MintColors.error)),
              ),
            ],
            const SizedBox(height: MintSpacing.xl),
            Semantics(
              identifier: 'action:domicile.continue',
              button: true,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_canton == null ||
                            _communeController.text.trim().isEmpty) {
                          setState(() => _validationError = true);
                          return;
                        }
                        setState(() => _step = _Step.review);
                      },
                child: Text(l10n.mintNextDomicileContinue),
              ),
            ),
          ],
        ),
      );

  Widget _review(S l10n) {
    final commune = _communeController.text.trim();
    return Semantics(
      identifier: 'node:domicile.review',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextDomicileReviewTitle,
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
                Text('$commune (${_canton ?? ''})',
                    style: MintTextStyles.headlineSmall(
                        color: MintColors.textPrimary)),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextDomicileReviewSource(
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
            identifier: 'action:domicile.confirm',
            button: true,
            child: FilledButton(
              onPressed: _busy ? null : _confirmSave,
              child: Text(l10n.mintNextDomicileConfirm),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:domicile.back_to_collect',
            button: true,
            child: TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _step = _Step.collect),
              child: Text(l10n.mintNextDomicileBack),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saved(S l10n) {
    final fact = context.watch<CoachProfileProvider>().domicileFact;
    if (fact == null) {
      return _collect(l10n);
    }
    return Semantics(
      identifier: 'node:domicile.saved',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.mintNextDomicileSavedTitle,
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
                  identifier: 'fact:domicile.summary',
                  child: Text('${fact.communeName} (${fact.canton})',
                      style: MintTextStyles.headlineSmall(
                          color: MintColors.textPrimary)),
                ),
                const SizedBox(height: MintSpacing.sm),
                Text(
                  l10n.mintNextDomicileReviewSource(
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
            identifier: 'action:domicile.edit',
            button: true,
            child: FilledButton.tonal(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _canton = fact.canton;
                        _communeController.text = fact.communeName;
                        _step = _Step.collect;
                      }),
              child: Text(l10n.mintNextDomicileEdit),
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            identifier: 'action:domicile.delete',
            button: true,
            child: TextButton(
              onPressed: _busy ? null : _delete,
              child: Text(l10n.mintNextDomicileDelete),
            ),
          ),
        ],
      ),
    );
  }
}
