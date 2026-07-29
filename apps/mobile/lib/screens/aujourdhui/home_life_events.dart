/// Home (Aujourd'hui) glue between [CoachProfile] and the life-event
/// suggestion cards, PR-D of the firstJob vertical tranche
/// (TRANCHE-FIRSTJOB-SPEC §1 T3 / §3.1).
///
/// The eligibility rules live in [buildLifeEventSuggestions]; this file only
/// translates the CoachProfile representation (French labels + enums) into the
/// primitive contract that builder expects, and owns the home-specific
/// accessibility identifiers. Kept out of the screen widget so it is
/// unit-testable without a BuildContext — it doubles as the deterministic
/// seed-fixture proof that a 25-year-old profile surfaces the firstJob card.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

/// Sentinel civil status / employment that matches no suggestion gate — fed
/// when the user has NOT provided the fact, so a constructor default never
/// fabricates a phantom card.
const _unknownCivilStatus = 'unknown';
const _unknownEmploymentStatus = 'unknown';

/// Builds the ordered life-event suggestions for /home from [profile].
///
/// Provenance-gated (CLAUDE.md NEVER #7, "unknown != default"): a suggestion
/// may only read a fact the user actually provided ([CoachProfile.userProvidedFields]).
/// Constructor defaults (`celibataire`, 0 children, `salarie`, canton `ZH`) are
/// NOT declared facts and must not fabricate phantom cards; and a gross salary
/// is NOT a net income (incomparable units), so income gates stay closed until
/// the net itself is known. The firstJob card requires only a provided age, so
/// a 25-year-old profile always yields a `/first-job` entry.
List<LifeEventSuggestion> homeLifeEventSuggestions(CoachProfile profile, S s) {
  final provided = profile.userProvidedFields;

  // Age drives most life events (firstJob <= 28, retraite >= 55, succession
  // >= 50, ...). Without a provided, valid age there is nothing to responsibly
  // gate -> surface nothing (D4: caller renders no section).
  final age = profile.ageOrNull;
  if (age == null || !provided.contains('age')) return const [];

  // Civil status / employment: real value only when provided; otherwise a
  // sentinel that fails every civil/employment gate.
  final civilStatus = provided.contains('civilStatus')
      ? _civilStatus(profile.etatCivil)
      : _unknownCivilStatus;
  final employmentStatus = provided.contains('employmentStatus')
      ? _employmentStatus(profile.employmentStatus)
      : _unknownEmploymentStatus;

  // Net income: use the explicit net when known; NEVER substitute the gross
  // salary (incomparable units). When the net is unknown, pass 0 — every income
  // gate is a lower bound (>= 5000 / > 6000 / *12 > 100000), so 0 closes them
  // all while leaving the children-driven branch of the invalidite gate intact.
  final monthlyNetIncome = profile.explicitMonthlyNetIncome ?? 0.0;

  // Canton drives the high-tax mobility suggestion; gate on its provenance so
  // the default 'ZH' never fabricates one.
  final canton = provided.contains('canton') ? profile.canton : '';

  return buildLifeEventSuggestions(
    age: age,
    civilStatus: civilStatus,
    childrenCount: profile.nombreEnfants,
    employmentStatus: employmentStatus,
    monthlyNetIncome: monthlyNetIncome,
    canton: canton,
    s: s,
  );
}

/// Stable Maestro / a11y identifier for a home life-event card.
///
/// Only the firstJob entry is under acceptance contract today
/// (`home-lifeevent-card-firstJob`, TRANCHE-FIRSTJOB-SPEC §3.1). Other routes
/// return `null` until their own tranche wires an acceptance flow, so the
/// generic section never carries a home-specific id on other surfaces.
String? homeLifeEventCardIdentifier(LifeEventSuggestion suggestion) {
  return suggestion.route == '/first-job'
      ? 'home-lifeevent-card-firstJob'
      : null;
}

/// Maps [CoachCivilStatus] to the primitive string the suggestion builder
/// checks (`'single'` / `'married'` / `'concubinage'`).
String _civilStatus(CoachCivilStatus status) {
  switch (status) {
    case CoachCivilStatus.marie:
      return 'married';
    case CoachCivilStatus.concubinage:
      return 'concubinage';
    case CoachCivilStatus.celibataire:
    case CoachCivilStatus.divorce:
    case CoachCivilStatus.veuf:
      return 'single';
  }
}

/// Maps CoachProfile's French employment status to the primitive string the
/// suggestion builder checks (`'employee'` / `'independent'`).
String _employmentStatus(String raw) {
  switch (raw) {
    case 'salarie':
      return 'employee';
    case 'independant':
      return 'independent';
    default:
      return raw;
  }
}
