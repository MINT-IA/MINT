import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/services/financial_core/wealth_financial_facts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:provider/provider.dart';

/// Swiss CHF formatter with apostrophe grouping.
String _formatChfSwiss(double value) {
  final intVal = value.round();
  final isNeg = intVal < 0;
  final str = intVal.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write("'");
    }
    buffer.write(str[i]);
  }
  return '${isNeg ? '-' : ''}${buffer.toString()}';
}

/// Swiss CHF formatter with prefix.
String _chfFmt(double value) {
  return 'CHF\u00A0${_formatChfSwiss(value)}';
}

/// Screen for simulating the tax and succession impact of a donation in Switzerland.
///
/// Covers cantonal donation tax, reserve hereditaire (2023), quotite disponible,
/// and impact on future succession.
/// Sprint S24 — Life Event: donation.
class DonationScreen extends StatefulWidget {
  const DonationScreen({super.key});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final _scrollController = ScrollController();
  final _resultsKey = GlobalKey();

  // ── Input state ──
  double _montant = 100000;
  String _lienParente = 'descendant';
  String _typeDonation = 'especes';
  bool _avancementHoirie = true;

  // Result
  DonationResult? _result;

  // Checklist state
  List<bool> _checklistState = [];

  static const _typesDonation = ['especes', 'immobilier', 'titres'];

  static const _liensParente = [
    'conjoint',
    'descendant',
    'parent',
    'fratrie',
    'concubin',
    'tiers',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _runDonationScenario(_DonationLedgerFacts facts) {
    if (!facts.canSimulate(_typeDonation)) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = DonationService.calculate(
        montant: _montant,
        donateurAge: facts.age!,
        lienParente: _lienParente,
        canton: facts.canton!,
        civilStatus: facts.civilStatus!.name,
        typeDonation: _typeDonation,
        valeurImmobiliere:
            _typeDonation == 'immobilier' ? facts.propertyMarketValue! : 0,
        soldeHypothecaire:
            _typeDonation == 'immobilier' ? facts.mortgageBalance! : 0,
        avancementHoirie: _avancementHoirie,
        nbEnfants: facts.children!,
        fortuneTotaleDonateur: facts.wealthReference!,
      );
      _checklistState = List.filled(_result!.checklist.length, false);
    });

    // Smooth scroll to results
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final facts = _DonationLedgerFacts.fromProfile(
      context.watch<CoachProfileProvider>().profile,
    );
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(S.of(context)!.donationAppBarTitle),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintEntrance(child: _buildHeader()),
            const SizedBox(height: 24),
            MintEntrance(
              delay: const Duration(milliseconds: 100),
              child: _buildIntroCard(),
            ),
            const SizedBox(height: 24),
            MintEntrance(
              delay: const Duration(milliseconds: 150),
              child: _buildSuccessionContextSection(facts),
            ),
            const SizedBox(height: 12),
            MintEntrance(
              delay: const Duration(milliseconds: 200),
              child: _buildDonationSection(facts),
            ),
            const SizedBox(height: 24),
            _buildSimulateButton(facts),
            const SizedBox(height: 24),
            if (_result != null)
              Column(
                key: const Key('donation_result_cards'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(key: _resultsKey),
                  MintEntrance(child: _buildTaxCard(facts)),
                  const SizedBox(height: 24),
                  MintEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: _buildReserveCard(facts),
                  ),
                  const SizedBox(height: 24),
                  MintEntrance(
                    delay: const Duration(milliseconds: 200),
                    child: _buildQuotiteCard(),
                  ),
                  const SizedBox(height: 24),
                  MintEntrance(
                    delay: const Duration(milliseconds: 300),
                    child: _buildImpactSuccessionCard(),
                  ),
                  const SizedBox(height: 24),
                  if (_result!.alerts.isNotEmpty) ...[
                    MintEntrance(
                      delay: const Duration(milliseconds: 350),
                      child: _buildAlertsSection(facts),
                    ),
                    const SizedBox(height: 24),
                  ],
                  MintEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: _buildChecklistSection(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            _buildEducationalFooter(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_giftcard,
                color: MintColors.indigo, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.donationHeaderTitle,
                  style: MintTextStyles.headlineMedium(),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context)!.donationHeaderSubtitle,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Intro Card ──
  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.indigo.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 20, color: MintColors.indigo.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.donationIntroText,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section: Donation ──
  Widget _buildDonationSection(_DonationLedgerFacts facts) {
    return SimulatorCard(
      title: S.of(context)!.donationSectionTitle,
      subtitle: S.of(context)!.donationSectionSubtitle,
      icon: Icons.card_giftcard,
      accentColor: MintColors.indigo,
      child: Column(
        children: [
          MintAmountField(
            label: S.of(context)!.donationMontantLabel,
            value: _montant,
            formatValue: (v) => _chfFmt(v),
            onChanged: (v) => setState(() => _montant = v),
            min: 10000,
            max: 2000000,
          ),
          const SizedBox(height: 16),
          _buildLienParenteChips(),
          const SizedBox(height: 16),
          _buildTypeDonationChips(),
          if (_typeDonation == 'immobilier') ...[
            const SizedBox(height: 16),
            _buildFactTile(
              key: const Key('donation_property_fact'),
              semanticsIdentifier: 'donation_property_fact',
              label: S.of(context)!.donationValeurImmobiliere,
              value: facts.propertyMarketValue == null
                  ? null
                  : _chfFmt(facts.propertyMarketValue!),
              route: '/data-block/patrimoine?inputKey=q_property_market_value',
              ctaKey: const Key('donation_property_missing_cta'),
              ctaSemanticsIdentifier: 'donation_property_missing_cta',
              ctaLabel: S.of(context)!.dataBlockPatrimoineCta,
            ),
            const SizedBox(height: 16),
            _buildFactTile(
              key: const Key('donation_mortgage_fact'),
              semanticsIdentifier: 'donation_mortgage_fact',
              label: S.of(context)!.financialSummaryHypothequeRestante,
              value: facts.mortgageBalance == null
                  ? null
                  : _chfFmt(facts.mortgageBalance!),
              route: '/data-block/patrimoine?inputKey=_coach_dettes_hypotheque',
              ctaKey: const Key('donation_mortgage_missing_cta'),
              ctaSemanticsIdentifier: 'donation_mortgage_missing_cta',
              ctaLabel: S.of(context)!.dataBlockPatrimoineCta,
            ),
          ],
          const SizedBox(height: 16),
          _buildSwitch(
            label: S.of(context)!.donationAvancementHoirie,
            value: _avancementHoirie,
            onChanged: (v) => setState(() {
              _avancementHoirie = v;
              _result = null;
            }),
          ),
        ],
      ),
    );
  }

  // ── Section: Succession Context ──
  Widget _buildSuccessionContextSection(_DonationLedgerFacts facts) {
    return SimulatorCard(
      key: const Key('donation_ledger_facts'),
      title: S.of(context)!.donationContexteSuccessoral,
      subtitle: S.of(context)!.independantLedgerFactsSubtitle,
      icon: Icons.family_restroom,
      accentColor: MintColors.indigo,
      child: Column(
        children: [
          _buildFactTile(
            key: const Key('donation_age_fact'),
            semanticsIdentifier: 'donation_age_fact',
            label: S.of(context)!.donationAgeLabel,
            value: facts.age == null ? null : '${facts.age} ans',
            route: '/data-block/revenu?inputKey=q_birth_year',
            ctaKey: const Key('donation_age_missing_cta'),
            ctaSemanticsIdentifier: 'donation_age_missing_cta',
            ctaLabel: S.of(context)!.dataBlockRevenuCta,
          ),
          const SizedBox(height: 16),
          _buildFactTile(
            key: const Key('donation_canton_fact'),
            semanticsIdentifier: 'donation_canton_fact',
            label: S.of(context)!.donationCanton,
            value: facts.canton,
            route: '/data-block/revenu?inputKey=q_canton',
            ctaKey: const Key('donation_canton_missing_cta'),
            ctaSemanticsIdentifier: 'donation_canton_missing_cta',
            ctaLabel: S.of(context)!.dataBlockRevenuCta,
          ),
          const SizedBox(height: 16),
          _buildFactTile(
            key: const Key('donation_civil_status_fact'),
            semanticsIdentifier: 'donation_civil_status_fact',
            label: S.of(context)!.dataBlockMenageCivilStatus,
            value: _civilStatusLabel(facts.civilStatus),
            route: '/data-block/composition_menage?inputKey=q_civil_status',
            ctaKey: const Key('donation_civil_status_missing_cta'),
            ctaSemanticsIdentifier: 'donation_civil_status_missing_cta',
            ctaLabel: S.of(context)!.dataBlockMenageCta,
          ),
          const SizedBox(height: 16),
          _buildFactTile(
            key: const Key('donation_children_fact'),
            semanticsIdentifier: 'donation_children_fact',
            label: S.of(context)!.donationNbEnfants,
            value: facts.children?.toString(),
            route: '/data-block/composition_menage?inputKey=q_children',
            ctaKey: const Key('donation_children_missing_cta'),
            ctaSemanticsIdentifier: 'donation_children_missing_cta',
            ctaLabel: S.of(context)!.dataBlockMenageCta,
          ),
          const SizedBox(height: 16),
          _buildFactTile(
            key: const Key('donation_wealth_fact'),
            semanticsIdentifier: 'donation_wealth_fact',
            label: S.of(context)!.donationEstateBaseLabel,
            value: facts.wealthReference == null
                ? null
                : _chfFmt(facts.wealthReference!),
            needsAttention:
                facts.estateMortgageMissing || facts.estateNeedsReconciliation,
            supportingText: _wealthReferenceSupportText(facts),
            route: '/data-block/patrimoine?inputKey=q_wealth_estimate',
            ctaKey: const Key('donation_wealth_missing_cta'),
            ctaSemanticsIdentifier: 'donation_wealth_missing_cta',
            ctaLabel: S.of(context)!.dataBlockPatrimoineCta,
            secondaryRoute: facts.estateMortgageMissing
                ? '/data-block/patrimoine?inputKey=_coach_dettes_hypotheque'
                : null,
            secondaryCtaKey: const Key('donation_estate_mortgage_cta'),
            secondaryCtaSemanticsIdentifier: 'donation_estate_mortgage_cta',
            secondaryCtaLabel: S.of(context)!.donationEstateMortgageCta,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFactTile({
    required Key key,
    required String semanticsIdentifier,
    required String label,
    required String? value,
    required String route,
    required Key ctaKey,
    required String ctaSemanticsIdentifier,
    required String ctaLabel,
    bool needsAttention = false,
    String? supportingText,
    String? secondaryRoute,
    Key? secondaryCtaKey,
    String? secondaryCtaSemanticsIdentifier,
    String? secondaryCtaLabel,
  }) {
    final isKnown = value != null && value.isNotEmpty;
    final attention = isKnown && needsAttention;
    final hasSecondaryAction = isKnown &&
        secondaryRoute != null &&
        secondaryCtaKey != null &&
        secondaryCtaSemanticsIdentifier != null &&
        secondaryCtaLabel != null;
    return Semantics(
      key: key,
      identifier: semanticsIdentifier,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MintColors.border),
        ),
        child: Row(
          children: [
            Icon(
              attention
                  ? Icons.warning_amber_rounded
                  : isKnown
                      ? Icons.check_circle_outline
                      : Icons.add_circle_outline,
              color: attention
                  ? MintColors.warning
                  : isKnown
                      ? MintColors.success
                      : MintColors.warning,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isKnown ? value : S.of(context)!.dataBlockStatusMissing,
                    style: MintTextStyles.bodyMedium(
                      color: attention
                          ? MintColors.warning
                          : isKnown
                              ? MintColors.textPrimary
                              : MintColors.warning,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (supportingText != null && supportingText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      supportingText,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isKnown)
              Semantics(
                identifier: ctaSemanticsIdentifier,
                button: true,
                child: TextButton(
                  key: ctaKey,
                  onPressed: () => context.push(route),
                  child: Text(ctaLabel),
                ),
              )
            else if (hasSecondaryAction)
              Semantics(
                identifier: secondaryCtaSemanticsIdentifier,
                button: true,
                child: TextButton(
                  key: secondaryCtaKey,
                  onPressed: () => context.push(secondaryRoute),
                  child: Text(secondaryCtaLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _wealthReferenceSupportText(_DonationLedgerFacts facts) {
    if (facts.wealthReference == null) return null;
    final l = S.of(context)!;
    if (facts.estateMortgageMissing) {
      return l.donationEstateMortgageMissingHint;
    }
    if (facts.estateNeedsReconciliation) {
      return l.donationEstateReconcileHint;
    }
    if (facts.estateUsesDetailedFacts) {
      return l.donationEstateBaseDerivedHint;
    }
    return null;
  }

  String? _civilStatusLabel(CoachCivilStatus? status) {
    final l = S.of(context)!;
    return switch (status) {
      CoachCivilStatus.celibataire => l.dataBlockMenageCivilSingle,
      CoachCivilStatus.marie => l.dataBlockMenageCivilMarried,
      CoachCivilStatus.divorce => l.dataBlockMenageCivilDivorced,
      CoachCivilStatus.veuf => l.dataBlockMenageCivilWidowed,
      CoachCivilStatus.concubinage => l.dataBlockMenageCivilCohabiting,
      null => null,
    };
  }

  String _typeDonationLabel(String type) {
    final l = S.of(context)!;
    return switch (type) {
      'immobilier' => l.donationTypeImmobilier,
      'titres' => l.donationTypeTitres,
      _ => l.donationTypeEspeces,
    };
  }

  // ── Lien de Parente Chips ──
  Widget _buildLienParenteChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationLienParente,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: _liensParente.map((lien) {
            final selected = _lienParente == lien;
            return Semantics(
              label: DonationService.lienParenteLabels[lien] ?? lien,
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => setState(() => _lienParente = lien),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? MintColors.indigo.withValues(alpha: 0.1)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? MintColors.indigo : MintColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    DonationService.lienParenteLabels[lien] ?? lien,
                    style: MintTextStyles.labelSmall(
                      color: selected
                          ? MintColors.indigo
                          : MintColors.textSecondary,
                    ).copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Type Donation Chips ──
  Widget _buildTypeDonationChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.donationTypeDonation,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
        const SizedBox(height: MintSpacing.sm),
        Wrap(
          spacing: MintSpacing.sm,
          runSpacing: MintSpacing.sm,
          children: _typesDonation.map((type) {
            final selected = _typeDonation == type;
            final label = _typeDonationLabel(type);
            return Semantics(
              label: label,
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => setState(() {
                  _typeDonation = type;
                  _result = null;
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? MintColors.indigo.withValues(alpha: 0.1)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? MintColors.indigo : MintColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: MintTextStyles.labelSmall(
                      color: selected
                          ? MintColors.indigo
                          : MintColors.textSecondary,
                    ).copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Simulate Button ──
  Widget _buildSimulateButton(_DonationLedgerFacts facts) {
    return Semantics(
      label: S.of(context)!.donationCalculer,
      button: true,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('donation_simulate_cta'),
          onPressed: !facts.canSimulate(_typeDonation)
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  _runDonationScenario(facts);
                },
          icon: const Icon(Icons.calculate_outlined, size: 20),
          label: Text(
            S.of(context)!.donationCalculer,
            style: MintTextStyles.titleMedium(color: MintColors.white),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tax Card ──
  Widget _buildTaxCard(_DonationLedgerFacts facts) {
    final r = _result!;
    final needsConfirmation = r.taxRequiresCantonalConfirmation;
    final accentColor =
        needsConfirmation ? MintColors.warning : MintColors.success;
    return MintResultHeroCard(
      eyebrow: S.of(context)!.donationImpotTitle,
      primaryValue: needsConfirmation
          ? S.of(context)!.agentFormEstimated
          : S.of(context)!.donationExoneree,
      primaryLabel: _taxStatusText(r, facts),
      secondaryValue: needsConfirmation ? _chfFmt(r.montantDonation) : null,
      secondaryLabel:
          needsConfirmation ? S.of(context)!.donationMontantRow : null,
      narrative:
          '${S.of(context)!.donationLienRow}\u00A0:\u00A0${DonationService.lienParenteLabels[_lienParente] ?? _lienParente}',
      accentColor: accentColor,
      tone: MintSurfaceTone.porcelaine,
    );
  }

  String _taxStatusText(DonationResult r, _DonationLedgerFacts facts) {
    final l = S.of(context)!;
    final canton = facts.canton ?? '';
    switch (r.taxStatus) {
      case DonationMessageCode.taxUnknownCanton:
        return l.donationTaxStatusUnknownCanton;
      case DonationMessageCode.taxUsualExemption:
        return l.donationTaxStatusUsualExemption;
      case DonationMessageCode.taxDescendantConfirm:
        return l.donationTaxStatusDescendantConfirm(canton);
      case DonationMessageCode.taxCantonalConfirm:
        return l.donationTaxStatusConfirm(canton);
      default:
        return l.agentFormEstimated;
    }
  }

  String _impactSuccessionText(DonationResult r) {
    final l = S.of(context)!;
    switch (r.impactSuccession) {
      case DonationMessageCode.impactAdvancement:
        return l.donationImpactAdvancement;
      case DonationMessageCode.impactReductionRisk:
        return l.donationImpactReductionRisk(_chfFmt(r.montantDepassement));
      case DonationMessageCode.impactOutsidePart:
        return l.donationImpactOutsidePart(_chfFmt(r.quotiteDisponible));
      default:
        return l.donationHorsPartNote;
    }
  }

  String _alertText(
    String code,
    DonationResult r,
    _DonationLedgerFacts facts,
  ) {
    final l = S.of(context)!;
    final canton = facts.canton ?? '';
    switch (code) {
      case DonationMessageCode.alertUnknownCanton:
        return l.donationAlertUnknownCanton;
      case DonationMessageCode.alertTaxConfirm:
        return l.donationAlertTaxConfirm(canton);
      case DonationMessageCode.alertMissingParentela:
        return l.donationAlertMissingParentela;
      case DonationMessageCode.alertMatrimonialRegime:
        return l.donationAlertMatrimonialRegime;
      case DonationMessageCode.alertSpouseLargeGift:
        return l.donationAlertSpouseLargeGift;
      case DonationMessageCode.alertReductionRisk:
        return l.donationAlertReductionRisk(_chfFmt(r.montantDepassement));
      case DonationMessageCode.alertConcubinage:
        return l.donationAlertConcubinage;
      case DonationMessageCode.alertRealEstate:
        return l.donationAlertRealEstate;
      case DonationMessageCode.alertOlderDonor:
        return l.donationAlertOlderDonor;
      case DonationMessageCode.alertLargeDonation:
        return l.donationAlertLargeDonation;
      default:
        return l.lifeEventPointsAttention;
    }
  }

  String _checklistText(String code) {
    final l = S.of(context)!;
    switch (code) {
      case DonationMessageCode.checklistVerifyQuotite:
        return l.donationChecklistVerifyQuotite;
      case DonationMessageCode.checklistDocumentAdvancement:
        return l.donationChecklistDocumentAdvancement;
      case DonationMessageCode.checklistConfirmTax:
        return l.donationChecklistConfirmTax;
      case DonationMessageCode.checklistInformReservedHeirs:
        return l.donationChecklistInformReservedHeirs;
      case DonationMessageCode.checklistKeepDeed:
        return l.donationChecklistKeepDeed;
      case DonationMessageCode.checklistLandRegister:
        return l.donationChecklistLandRegister;
      case DonationMessageCode.checklistFutureCollation:
        return l.donationChecklistFutureCollation;
      case DonationMessageCode.checklistConcubinageQuestions:
        return l.donationChecklistConcubinageQuestions;
      default:
        return l.lifeEventChecklistSubtitle;
    }
  }

  String _disclaimerText(String? code) {
    if (code == DonationMessageCode.disclaimerStandard || code == null) {
      return S.of(context)!.donationDisclaimerFallback;
    }
    return S.of(context)!.donationDisclaimerFallback;
  }

  // ── Reserve Card ──
  Widget _buildReserveCard(_DonationLedgerFacts facts) {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.peche,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: MintColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationReserveTitle,
                style: MintTextStyles.micro(color: MintColors.warning).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.reserveHereditaireTotale),
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.agentFormEstimated,
            style: MintTextStyles.labelSmall(color: MintColors.warning),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.donationReserveProtege,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Visual bar: reserve vs quotite
          _buildReserveBar(r, facts),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.donationReserveNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Reserve Bar Visual ──
  Widget _buildReserveBar(DonationResult r, _DonationLedgerFacts facts) {
    final fortune = facts.wealthReference ?? r.montantDonation;
    final reservePct = fortune > 0
        ? (r.reserveHereditaireTotale / fortune).clamp(0.0, 1.0)
        : 0.0;
    final quotitePct = 1.0 - reservePct;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            if (reservePct > 0)
              Flexible(
                flex: (reservePct * 100).toInt().clamp(1, 99),
                child: Container(
                  color: MintColors.warning,
                  alignment: Alignment.center,
                  child: reservePct > 0.15
                      ? Text(
                          S.of(context)!.donationReserveBarLabel(
                                (reservePct * 100).toStringAsFixed(0),
                              ),
                          style: MintTextStyles.micro(color: MintColors.white)
                              .copyWith(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
              ),
            if (quotitePct > 0)
              Flexible(
                flex: (quotitePct * 100).toInt().clamp(1, 99),
                child: Container(
                  color: MintColors.success,
                  alignment: Alignment.center,
                  child: quotitePct > 0.15
                      ? Text(
                          S.of(context)!.donationDisponibleBarLabel(
                                (quotitePct * 100).toStringAsFixed(0),
                              ),
                          style: MintTextStyles.micro(color: MintColors.white)
                              .copyWith(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Quotite Disponible Card ──
  Widget _buildQuotiteCard() {
    final r = _result!;
    final requiresConfirmation = r.quotiteRequiresSpecialistConfirmation;
    final statusColor = r.donationDepasseQuotite
        ? MintColors.error
        : requiresConfirmation
            ? MintColors.warning
            : MintColors.success;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.donationDepasseQuotite
                    ? Icons.warning_amber_rounded
                    : requiresConfirmation
                        ? Icons.info_outline
                        : Icons.edit_note,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationQuotiteTitle,
                style: MintTextStyles.micro(
                  color: r.donationDepasseQuotite
                      ? MintColors.error
                      : requiresConfirmation
                          ? MintColors.warning
                          : MintColors.success,
                ).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _chfFmt(r.quotiteDisponible),
            style: MintTextStyles.headlineMedium(),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.agentFormEstimated,
            style: MintTextStyles.labelSmall(
              color: statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.donationQuotiteDesc,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          if (r.donationDepasseQuotite) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: MintColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S
                          .of(context)!
                          .donationDepassement(_chfFmt(r.montantDepassement)),
                      style: MintTextStyles.bodySmall(color: MintColors.error)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Impact Succession Card ──
  Widget _buildImpactSuccessionCard() {
    final r = _result!;
    return MintSurface(
      tone: MintSurfaceTone.bleu,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, color: MintColors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.donationImpactTitle,
                style: MintTextStyles.micro(color: MintColors.info).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _impactSuccessionText(r),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                .copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: MintColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _avancementHoirie
                        ? S.of(context)!.donationAvancementNote
                        : S.of(context)!.donationHorsPartNote,
                    style: MintTextStyles.labelSmall(color: MintColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts Section ──
  Widget _buildAlertsSection(_DonationLedgerFacts facts) {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventPointsAttention,
          style:
              MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...r.alerts.map((alert) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MintColors.warning.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 16, color: MintColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _alertText(alert, r, facts),
                        style: MintTextStyles.bodySmall(
                                color: MintColors.textSecondary)
                            .copyWith(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ── Checklist Section ──
  Widget _buildChecklistSection() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.lifeEventActionsTitle,
      subtitle: S.of(context)!.lifeEventChecklistSubtitle,
      icon: Icons.checklist,
      accentColor: MintColors.indigo,
      child: Column(
        children: List.generate(r.checklist.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label: _checklistText(r.checklist[index]),
              button: true,
              toggled: _checklistState[index],
              child: InkWell(
                onTap: () {
                  setState(() {
                    _checklistState[index] = !_checklistState[index];
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _checklistState[index]
                        ? MintColors.success.withValues(alpha: 0.06)
                        : MintColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _checklistState[index]
                          ? MintColors.success.withValues(alpha: 0.3)
                          : MintColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _checklistState[index]
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: _checklistState[index]
                            ? MintColors.success
                            : MintColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _checklistText(r.checklist[index]),
                          style: MintTextStyles.bodySmall(
                            color: _checklistState[index]
                                ? MintColors.textSecondary
                                : MintColors.textPrimary,
                          ).copyWith(
                            decoration: _checklistState[index]
                                ? TextDecoration.lineThrough
                                : null,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Educational Footer ──
  Widget _buildEducationalFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.lifeEventComprendre,
          style:
              MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          S.of(context)!.donationEduQuotiteTitle,
          S.of(context)!.donationEduQuotiteBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.donationEduAvancementTitle,
          S.of(context)!.donationEduAvancementBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.donationEduConcubinTitle,
          S.of(context)!.donationEduConcubinBody,
        ),
      ],
    );
  }

  // ── Expandable Tile ──
  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: MintColors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w500),
          ),
          children: [
            Text(
              content,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary)
                  .copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ──
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: MintColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _disclaimerText(_result?.disclaimer),
              style: MintTextStyles.micro(color: MintColors.deepOrange)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Switch ──
  Widget _buildSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }
}

class _DonationLedgerFacts {
  final int? age;
  final String? canton;
  final CoachCivilStatus? civilStatus;
  final int? children;
  final double? wealthReference;
  final double? propertyMarketValue;
  final double? mortgageBalance;
  final bool estateUsesDetailedFacts;
  final bool estateNeedsReconciliation;
  final bool estateMortgageMissing;

  const _DonationLedgerFacts({
    required this.age,
    required this.canton,
    required this.civilStatus,
    required this.children,
    required this.wealthReference,
    required this.propertyMarketValue,
    required this.mortgageBalance,
    required this.estateUsesDetailedFacts,
    required this.estateNeedsReconciliation,
    required this.estateMortgageMissing,
  });

  factory _DonationLedgerFacts.fromProfile(CoachProfile? profile) {
    if (profile == null) return const _DonationLedgerFacts.empty();
    final provided = profile.userProvidedFields;
    final age = provided.contains('age') ? profile.ageOrNull : null;
    final canton = provided.contains('canton') && profile.canton.isNotEmpty
        ? profile.canton
        : null;
    final civilStatus =
        provided.contains('civilStatus') ? profile.etatCivil : null;
    final children =
        provided.contains('children') ? profile.nombreEnfants : null;
    final propertyValue = profile.patrimoine.immobilierEffectif;
    final propertyMarketValue =
        provided.contains('propertyMarketValue') && propertyValue > 0
            ? propertyValue
            : null;
    final mortgage =
        profile.dettes.hypotheque ?? profile.patrimoine.mortgageBalance;
    final mortgageBalance = provided.contains('mortgageBalance') &&
            mortgage != null &&
            mortgage >= 0
        ? mortgage
        : null;
    final estatePropertyNet =
        propertyMarketValue != null && mortgageBalance != null
            ? WealthFinancialFacts.propertyNetValue(
                propertyValue: propertyMarketValue,
                mortgageBalance: mortgageBalance,
              )
            : 0.0;
    final estateReference = WealthFinancialFacts.reconcileAggregate(
      cash: provided.contains('liquidSavings')
          ? profile.patrimoine.epargneLiquide
          : 0,
      investments: provided.contains('investments')
          ? profile.patrimoine.investissements
          : 0,
      propertyValue: estatePropertyNet,
      wealthEstimate: profile.patrimoine.wealthEstimate,
    );
    final estateUsesDetailedFacts = estatePropertyNet > 0 ||
        (provided.contains('liquidSavings') &&
            profile.patrimoine.epargneLiquide > 0) ||
        (provided.contains('investments') &&
            profile.patrimoine.investissements > 0);
    final wealthReference = provided.contains('wealthEstimate') &&
            estateReference.hasEstimate &&
            estateReference.resolvedTotal > 0
        ? estateReference.resolvedTotal
        : null;

    return _DonationLedgerFacts(
      age: age,
      canton: canton,
      civilStatus: civilStatus,
      children: children,
      wealthReference: wealthReference,
      propertyMarketValue: propertyMarketValue,
      mortgageBalance: mortgageBalance,
      estateUsesDetailedFacts: estateUsesDetailedFacts,
      estateNeedsReconciliation: estateReference.needsReconciliation,
      estateMortgageMissing:
          propertyMarketValue != null && mortgageBalance == null,
    );
  }

  const _DonationLedgerFacts.empty()
      : age = null,
        canton = null,
        civilStatus = null,
        children = null,
        wealthReference = null,
        propertyMarketValue = null,
        mortgageBalance = null,
        estateUsesDetailedFacts = false,
        estateNeedsReconciliation = false,
        estateMortgageMissing = false;

  bool canSimulate(String donationType) {
    final baseReady = age != null &&
        canton != null &&
        civilStatus != null &&
        children != null &&
        wealthReference != null;
    if (!baseReady) return false;
    if (donationType == 'immobilier') {
      return propertyMarketValue != null && mortgageBalance != null;
    }
    return true;
  }
}
