/// Form Pre-fill Service — Agent Autonome v1 (S68).
///
/// Pure functions for pre-filling tax declaration, 3a contribution,
/// and LPP buyback request forms from user profile data.
///
/// COMPLIANCE INVARIANTS:
///   - ALL user-facing strings via [S] (i18n) — ZERO hardcoded strings.
///   - [FormPrefill.requiresValidation] ALWAYS returns true.
///   - All [FormField] fields have [userMustConfirm] = true.
///   - NO PII (name, address, SSN/AVS, IBAN, employer) in pre-filled values.
///   - Financial amounts shown as RANGES to avoid exposing exact salary.
///   - Disclaimer present on every output.
///
/// References:
///   - LIFD art. 21-33 (revenu imposable / déductions)
///   - LIFD art. 38 (impôt sur retrait en capital)
///   - OPP3 art. 7 (plafond 3e pilier)
///   - LPP art. 79b (rachat LPP)
///   - LSFin art. 3/8 (qualité de l'information financière)
library;

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  VALUE OBJECTS
// ════════════════════════════════════════════════════════════════

/// A single field in a pre-filled form.
///
/// [label] and [source] are i18n strings passed in via [S].
/// [value] is a computed, anonymized value (never raw PII).
/// [userMustConfirm] and [isEstimated] are always true for financial amounts.
class FormField {
  const FormField({
    required this.label,
    required this.value,
    this.isEstimated = true,
    this.source,
    this.userMustConfirm = true,
  });

  /// Human-readable label (i18n).
  final String label;

  /// Pre-filled value (anonymized, may be a range).
  final String value;

  /// True if the value is estimated (inferred from profile data).
  final bool isEstimated;

  /// Source reference (legal article or data origin), if applicable.
  final String? source;

  /// ALWAYS true — user must validate every field before use.
  final bool userMustConfirm;
}

/// Result of a form pre-fill operation.
///
/// [requiresValidation] is ALWAYS true — structural guarantee.
class FormPrefill {
  const FormPrefill({
    required this.formType,
    required this.fields,
    required this.disclaimer,
  }) : requiresValidation = true;

  /// Identifier for the form type (e.g. "taxDeclaration", "3a", "lppBuyback").
  final String formType;

  /// Pre-filled fields. All have [FormField.userMustConfirm] = true.
  final List<FormField> fields;

  /// Educational disclaimer. Always non-empty.
  final String disclaimer;

  /// ALWAYS true. MINT never submits anything automatically.
  final bool requiresValidation;
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Pure-function service for pre-filling forms from user profile data.
///
/// Every method is static, deterministic, and side-effect-free.
/// All user-facing strings pass through [S] (i18n).
class FormPrefillService {
  FormPrefillService._();

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────

  /// Pre-fill a tax declaration form from user profile.
  ///
  /// Returns structured field values — user MUST validate each field.
  /// Financial amounts shown as ± 5'000 ranges (not exact salary).
  /// NO PII (name, address, SSN) included.
  ///
  /// References: LIFD art. 21-33, OPP3 art. 7, LPP art. 79b.
  static FormPrefill prepareTaxDeclaration({
    required CoachProfile profile,
    required int taxYear,
    required S l,
  }) {
    final revenuRange = _toRange(profile.revenuBrutAnnuel);
    final canton =
        profile.canton.isNotEmpty ? profile.canton : l.agentFormCantonFallback;
    final plafond3a = _plafond3a(profile);
    final rachatMax = profile.prevoyance.lacuneRachatRestante;

    final disclaimer = l.agentOutputDisclaimer;
    const sourceRef = 'LIFD art.\u00a021-33 / OPP3 art.\u00a07 / LPP art.\u00a079b';

    return FormPrefill(
      formType: 'taxDeclaration',
      disclaimer: disclaimer,
      fields: [
        FormField(
          label: l.agentTaxFormTitle,
          value: '$taxYear',
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormRevenuBrut,
          value: '~$revenuRange\u00a0CHF/an',
          isEstimated: true,
          source: l.agentFieldSource(sourceRef),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormCanton,
          value: canton,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormSituationFamiliale,
          value: _civilStatusLabel(profile.etatCivil, l),
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormNbEnfants,
          value: '${profile.nombreEnfants}',
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormDeduction3a,
          value: '~${_formatAmount(plafond3a)}\u00a0CHF',
          isEstimated: true,
          source: l.agentFieldSource('OPP3 art.\u00a07'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormRachatLppDeductible,
          value: rachatMax > 0
              ? '~${_toRange(rachatMax)}\u00a0CHF'
              : '0\u00a0CHF',
          isEstimated: true,
          source: l.agentFieldSource('LPP art.\u00a079b'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormStatutProfessionnel,
          value: _employmentStatusLabel(profile.employmentStatus, l),
          isEstimated: false,
          userMustConfirm: true,
        ),
      ],
    );
  }

  /// Pre-fill a 3a contribution form.
  ///
  /// Determines the correct plafond based on employment status and LPP.
  /// Salarié avec LPP: CHF 7'258. Indépendant sans LPP: CHF 36'288.
  ///
  /// Reference: OPP3 art. 7.
  static FormPrefill prepare3aForm({
    required CoachProfile profile,
    required int year,
    required S l,
  }) {
    final plafond = _plafond3a(profile);
    final isIndependantSansLpp =
        profile.employmentStatus == 'independant' && !_hasLpp(profile);
    final typeContrat = isIndependantSansLpp
        ? l.agentFormTypeContratIndependant
        : l.agentFormTypeContratSalarie;

    return FormPrefill(
      formType: '3a',
      disclaimer: l.agentOutputDisclaimer,
      fields: [
        FormField(
          label: l.agent3aFormTitle,
          value: '$year',
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormBeneficiaireNom,
          value: l.agentLetterPlaceholderName,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormNumeroCompte3a,
          value: l.agentFormToComplete,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormMontantVersementLabel,
          value: l.agentFormMontantVersement(
            _formatAmount(plafond),
            '$year',
          ),
          isEstimated: true,
          source: l.agentFieldSource('OPP3 art.\u00a07'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormTypeContrat,
          value: typeContrat,
          isEstimated: false,
          userMustConfirm: true,
        ),
      ],
    );
  }

  /// Pre-fill a LPP buyback request form.
  ///
  /// Includes rachat maximum if available in profile.
  /// Financial amounts shown as ranges — never exact salary.
  ///
  /// Reference: LPP art. 79b.
  static FormPrefill prepareLppBuyback({
    required CoachProfile profile,
    required S l,
  }) {
    final rachatMax = profile.prevoyance.lacuneRachatRestante;
    final rachatEffectue = profile.prevoyance.rachatEffectue ?? 0.0;
    final caisse =
        profile.prevoyance.nomCaisse ?? l.agentLetterCaisseFallback;
    final avoirTotal = profile.prevoyance.avoirLppTotal ?? 0.0;

    return FormPrefill(
      formType: 'lppBuyback',
      disclaimer: l.agentOutputDisclaimer,
      fields: [
        FormField(
          label: l.agentLppFormTitle,
          value: caisse,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormTitulaireNom,
          value: l.agentLetterPlaceholderName,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormNumeroPolice,
          value: l.agentFormToComplete,
          isEstimated: false,
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormAvoirLpp,
          value: avoirTotal > 0
              ? '~${_toRange(avoirTotal)}\u00a0CHF'
              : l.agentFormToComplete,
          isEstimated: true,
          source: l.agentFieldSource('LPP art.\u00a015'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormRachatMax,
          value: rachatMax > 0
              ? '~${_toRange(rachatMax)}\u00a0CHF'
              : l.agentFormToCompleteAupres,
          isEstimated: rachatMax > 0,
          source: l.agentFieldSource('LPP art.\u00a079b'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormRachatsDeja,
          value: rachatEffectue > 0
              ? '~${_toRange(rachatEffectue)}\u00a0CHF'
              : '0\u00a0CHF',
          isEstimated: rachatEffectue > 0,
          source: l.agentFieldSource('LPP art.\u00a079b al.\u00a03'),
          userMustConfirm: true,
        ),
        FormField(
          label: l.agentFormMontantRachatSouhaite,
          value: l.agentFormToCompleteMax(_formatAmount(rachatMax)),
          isEstimated: false,
          userMustConfirm: true,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Round to nearest 5'000 range to avoid exposing exact salary.
  static String _toRange(double value) {
    if (value <= 0) return '0';
    const step = 5000;
    final lower = (value / step).floor() * step;
    final upper = lower + step;
    return '${_formatAmount(lower.toDouble())}-${_formatAmount(upper.toDouble())}';
  }

  /// Format amount with Swiss apostrophe thousands separator.
  static String _formatAmount(double amount) {
    final rounded = amount.round();
    if (rounded == 0) return '0';
    final str = rounded.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0 && str[i - 1] != '-') {
        buffer.write("'");
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Determine 3a plafond based on employment status and LPP.
  /// Salarié avec LPP: CHF 7'258. Indépendant sans LPP: CHF 36'288.
  static double _plafond3a(CoachProfile profile) {
    if (profile.employmentStatus == 'independant' && !_hasLpp(profile)) {
      return reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp);
    }
    return reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
  }

  /// Check if profile has LPP (via avoir or caisse).
  static bool _hasLpp(CoachProfile profile) {
    final avoir = profile.prevoyance.avoirLppTotal ?? 0;
    return avoir > 0 || profile.prevoyance.nomCaisse != null;
  }

  static String _civilStatusLabel(CoachCivilStatus status, S l) {
    return switch (status) {
      CoachCivilStatus.celibataire => l.agentFormCivilCelibataire,
      CoachCivilStatus.marie => l.agentFormCivilMarie,
      CoachCivilStatus.divorce => l.agentFormCivilDivorce,
      CoachCivilStatus.veuf => l.agentFormCivilVeuf,
      CoachCivilStatus.concubinage => l.agentFormCivilConcubinage,
    };
  }

  static String _employmentStatusLabel(String status, S l) {
    return switch (status) {
      'salarie' => l.agentFormEmplSalarie,
      'independant' => l.agentFormEmplIndependant,
      'chomage' => l.agentFormEmplChomage,
      'retraite' => l.agentFormEmplRetraite,
      _ => status,
    };
  }
}
