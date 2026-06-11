/// MVP Wedge onboarding state v2 — storyboard final locked 2026-04-22.
///
/// 9 tours linéaires après sélection d'un intent au tour 2. Chaque tour
/// capture une data qui peuple le dossier strip. Flush vers
/// CoachProfile au tour 9 (magic link envoyé).
///
/// Doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md`
/// Feedback règles : scenario-before-screen, retains-everything,
///                   net-monthly-not-gross-annual.
library;

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/models/onboarding_intent.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
// NOTE (sub-phase 01.5 W02-T05): ProfileMigrationService is consulted by
// the CALLER (OnboardingShellScreen wrapper after awaiting the flag) — we
// don't import it here so the provider stays SharedPreferences-free + sync
// constructable in unit tests. See OnboardingProvider.legacyReOnboarding
// below.
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/income_converter.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Une ligne visible du dossier, affichée dans la bande en bas d'écran.
@immutable
class DossierEntry {
  const DossierEntry({
    required this.key,
    required this.label,
    required this.value,
    required this.orderHint,
  });

  final String key;
  final String label;
  final String value;
  final int orderHint;
}

/// Les 9 tours du flow storyboard final.
enum OnboardingStep {
  entry, // T1 — opener
  intents, // T2 — 4 cartes d'intent
  // T2.5 — Sub-phase 01.5 W02-T03 hard-gate US-tax-person Q.
  // Placed BEFORE age/canton/revenue because Security §4 (nLPD art. 6
  // data minimization) requires the FATCA self-declaration to be asked
  // BEFORE any financial-data collection. Yes → archetype is forced to
  // expatUs by `CoachProfile.fromWizardAnswers` (plan 02-01), and the
  // coach-entry gate (plan 02-03 Task 4) routes to /waitlist before
  // CoachContext is built.
  usTaxPerson, // T2.5
  // T2.6 — SALVAGE-01: nationality capture. Placed AFTER usTaxPerson and
  // BEFORE age because nationality is an archetype signal that pairs with
  // the FATCA Q (both precede financial-data collection per nLPD art. 6
  // data-minimization). `advance()` walks OnboardingStep.values via
  // indexOf, so inserting mid-enum is ordinal-safe — no `.index` is
  // persisted or used in analytics (grep-confirmed 2026-05-31).
  // The captured group (CH/EU/OTHER) is mapped to a nationality string at
  // the flush so CoachProfile.fromWizardAnswers reaches the swissNative /
  // expatEu / expatNonEu archetype branches. NEVER coerced null→'CH'.
  nationality, // T2.6
  // T2.7-T2.9 — W2 (mint-illogism-fixes-06) archetype-truth questions.
  // Placed AFTER nationality and BEFORE age: like the FATCA + nationality
  // signals, employment / civil status / AVS gaps are archetype signals
  // that disambiguate the user BEFORE financial-data collection (NEVER #7).
  // `advance()` walks OnboardingStep.values via indexOf, so inserting
  // mid-enum is ordinal-safe — no `.index` is persisted or used in
  // analytics. The captured values populate the EXISTING q_* keys read by
  // CoachProfile.fromWizardAnswers (no new schema field).
  employment, // T2.7 — statut d'emploi
  civilStatus, // T2.8 — état civil (incl. divorce)
  avsLacunes, // T2.9 — lacunes AVS (années à l'étranger)
  age, // T3
  canton, // T4
  revenue, // T5 — slider fourchette + lien exact
  insight, // T6 — N1 inline contextuel à l'intent
  scene, // T7 — scène N2 interactive
  bifurcation, // T8 — [Creuser] / [Plus tard] → flush + navigate
  // T9 "magicLink" removed 2026-04-24 per design panel : user-eject
  // pattern ("Laisse-moi un email, je te retrouve demain") violated
  // retention. Bifurcation now flushes the dossier directly + navigates
  // to /coach/chat or /home. Auth conversion happens inline via the
  // existing auth_gate_bottom_sheet after 3 anonymous coach messages.
}

/// Niveau de confiance d'une donnée captée, aligné sur
/// EnhancedConfidence 4-axes de MINT (completeness × accuracy ×
/// freshness × understanding). Simplifié ici à 4 paliers.
enum OnboardingConfidence { low, medium, high, veryHigh }

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider();

  /// Sub-phase 01.5 W02-T05 Task 1 (R7) — pre-archetype guard constructor.
  ///
  /// Legacy users grandfathered by `ProfileMigrationService` (cached
  /// pre-fix profile with `usTaxPerson==null AND nationality==null`) start
  /// the orchestrator DIRECTLY at the `usTaxPerson` step — bypassing
  /// the entry / intent steps. After they answer the FATCA Q, the
  /// `UsTaxPersonScreen` calls `ProfileMigrationService.clearReOnboardingFlag`
  /// and the archetype getter resolves from the fresh signal on the
  /// next entry.
  ///
  /// **Codex C1 HIGH (REVIEWS.md 2026-05-22):** this is the structural
  /// fix that lets the migration be FLAG-ONLY (no nationality rewrite).
  /// Without this guard the legacy ambiguous profile would route to
  /// the archetype getter's "all signals null → unknown" branch and
  /// land on /waitlist before the user ever sees the FATCA Q.
  ///
  /// **Pre-archetype**: this guard runs BEFORE archetype detection
  /// in the wider app — the orchestrator's step state machine never
  /// consults `CoachProfile.archetype`.
  ///
  /// `needsUsTaxPersonReOnboarding` is computed by the caller (e.g.
  /// `OnboardingShellScreen` after awaiting `ProfileMigrationService`).
  /// We accept the bool to keep the provider's constructor synchronous
  /// and unit-testable in isolation (no SharedPreferences dep).
  OnboardingProvider.legacyReOnboarding({
    required bool needsUsTaxPersonReOnboarding,
  }) {
    if (needsUsTaxPersonReOnboarding) {
      _step = OnboardingStep.usTaxPerson;
    }
  }

  OnboardingStep _step = OnboardingStep.entry;
  final Map<String, DossierEntry> _dossier = {};

  // Captures — source of truth for the mapper au tour 9.
  OnboardingIntent? _intent;
  int? _ageYears;
  DateTime? _dateOfBirth;

  /// Captured nationality GROUP from the T2.6 step: 'CH', 'EU', or 'OTHER'.
  /// Mapped to a nationality string at the flush (mirrors
  /// CoachProfileProvider.updateFromSmartFlow). null until the user picks.
  String? _nationalityGroup;
  // W2 (mint-illogism-fixes-06) — archetype-truth captures. null until the
  // user answers; the flush emits the EXACT q_* values the parser reads.
  // No DossierEntry side-effect: like nationality these are archetype
  // signals kept invisible to the user post-answer (PII: civil status /
  // employment), surfaced only by the coach gate.
  String? _employmentStatus;
  String? _civilStatus;
  String? _avsLacunesStatus;
  int? _avsArrivalYear;
  int? _avsYearsAbroad;
  String? _cantonCode;
  ({double low, double high})? _netMonthlyRange;
  double? _netMonthlyExact;
  bool _wantsDeeper = false;
  bool _sealed = false;

  final Map<String, OnboardingConfidence> _confidenceByField = {};

  // ── Read accessors ──────────────────────────────────────────────
  OnboardingStep get step => _step;
  OnboardingIntent? get intent => _intent;
  int? get ageYears {
    final dob = _dateOfBirth;
    if (dob == null) return _ageYears;
    return _ageFromDateOfBirth(dob);
  }

  DateTime? get dateOfBirth => _dateOfBirth;
  String? get employmentStatus => _employmentStatus;
  String? get civilStatus => _civilStatus;
  String? get avsLacunesStatus => _avsLacunesStatus;
  int? get avsArrivalYear => _avsArrivalYear;
  int? get avsYearsAbroad => _avsYearsAbroad;
  String? get nationalityGroup => _nationalityGroup;
  String? get cantonCode => _cantonCode;
  ({double low, double high})? get netMonthlyRange => _netMonthlyRange;
  double? get netMonthlyExact => _netMonthlyExact;
  bool get wantsDeeper => _wantsDeeper;
  bool get sealed => _sealed;
  Map<String, OnboardingConfidence> get confidenceByField =>
      Map.unmodifiable(_confidenceByField);

  bool get isCompleted => _sealed;

  List<DossierEntry> get dossier {
    final list = _dossier.values.toList()
      ..sort((a, b) => a.orderHint.compareTo(b.orderHint));
    return List.unmodifiable(list);
  }

  /// Revenu net mensuel effectif (soit l'exact s'il a été saisi, soit
  /// le milieu de la fourchette). Lecture unique pour les calculateurs.
  double? get netMonthlyEffective {
    if (_netMonthlyExact != null) return _netMonthlyExact;
    if (_netMonthlyRange != null) {
      return (_netMonthlyRange!.low + _netMonthlyRange!.high) / 2;
    }
    return null;
  }

  // ── Write actions ──────────────────────────────────────────────

  void _setDossier(String key, String label, String value, int orderHint) {
    _dossier[key] = DossierEntry(
      key: key,
      label: label,
      value: value,
      orderHint: orderHint,
    );
  }

  void setIntent(OnboardingIntent intent, String humanLabel) {
    _intent = intent;
    _confidenceByField['intent'] = OnboardingConfidence.high;
    _setDossier('intent', 'Intention', humanLabel, 0);
    notifyListeners();
  }

  void setAge(int years) {
    _ageYears = years;
    _dateOfBirth = null;
    _confidenceByField['age'] = OnboardingConfidence.high;
    _setDossier('age', 'Âge', '$years ans', 1);
    notifyListeners();
  }

  void setDateOfBirth(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    _dateOfBirth = normalized;
    _ageYears = _ageFromDateOfBirth(normalized);
    _confidenceByField['dateOfBirth'] = OnboardingConfidence.high;
    _setDossier(
      'date_of_birth',
      'Date de naissance',
      _formatDateOfBirth(normalized),
      1,
    );
    notifyListeners();
  }

  /// Capture the nationality GROUP at T2.6. [group] ∈ {'CH','EU','OTHER'}.
  ///
  /// SALVAGE-01: plain field setter, NO DossierEntry side-effect — the
  /// nationality is an archetype signal that stays invisible to the user
  /// post-answer (mirrors the FATCA us-tax-person Q), surfaced only by the
  /// coach-entry gate. It is NOT routed through a standalone mergeAnswers
  /// call; it flows ONLY through the final completeAndFlushToProfile map.
  ///
  /// NOTE (documented known gap): the CH/EU/OTHER signal is a HINT for
  /// archetype detection, refined later by canton/permit signals. A
  /// naturalized-Swiss frontalier picking 'CH' resolves to swissNative
  /// because the wedge captures no permit-G — frontalier disambiguation is
  /// out of scope for this plan (no permit question at this boundary).
  void setNationality(String group) {
    _nationalityGroup = group;
    _confidenceByField['nationality'] = OnboardingConfidence.high;
    notifyListeners();
  }

  /// W2 — capture the employment status. [status] ∈ {salarie, independant,
  /// sans_activite} (the EXACT values _parseEmploymentStatus reads). Plain
  /// field setter, NO DossierEntry side-effect (PII, archetype signal).
  void setEmploymentStatus(String status) {
    _employmentStatus = status;
    _confidenceByField['employment'] = OnboardingConfidence.high;
    notifyListeners();
  }

  /// W2 — capture the civil status. [status] ∈ {celibataire, marie, divorce,
  /// veuf, concubinage} (the EXACT values _parseCivilStatus reads).
  void setCivilStatus(String status) {
    _civilStatus = status;
    _confidenceByField['civilStatus'] = OnboardingConfidence.high;
    notifyListeners();
  }

  /// W2 — capture the AVS-lacunes status. [status] ∈ {no_gaps, lived_abroad,
  /// arrived_late, unknown}. For arrived_late, pass [arrivalYear]; for
  /// lived_abroad, pass [yearsAbroad]. Both feed the avsGaps derivation in
  /// CoachProfile.fromWizardAnswers (coach_profile.dart:2808-2824).
  void setAvsLacunes(
    String status, {
    int? arrivalYear,
    int? yearsAbroad,
  }) {
    _avsLacunesStatus = status;
    _avsArrivalYear = arrivalYear;
    _avsYearsAbroad = yearsAbroad;
    _confidenceByField['avsLacunes'] = OnboardingConfidence.high;
    notifyListeners();
  }

  void setCanton(String code, String humanName) {
    _cantonCode = code;
    _confidenceByField['canton'] = OnboardingConfidence.high;
    _setDossier('canton', 'Canton', humanName, 2);
    notifyListeners();
  }

  void setNetMonthlyRange(double low, double high) {
    _netMonthlyRange = (low: low, high: high);
    _netMonthlyExact = null;
    _confidenceByField['revenue'] = OnboardingConfidence.medium;
    _setDossier(
      'revenue',
      'Revenu net mensuel',
      '${_formatChf(low)} – ${_formatChf(high)} CHF',
      3,
    );
    notifyListeners();
  }

  void setNetMonthlyExact(double value) {
    _netMonthlyExact = value;
    _netMonthlyRange = null;
    _confidenceByField['revenue'] = OnboardingConfidence.high;
    _setDossier(
      'revenue',
      'Revenu net mensuel',
      '${_formatChf(value)} CHF',
      3,
    );
    notifyListeners();
  }

  void setWantsDeeper(bool value) {
    _wantsDeeper = value;
    notifyListeners();
  }

  // ── Step navigation ─────────────────────────────────────────────

  void goToStep(OnboardingStep s) {
    _step = s;
    notifyListeners();
  }

  void advance() {
    const order = OnboardingStep.values;
    final idx = order.indexOf(_step);
    if (idx < order.length - 1) {
      _step = order[idx + 1];
      notifyListeners();
    }
  }

  // ── Flush to CoachProfile au tour 9 ─────────────────────────────

  /// Persiste la capture dans `wizard_answers_v2` + seed
  /// `CoachProfileProvider`. Appelé au T8 bifurcation (was T9 avant
  /// 2026-04-24 kill de la scène email-demain).
  ///
  /// Failure modes (caller MUST try/catch, never silent-swallow):
  /// - `mergeAnswers` → same SharedPreferences bucket, plus CoachProfile
  ///   derivation errors. Backend sync is already fire-and-forget inside
  ///   `mergeAnswers` (see `_syncToBackend`), so a thrown exception here
  ///   means local seed failed — NOT a backend outage.
  ///
  /// If the secure store cannot seal sensitive fields, persistence fails
  /// closed (PII is not demoted to SharedPreferences) but the current app
  /// session still receives the freshly captured profile in memory. This
  /// keeps the terminal onboarding path usable on dev/simulator keychains
  /// while preserving SEC-10 disk guarantees. The fallback deliberately
  /// skips backend sync too: unsealed local PII must not leave the device
  /// through a different path.
  Future<void> completeAndFlushToProfile(
    CoachProfileProvider coachProvider,
  ) async {
    final answers = <String, dynamic>{};
    if (_intent != null) answers['onb_intent'] = _intent!.name;
    if (_dateOfBirth != null) {
      answers['q_date_of_birth'] = _dateOfBirth!.toIso8601String();
      answers['q_birth_year'] = _dateOfBirth!.year;
    } else if (_ageYears != null) {
      answers['q_birth_year'] = DateTime.now().year - _ageYears!;
    }
    if (_cantonCode != null) answers['q_canton'] = _cantonCode;
    if (_netMonthlyExact != null) {
      answers['q_net_income_period_chf'] = _netMonthlyExact;
      answers['q_net_income_confidence'] = 'high';
    } else if (_netMonthlyRange != null) {
      // Persiste le milieu de la fourchette en valeur effective, et
      // archive la fourchette brute pour les upgrades de confidence.
      answers['q_net_income_period_chf'] = netMonthlyEffective;
      answers['q_net_income_range_low'] = _netMonthlyRange!.low;
      answers['q_net_income_range_high'] = _netMonthlyRange!.high;
      answers['q_net_income_confidence'] = 'medium';
    }
    // SALVAGE-01 (archetype-waitlist): derive q_nationality from the
    // captured group, mirroring updateFromSmartFlow's CH/EU/OTHER mapping.
    // 'CH' → 'CH' (swissNative); 'EU' → 'FR' (generic EU/AELE → expatEu);
    // 'OTHER' → null here (no country sub-capture in the wedge) → archetype
    // falls through to expatNonEu. Write q_nationality ONLY when non-null —
    // NEVER coerce null→'CH' (silent-fallback bug closed 2026-05-22; only a
    // POSITIVE 'CH' capture may yield swissNative).
    final String? nationality = switch (_nationalityGroup) {
      'CH' => 'CH',
      'EU' => 'FR',
      _ => null, // 'OTHER' or null group → no positive nationality signal
    };
    if (nationality != null) answers['q_nationality'] = nationality;

    // onb-03 + W2 (mint-illogism-fixes-06): employment + LPP affiliation at
    // flush. The W2 statut-d'emploi scene now captures employment; when the
    // user skipped it (legacy / partial flow) the default stays 'salarie' so
    // the existing archetype contract is preserved. q_has_pension_fund
    // mirrors updateFromSmartFlow's rule (gross-annual >= LPP-entry seuil AND
    // salaried) AND respects a 'sans_activite'/'independant' answer: a
    // non-salaried user is NOT auto-assumed to have a 2nd pillar (NEVER #7).
    final String employmentStatus = _employmentStatus ?? 'salarie';
    answers['q_employment_status'] = employmentStatus;
    final bool isSalaried = employmentStatus == 'salarie';
    final double? net = netMonthlyEffective;
    if (net != null && isSalaried) {
      final double grossAnnual =
          IncomeConverter.netMonthlyToGrossAnnual(net, isSalaried: true);
      answers['q_has_pension_fund'] =
          grossAnnual >= reg('lpp.entry_threshold', lppSeuilEntree);
    } else if (net != null) {
      // Independant / sans activité → no LPP affiliation presumed.
      answers['q_has_pension_fund'] = false;
    }

    // W2 — civil status + AVS gaps, emitted ONLY when captured (omit the
    // keys entirely otherwise so the parser keeps its safe defaults). These
    // are PII keys: they flow ONLY through this flush map into the encrypted
    // SecureWizardStore (sealed by SecureWizardStore._sensitiveKeys +
    // the q_avs_ prefix rule), never into logs or analytics.
    if (_civilStatus != null) answers['q_civil_status'] = _civilStatus;
    if (_avsLacunesStatus != null) {
      answers['q_avs_lacunes_status'] = _avsLacunesStatus;
      if (_avsArrivalYear != null) {
        answers['q_avs_arrival_year'] = _avsArrivalYear;
      }
      if (_avsYearsAbroad != null) {
        answers['q_avs_years_abroad'] = _avsYearsAbroad;
      }
    }

    answers['q_wants_deeper'] = _wantsDeeper;

    final sealed = await ReportPersistenceService.saveAnswers(answers);
    if (!sealed) {
      coachProvider.updateFromAnswers(answers);
      if (!coachProvider.hasProfile) {
        throw StateError(
          'onboarding_profile_unavailable_after_memory_seed',
        );
      }
      _sealed = true;
      notifyListeners();
      return;
    }
    await coachProvider.mergeAnswers(answers);
    if (!coachProvider.hasProfile) {
      throw StateError('onboarding_profile_unavailable_after_merge');
    }
    _sealed = true;
    notifyListeners();
  }

  /// Format CHF suisse avec apostrophe comme séparateur de milliers.
  /// Source of truth de formatage — le même que DossierStrip et
  /// chiffres héros des scènes N2.
  static String _formatChf(double value) {
    final whole = value.round();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static int _ageFromDateOfBirth(DateTime value) {
    final now = DateTime.now();
    var years = now.year - value.year;
    if (now.month < value.month ||
        (now.month == value.month && now.day < value.day)) {
      years--;
    }
    return years;
  }

  static String _formatDateOfBirth(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }
}
