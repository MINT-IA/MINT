import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/mint_next_revenu/mint_next_revenu_screen.dart'
    show mintNextRevenuChf;
import 'package:mint_mobile/services/financial_core/mint_next_marge_3a_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Lego 7 — le vrai vertical 3a.
///
/// Contrat : `product/mint_next/storyboard/vertical_3a.storyboard.json`.
/// SURFACE de lecture pure : consomme exclusivement le calculateur canonique
/// (guard commit-gate — aucune formule locale, aucun writer, jamais le
/// laboratoire visuel). Trois classes d'états : fait éditable → écran canonique ;
/// stale → recalcul au build ; année/constantes → état factuel non éditable.
/// Design : langage éditorial du handoff (eyebrow + Fraunces + papier chaud).
class MintNextVertical3aScreen extends StatelessWidget {
  const MintNextVertical3aScreen({super.key, this.now});

  final DateTime Function()? now;

  DateTime _now() => (now ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final taxYear = _now().year;

    // Chargement ≠ fait manquant (contrat) : tant que le provider n'a pas
    // rechargé les faits scellés, aucun état métier n'est affirmé.
    if (!provider.isLoaded) {
      return Scaffold(
        backgroundColor: MintColors.warmWhite,
        body: Semantics(
          identifier: 'node:vertical_3a.loading',
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final revenu =
        MintNext3aRevenuContext.fromConfirmedFact(provider.revenuFact);
    final lpp = MintNext3aLppAffiliationContext.fromConfirmedFact(
        provider.lppAffiliationFact);
    final versements = MintNext3aVersementsContext.fromConfirmedFact(
        provider.versements3aFact, taxYear);
    final fiscal = MintNext3aFiscalContext(
      taxYear: taxYear,
      effectiveAt: _now().toUtc(),
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

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      appBar: AppBar(
        backgroundColor: MintColors.warmWhite,
        elevation: 0,
        leading: Semantics(
          identifier: 'action:vertical_3a.close',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.close, color: MintColors.textPrimary),
            onPressed: () => context.go('/home'),
          ),
        ),
        title: Text(l10n.mintNextVertical3aTitle,
            style: MintTextStyles.titleLarge(color: MintColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: result.status == MintNextMarge3aStatus.available
              ? _AvailableView(
                  result: result, taxYear: taxYear, l10n: l10n)
              : _StateView(result: result, taxYear: taxYear, l10n: l10n),
        ),
      ),
    );
  }
}

/// Résultat attesté — carte éditoriale du handoff : eyebrow, chiffre en
/// Fraunces, barre de proportion versé/plafond, provenance en pied.
class _AvailableView extends StatelessWidget {
  const _AvailableView({
    required this.result,
    required this.taxYear,
    required this.l10n,
  });

  final MintNextMarge3aResult result;
  final int taxYear;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final marge = result.margeCents!;
    final plafond = result.plafondCents!;
    final verse = result.totalVerseCents!;
    final ratio = plafond > 0 ? (verse / plafond).clamp(0.0, 1.0) : 0.0;
    final headline = marge >= 0
        ? l10n.mintNextVertical3aHeadlineRoom(mintNextRevenuChf(marge))
        : l10n.mintNextVertical3aHeadlineOver(mintNextRevenuChf(-marge));

    return Semantics(
      identifier: 'mint_next_vertical_3a_marge_$marge',
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md, vertical: MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.porcelaine,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mintNextVertical3aEyebrow('$taxYear').toUpperCase(),
              style: MintTextStyles.labelMedium(
                      color: MintColors.textSecondary)
                  .copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(headline,
                style:
                    MintTextStyles.editorialLarge(color: MintColors.textPrimary)),
            const SizedBox(height: MintSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: MintColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(marge >= 0
                    ? MintColors.sauge
                    : MintColors.pecheDouce),
              ),
            ),
            const SizedBox(height: MintSpacing.md),
            _row(l10n.mintNextVertical3aVerseRow('$taxYear'),
                mintNextRevenuChf(verse)),
            _row(l10n.mintNextVertical3aPlafondRow('$taxYear'),
                mintNextRevenuChf(plafond)),
            const SizedBox(height: MintSpacing.md),
            Text(
              l10n.mintNextVertical3aProvenance('$taxYear',
                  result.constantsVersionHash!.substring(0, 8)),
              key: const Key('vertical_3a_provenance'),
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: MintSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
            Text(value,
                style:
                    MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
          ],
        ),
      );
}

/// États fail-closed — trois classes, jamais confondues (contrat) :
/// fait éditable → écran canonique ; stale → recalcul (déjà fait au build) ;
/// année/constantes → état factuel NON éditable, sans faux CTA.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.result,
    required this.taxYear,
    required this.l10n,
  });

  final MintNextMarge3aResult result;
  final int taxYear;
  final S l10n;

  @override
  Widget build(BuildContext context) {
    final String invitation;
    final String? ctaLabel;
    final String? ctaRoute;
    switch (result.status) {
      case MintNextMarge3aStatus.lppAffiliationUnknown:
        invitation = l10n.mintNextVertical3aStateLppUnknown;
        ctaLabel = l10n.mintNextVertical3aCtaLpp;
        ctaRoute = '/mint-next/lpp-affiliation';
      case MintNextMarge3aStatus.incomeMissing:
        invitation = l10n.mintNextVertical3aStateIncomeMissing;
        ctaLabel = l10n.mintNextVertical3aCtaRevenu;
        ctaRoute = '/mint-next/revenu';
      case MintNextMarge3aStatus.contributionsMissing:
        invitation = l10n.mintNextVertical3aStateContributionsMissing;
        ctaLabel = l10n.mintNextVertical3aCtaVersements;
        ctaRoute = '/mint-next/versements-3a';
      case MintNextMarge3aStatus.unsupportedTaxYear:
      case MintNextMarge3aStatus.regulatoryConstantsUnattested:
        invitation = l10n.mintNextVertical3aStateUnattested('$taxYear');
        ctaLabel = null;
        ctaRoute = null;
      case MintNextMarge3aStatus.staleInputs:
        invitation = l10n.mintNextVertical3aStateUnattested('$taxYear');
        ctaLabel = null;
        ctaRoute = null;
      case MintNextMarge3aStatus.available:
        throw StateError('available is rendered by _AvailableView');
    }

    return Semantics(
      identifier: 'mint_next_vertical_3a_state_${result.status.name}',
      container: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md, vertical: MintSpacing.lg),
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.mintNextVertical3aEyebrow('$taxYear').toUpperCase(),
              style: MintTextStyles.labelMedium(
                      color: MintColors.textSecondary)
                  .copyWith(letterSpacing: 1.2),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(invitation,
                style: MintTextStyles.editorialLarge(
                    color: MintColors.textPrimary)),
            if (ctaLabel != null && ctaRoute != null) ...[
              const SizedBox(height: MintSpacing.lg),
              Semantics(
                identifier: 'action:vertical_3a.fix_fact',
                button: true,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.textPrimary,
                    foregroundColor: MintColors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go(ctaRoute!),
                  child: Text(ctaLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
