import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/confidence_scorer.dart';

/// Resolves presentation copy without leaking a locale into financial_core.
extension EnrichmentPromptLocalizations on EnrichmentPrompt {
  String localizedLabel(S l10n) {
    return switch (copyCode) {
      EnrichmentPromptCopyCode.partnerDetails =>
        l10n.confidencePromptPartnerLabel,
      EnrichmentPromptCopyCode.taxMunicipality => l10n.dataBlockFiscaliteTitle,
      EnrichmentPromptCopyCode.taxDocument => l10n.docScanTaxDocumentLabel,
      EnrichmentPromptCopyCode.freshnessStale ||
      EnrichmentPromptCopyCode.freshnessCurrent =>
        l10n.confidencePromptRefreshField(_localizedField(l10n)),
      EnrichmentPromptCopyCode.accuracyEstimated ||
      EnrichmentPromptCopyCode.accuracyUserInput =>
        l10n.confidencePromptConfirmField(_localizedField(l10n)),
      EnrichmentPromptCopyCode.education => l10n.confidencePromptEducationLabel,
      EnrichmentPromptCopyCode.coachQuestion => l10n.confidencePromptCoachLabel,
      null => label,
    };
  }

  String localizedAction(S l10n) {
    return switch (copyCode) {
      EnrichmentPromptCopyCode.partnerDetails =>
        l10n.confidencePromptPartnerAction,
      EnrichmentPromptCopyCode.taxMunicipality => l10n.dataBlockFiscaliteDesc,
      EnrichmentPromptCopyCode.taxDocument =>
        l10n.docScanTaxDocumentDescription,
      EnrichmentPromptCopyCode.freshnessStale =>
        l10n.confidencePromptFreshnessStale(copyArgument!),
      EnrichmentPromptCopyCode.freshnessCurrent =>
        l10n.confidencePromptFreshnessCurrent,
      EnrichmentPromptCopyCode.accuracyEstimated =>
        l10n.confidencePromptAccuracyEstimated,
      EnrichmentPromptCopyCode.accuracyUserInput =>
        l10n.confidencePromptAccuracyCurrentSource,
      EnrichmentPromptCopyCode.education =>
        l10n.confidencePromptEducationAction,
      EnrichmentPromptCopyCode.coachQuestion =>
        l10n.confidencePromptCoachAction,
      null => action,
    };
  }

  String _localizedField(S l10n) {
    return switch (fieldPath) {
      'salaireBrutMensuel' => l10n.dataBlockRevenuTitle,
      'age' => l10n.expertItemAge,
      'canton' => l10n.expertItemCanton,
      'etatCivil' => l10n.agentFormSituationFamiliale,
      'prevoyance.avoirLppTotal' => l10n.dataBlockLppTitle,
      'prevoyance.tauxConversion' => l10n.financialSummaryTauxConversion,
      'prevoyance.anneesContribuees' => l10n.expertItemAvsYears,
      'prevoyance.totalEpargne3a' => l10n.dataBlock3aTitle,
      'patrimoine.epargneLiquide' => l10n.dataBlockPatrimoineTitle,
      _ => fieldPath ?? '',
    };
  }
}
