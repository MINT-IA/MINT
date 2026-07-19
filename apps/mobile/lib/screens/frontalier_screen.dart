import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/common/mint_empty_state.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:provider/provider.dart';

class FrontalierScreen extends StatelessWidget {
  const FrontalierScreen({super.key});

  static const _countryCodes = <String>['CH', 'FR', 'DE', 'IT', 'AT', 'LI'];

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final profile = context.watch<CoachProfileProvider>().profile;
    final evidence = profile?.frontierJurisdictionAt(DateTime.now());

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.background,
        surfaceTintColor: MintColors.transparent,
        leading: Semantics(
          label: l10n.semanticsBackButton,
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => safePop(context),
          ),
        ),
        title: Text(
          l10n.frontalierAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg,
          MintSpacing.md,
          MintSpacing.lg,
          100,
        ),
        children: <Widget>[
          Text(
            l10n.frontalierScreenIntro,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textSecondaryAaa,
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          _jurisdictionCollector(context, profile, l10n),
          const SizedBox(height: MintSpacing.lg),
          if (evidence == null ||
              evidence.state == FrontierJurisdictionState.missing)
            _missingState(context, l10n)
          else if (evidence.state == FrontierJurisdictionState.stale)
            _staleState(context, profile!, evidence, l10n)
          else if (evidence.candidateTaxInstrument ==
              FrontierTaxInstrument.domestic)
            _domesticState(context, profile!, l10n)
          else if (evidence.state == FrontierJurisdictionState.known)
            _knownState(profile!, evidence, l10n)
          else
            _specialistOnlyState(profile!, l10n),
        ],
      ),
    );
  }

  Widget _jurisdictionCollector(
    BuildContext context,
    CoachProfile? profile,
    S l10n,
  ) {
    final workCountry = profile?.workCountry?.value;

    return MintSurface(
      tone: MintSurfaceTone.craie,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.frontalierFactsTitle,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.md),
          _dropdownField(
            label: l10n.frontalierResidenceCountryLabel,
            child: DropdownButton<String>(
              key: const Key('frontier_residence_country_field'),
              value: profile?.residenceCountry?.value,
              isExpanded: true,
              hint: Text(l10n.frontalierSelectPlaceholder),
              items: _countryItems(l10n),
              onChanged: (value) async {
                if (value == null) return;
                await _persistLedgerAnswers(
                  context,
                  <String, dynamic>{'q_residence_country': value},
                );
              },
            ),
          ),
          const SizedBox(height: MintSpacing.md),
          _dropdownField(
            label: l10n.frontalierWorkCountryLabel,
            child: DropdownButton<String>(
              key: const Key('frontier_work_country_field'),
              value: workCountry,
              isExpanded: true,
              hint: Text(l10n.frontalierSelectPlaceholder),
              items: _countryItems(l10n),
              onChanged: (value) async {
                if (value == null) return;
                await _persistLedgerAnswers(
                  context,
                  <String, dynamic>{
                    'q_work_country': value,
                    if (value != 'CH') 'q_work_canton': null,
                  },
                );
              },
            ),
          ),
          if (workCountry == 'CH') ...<Widget>[
            const SizedBox(height: MintSpacing.md),
            _dropdownField(
              label: l10n.frontalierWorkCantonLabel,
              child: DropdownButton<String>(
                key: const Key('frontier_work_canton_field'),
                value: profile?.workCanton?.value,
                isExpanded: true,
                hint: Text(l10n.frontalierSelectPlaceholder),
                items: SwissCantonCode.supportedValues
                    .map(
                      (code) => DropdownMenuItem<String>(
                        value: code,
                        child: Text(code),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) async {
                  if (value == null) return;
                  await _persistLedgerAnswers(
                    context,
                    <String, dynamic>{'q_work_canton': value},
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdownField({required String label, required Widget child}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  Future<void> _persistLedgerAnswers(
    BuildContext context,
    Map<String, dynamic> answers,
  ) async {
    try {
      await context.read<CoachProfileProvider>().mergeAnswers(answers);
    } on Object {
      // The provider publishes only after persistence succeeds, so retaining
      // its previous snapshot is safer than drifting the visible jurisdiction.
    }
  }

  List<DropdownMenuItem<String>> _countryItems(S l10n) => _countryCodes
      .map(
        (code) => DropdownMenuItem<String>(
          value: code,
          child: Text(_countryLabel(l10n, code)),
        ),
      )
      .toList(growable: false);

  String _countryLabel(S l10n, String code) => switch (code) {
        'CH' => l10n.frontalierCountryCH,
        'FR' => l10n.frontalierCountryFR,
        'DE' => l10n.frontalierCountryDE,
        'IT' => l10n.frontalierCountryIT,
        'AT' => l10n.frontalierCountryAT,
        'LI' => l10n.frontalierCountryLI,
        _ => code,
      };

  Widget _missingState(BuildContext context, S l10n) {
    return Column(
      children: <Widget>[
        FilledButton.icon(
          key: const Key('frontier_jurisdiction_capture_cta'),
          onPressed: () => context.push('/coach/chat'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(l10n.frontalierCaptureWithCoach),
        ),
        MintEmptyState(
          key: const Key('frontier_jurisdiction_missing_state'),
          icon: Icons.public,
          title: l10n.frontalierMissingTitle,
          subtitle: l10n.frontalierMissingDescription,
        ),
      ],
    );
  }

  Widget _staleState(
    BuildContext context,
    CoachProfile profile,
    FrontierJurisdictionEvidence evidence,
    S l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _stateCard(
          key: const Key('frontier_jurisdiction_stale_state'),
          icon: Icons.history,
          title: l10n.frontalierStaleTitle,
          body: l10n.frontalierStaleDescription,
          tone: MintSurfaceTone.porcelaine,
        ),
        const SizedBox(height: MintSpacing.md),
        _factsCard(profile, l10n),
        const SizedBox(height: MintSpacing.md),
        FilledButton.icon(
          key: const Key('frontier_jurisdiction_reconfirm_cta'),
          onPressed: evidence.staleFields.contains('workCanton') &&
                  profile.workCanton != null
              ? () async {
                  await _persistLedgerAnswers(
                    context,
                    <String, dynamic>{
                      'q_work_canton': profile.workCanton!.value,
                    },
                  );
                }
              : null,
          icon: const Icon(Icons.check),
          label: Text(l10n.frontalierReconfirm),
        ),
      ],
    );
  }

  Widget _domesticState(
    BuildContext context,
    CoachProfile profile,
    S l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _stateCard(
          key: const Key('frontier_jurisdiction_domestic_state'),
          icon: Icons.home_outlined,
          title: l10n.frontalierDomesticTitle,
          body: l10n.frontalierDomesticDescription,
          tone: MintSurfaceTone.sauge,
        ),
        const SizedBox(height: MintSpacing.md),
        _factsCard(profile, l10n),
        const SizedBox(height: MintSpacing.md),
        FilledButton.icon(
          key: const Key('frontier_domestic_fiscal_cta'),
          onPressed: () => context.push('/fiscal'),
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.frontalierOpenDomesticFiscal),
        ),
      ],
    );
  }

  Widget _knownState(
    CoachProfile profile,
    FrontierJurisdictionEvidence evidence,
    S l10n,
  ) {
    final isCdi = evidence.candidateTaxInstrument ==
        FrontierTaxInstrument.cdi1966Article17;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _stateCard(
          key: const Key('frontier_jurisdiction_known_state'),
          icon: Icons.verified_outlined,
          title: l10n.frontalierKnownTitle,
          body: l10n.frontalierKnownDescription,
          tone: MintSurfaceTone.sauge,
        ),
        const SizedBox(height: MintSpacing.md),
        _factsCard(profile, l10n),
        const SizedBox(height: MintSpacing.md),
        _informationCard(
          key: const Key('frontier_tax_orientation_card'),
          icon: Icons.account_balance_outlined,
          title: l10n.frontalierTaxCardTitle,
          headline: isCdi
              ? l10n.frontalierCdiCandidateTitle
              : l10n.frontalierAccordCandidateTitle,
          body: isCdi
              ? l10n.frontalierCdiCandidateDescription
              : l10n.frontalierAccordCandidateDescription,
        ),
        const SizedBox(height: MintSpacing.md),
        _socialInsuranceCard(l10n),
        const SizedBox(height: MintSpacing.md),
        _specialistQuestionsCard(l10n),
        const SizedBox(height: MintSpacing.md),
        _disclaimer(l10n),
      ],
    );
  }

  Widget _specialistOnlyState(CoachProfile profile, S l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _stateCard(
          key: const Key('frontier_jurisdiction_specialist_only_state'),
          icon: Icons.support_agent,
          title: l10n.frontalierSpecialistTitle,
          body: l10n.frontalierSpecialistDescription,
          tone: MintSurfaceTone.porcelaine,
        ),
        const SizedBox(height: MintSpacing.md),
        _factsCard(profile, l10n),
        const SizedBox(height: MintSpacing.md),
        _informationCard(
          key: const Key('frontier_tax_orientation_card'),
          icon: Icons.account_balance_outlined,
          title: l10n.frontalierTaxCardTitle,
          body: l10n.frontalierSpecialistTaxDescription,
        ),
        const SizedBox(height: MintSpacing.md),
        _socialInsuranceCard(l10n),
        const SizedBox(height: MintSpacing.md),
        _specialistQuestionsCard(l10n),
        const SizedBox(height: MintSpacing.md),
        _disclaimer(l10n),
      ],
    );
  }

  Widget _factsCard(CoachProfile profile, S l10n) {
    return MintSurface(
      key: const Key('frontier_jurisdiction_facts_card'),
      tone: MintSurfaceTone.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.frontalierFactsTitle,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          _factRow(
            l10n.frontalierResidenceFact,
            profile.residenceCountry?.value ?? l10n.frontalierSelectPlaceholder,
          ),
          _factRow(
            l10n.frontalierWorkCountryFact,
            profile.workCountry?.value ?? l10n.frontalierSelectPlaceholder,
          ),
          if (profile.workCountry?.value == 'CH')
            _factRow(
              l10n.frontalierWorkCantonFact,
              profile.workCanton?.value ?? l10n.frontalierSelectPlaceholder,
            ),
        ],
      ),
    );
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondaryAaa,
              ),
            ),
          ),
          Text(
            value,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _stateCard({
    required Key key,
    required IconData icon,
    required String title,
    required String body,
    required MintSurfaceTone tone,
  }) {
    return MintSurface(
      key: key,
      tone: tone,
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: MintColors.accent),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  body,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondaryAaa,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard({
    required Key key,
    required IconData icon,
    required String title,
    String? headline,
    required String body,
  }) {
    return MintSurface(
      key: key,
      tone: MintSurfaceTone.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: MintColors.accent),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (headline != null) ...<Widget>[
            const SizedBox(height: MintSpacing.md),
            Text(
              headline,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: MintSpacing.sm),
          Text(
            body,
            style: MintTextStyles.bodySmall(
              color: MintColors.textSecondaryAaa,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialInsuranceCard(S l10n) {
    return _informationCard(
      key: const Key('frontier_social_insurance_card'),
      icon: Icons.health_and_safety_outlined,
      title: l10n.frontalierSocialCardTitle,
      body: l10n.frontalierSocialDescription,
    );
  }

  Widget _specialistQuestionsCard(S l10n) {
    return MintSurface(
      key: const Key('frontier_specialist_questions_card'),
      tone: MintSurfaceTone.craie,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.frontalierQuestionsTitle,
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
          ),
          const SizedBox(height: MintSpacing.sm),
          for (final question in <String>[
            l10n.frontalierQuestionResidence,
            l10n.frontalierQuestionEmployment,
            l10n.frontalierQuestionEmployer,
            l10n.frontalierQuestionA1,
          ])
            Padding(
              padding: const EdgeInsets.only(top: MintSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Icons.help_outline,
                    size: 18,
                    color: MintColors.accent,
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      question,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondaryAaa,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _disclaimer(S l10n) {
    return Semantics(
      label: l10n.frontalierDisclaimer,
      child: Container(
        key: const Key('frontier_disclaimer'),
        padding: const EdgeInsets.all(MintSpacing.md),
        decoration: BoxDecoration(
          color: MintColors.disclaimerBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          l10n.frontalierDisclaimer,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
      ),
    );
  }
}
