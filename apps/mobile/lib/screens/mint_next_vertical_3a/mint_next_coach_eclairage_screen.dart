// Lego C1 — « Éclairer ma marge 3a » : la seule surface coach de la
// préversion (beats c1/c2/c3/c7/c8).
//
// Contrat : product/mint_next/storyboard/coach_twin_read_3a.storyboard.json.
// L'écran n'affiche JAMAIS un chiffre qu'il aurait produit : il rend le
// texte validé par le serveur, ou un état honnête. Sans attestation
// disponible, aucun appel n'est possible — chaque état non-attesté est
// distinct (absent / invalide / lecture en échec / non chargé).

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/twin_read_api_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/financial_core/mint_next_marge_3a_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Ce que l'écran a le droit de rendre — jamais un chiffre local.
enum EclairageStage {
  /// Prêt : attestation disponible, question possible.
  ready,

  /// Attestation absente ou non calculable (marge indisponible).
  unattested,

  /// Lecture du jumeau en échec — DISTINCT d'un jumeau vide.
  readFailure,

  /// Chargement en cours.
  loading,
}

class MintNextCoachEclairageScreen extends StatefulWidget {
  const MintNextCoachEclairageScreen({
    super.key,
    this.attestationOverride,
  });

  /// Seam de test : attestation injectée (le calcul reste canonique en
  /// production, cf. le vertical).
  final Map<String, dynamic>? attestationOverride;

  @override
  State<MintNextCoachEclairageScreen> createState() =>
      _MintNextCoachEclairageScreenState();
}

class _MintNextCoachEclairageScreenState
    extends State<MintNextCoachEclairageScreen> {
  final TextEditingController _question = TextEditingController();
  TwinReadOutcome? _outcome;
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  /// L'attestation vient EXCLUSIVEMENT du calculateur canonique — même
  /// chemin que le vertical, aucun calcul propre à cet écran.
  Map<String, dynamic>? _attestationFor(CoachProfileProvider provider) {
    if (widget.attestationOverride != null) {
      return widget.attestationOverride;
    }
    final taxYear = DateTime.now().toUtc().year;
    final revenu =
        MintNext3aRevenuContext.fromConfirmedFact(provider.revenuFact);
    final lpp = MintNext3aLppAffiliationContext.fromConfirmedFact(
        provider.lppAffiliationFact);
    final versements = MintNext3aVersementsContext.fromConfirmedFact(
        provider.versements3aFact, taxYear);
    final fiscal = MintNext3aFiscalContext(
      taxYear: taxYear,
      effectiveAt: DateTime.now().toUtc(),
      domicile: null,
      civilStatus: null,
      revenu: revenu,
      lppAffiliation: lpp,
      versements: versements,
    );
    final result = MintNextMarge3aCalculator.compute(
      taxYear: taxYear,
      plafondDetermination: fiscal.plafond3aDetermination,
      annualNetCents: revenu?.annualNetCents,
      revenuRevision: revenu?.revision,
      totalVerseCents: versements?.totalVerseAnnualCents,
      versementsBucketRevision: versements?.bucketRevision,
      lppRevision: lpp?.revision,
    );
    final freshest = [
      provider.lppAffiliationFact?.assertedAt,
      provider.revenuFact?.assertedAt,
      provider.versements3aFact?.assertedAt,
    ].whereType<DateTime>().fold<DateTime?>(
        null, (max, d) => max == null || d.isAfter(max) ? d : max);
    if (freshest == null) return null;
    // Les révisions des faits d'entrée SONT l'empreinte des entrées :
    // toute correction change la clé d'opération et rouvre la surface.
    final inputsMaterial = (result.inputRevisions.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}=${e.value}')
        .join('|');
    return TwinReadApiService.attestationFrom(
      result,
      inputsHash: sha256
          .convert(utf8.encode(inputsMaterial))
          .toString(),
      computedAt: freshest.toUtc().toIso8601String(),
    );
  }

  EclairageStage _stageFor(
      CoachProfileProvider provider, Map<String, dynamic>? attestation) {
    if (!provider.isLoaded) return EclairageStage.loading;
    if (provider.loadFailed) return EclairageStage.readFailure;
    if (attestation == null) return EclairageStage.unattested;
    return EclairageStage.ready;
  }

  Future<void> _ask(Map<String, dynamic> attestation) async {
    final l = S.of(context)!;
    setState(() => _busy = true);
    try {
      // Consentement DÉDIÉ : demandé ici, accordé localement — sans lui,
      // aucun octet ne part (le service refuse en amont de tout HTTP).
      final consent = ConsentService();
      final hasReceipt =
          await consent.activeReceiptFor(ConsentPurpose.twinRead3aMargin) !=
              null;
      if (!mounted) return;
      if (!hasReceipt) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.consentPurposeTwinRead3aMargin),
            content: Text(l.consentPurposeTwinRead3aMarginWhy),
            actions: [
              TextButton(
                // lint-ignore: prefer_mint_cta
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l.consentCancel),
              ),
              FilledButton(
                // lint-ignore: prefer_mint_cta
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l.mintNextCoachEclairageConsentAccept),
              ),
            ],
          ),
        );
        if (accepted != true) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _outcome = const TwinReadOutcome(
                kind: TwinReadOutcomeKind.consentMissing);
          });
          return;
        }
        await consent.grantLocal(ConsentPurpose.twinRead3aMargin);
      }

      final sessionId = await AnonymousSessionService.getOrCreateSessionId();
      final outcome = await TwinReadApiService.requestEclairage(
        question: _question.text.trim(),
        attestation: attestation,
        sessionId: sessionId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome = outcome;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _outcome =
            const TwinReadOutcome(kind: TwinReadOutcomeKind.ambiguous);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final attestation = _attestationFor(provider);
    final stage = _stageFor(provider, attestation);

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      appBar: AppBar(
        backgroundColor: MintColors.warmWhite,
        elevation: 0,
        leading: Semantics(
          identifier: 'action:coach_eclairage.close',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close, color: MintColors.textPrimary),
            onPressed: () => context.go('/mint-next/vertical-3a'),
          ),
        ),
        title: Text(l.mintNextCoachEclairageTitle,
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: switch (stage) {
            EclairageStage.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.all(MintSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
            EclairageStage.readFailure => _HonestState(
                identifier: 'mint_next_coach_eclairage_state_readFailure',
                body: l.mintNextCoachEclairageReadFailure,
                ctaLabel: l.mintNextCoachEclairageGoToSituation,
                onCta: () => context.go('/mon-argent'),
              ),
            EclairageStage.unattested => _HonestState(
                identifier: 'mint_next_coach_eclairage_state_unattested',
                body: l.mintNextCoachEclairageUnattested,
                ctaLabel: l.mintNextCoachEclairageGoToSituation,
                onCta: () => context.go('/mon-argent'),
              ),
            EclairageStage.ready => _ReadyView(
                l: l,
                controller: _question,
                busy: _busy,
                outcome: _outcome,
                attestation: attestation!,
                onAsk: () => _ask(attestation),
              ),
          },
        ),
      ),
    );
  }
}

class _HonestState extends StatelessWidget {
  const _HonestState({
    required this.identifier,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  final String identifier;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body,
              style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
          const SizedBox(height: MintSpacing.lg),
          Semantics(
            identifier: 'action:coach_eclairage.go_to_situation',
            button: true,
            child: FilledButton(
              // lint-ignore: prefer_mint_cta
              onPressed: onCta,
              child: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({
    required this.l,
    required this.controller,
    required this.busy,
    required this.outcome,
    required this.attestation,
    required this.onAsk,
  });

  final S l;
  final TextEditingController controller;
  final bool busy;
  final TwinReadOutcome? outcome;
  final Map<String, dynamic> attestation;
  final VoidCallback onAsk;

  String? _messageFor(TwinReadOutcomeKind kind) {
    switch (kind) {
      case TwinReadOutcomeKind.answered:
        return null;
      case TwinReadOutcomeKind.refused:
        return l.mintNextCoachEclairageRefused;
      case TwinReadOutcomeKind.ambiguous:
        return l.mintNextCoachEclairageAmbiguous;
      case TwinReadOutcomeKind.quotaExhausted:
        return l.mintNextCoachEclairageQuotaExhausted;
      case TwinReadOutcomeKind.consentMissing:
        return l.mintNextCoachEclairageConsentMissing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final answered = outcome?.kind == TwinReadOutcomeKind.answered;
    return Semantics(
      identifier: 'mint_next_coach_eclairage_state_ready',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mintNextCoachEclairageIntro,
              style:
                  MintTextStyles.bodySmall(color: MintColors.textSecondary)),
          const SizedBox(height: MintSpacing.md),
          if (!answered) ...[
            Semantics(
              identifier: 'input:coach_eclairage.question',
              textField: true,
              child: TextField(
                key: const Key('coach_eclairage_question'),
                controller: controller,
                maxLength: 280,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l.mintNextCoachEclairageHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier: 'action:coach_eclairage.ask',
              button: true,
              child: FilledButton(
                // lint-ignore: prefer_mint_cta
                onPressed: busy ? null : onAsk,
                child: Text(l.mintNextCoachEclairageAsk),
              ),
            ),
          ],
          if (answered) ...[
            Semantics(
              identifier: 'mint_next_coach_eclairage_answer',
              container: true,
              explicitChildNodes: true,
              child: Container(
                padding: const EdgeInsets.all(MintSpacing.md),
                decoration: BoxDecoration(
                  color: MintColors.porcelaine,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.border, width: 0.5),
                ),
                child: Text(outcome!.answer!,
                    style: MintTextStyles.bodyLarge(
                        color: MintColors.textPrimary)),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            // Source + année + fraîcheur : l'éclairage dit toujours d'où
            // il parle et de quand date le calcul.
            Text(
              l.mintNextCoachEclairageSource(
                '${attestation['taxYear']}',
                (attestation['computedAt'] as String).substring(0, 10),
              ),
              key: const Key('coach_eclairage_source'),
              style:
                  MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(l.mintNextCoachEclairageLimit,
                key: const Key('coach_eclairage_limit'),
                style:
                    MintTextStyles.bodySmall(color: MintColors.textSecondary)),
            const SizedBox(height: MintSpacing.lg),
            Semantics(
              identifier: 'action:coach_eclairage.go_to_situation',
              button: true,
              child: FilledButton(
                // lint-ignore: prefer_mint_cta
                onPressed: () => context.go('/mon-argent'),
                child: Text(l.mintNextCoachEclairageGoToSituation),
              ),
            ),
          ],
          if (outcome != null && !answered) ...[
            const SizedBox(height: MintSpacing.md),
            Semantics(
              identifier:
                  'mint_next_coach_eclairage_outcome_${outcome!.kind.name}',
              container: true,
              explicitChildNodes: true,
              child: Text(_messageFor(outcome!.kind)!,
                  key: const Key('coach_eclairage_outcome_message'),
                  style: MintTextStyles.bodyLarge(
                      color: MintColors.textPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}
